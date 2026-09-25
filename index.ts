// supabase/functions/receive-email/index.ts
//
// Inbound mail webhook. Point your mail-receiving provider (ForwardEmail,
// Mailgun Routes, etc.) at this function's URL. It looks up which local
// user owns the destination address and stores the message in their Inbox.
//
// Deploy with:
//   supabase functions deploy receive-email --no-verify-jwt
//
// Set secrets with:
//   supabase secrets set INBOUND_SHARED_SECRET=some-long-random-string

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const INBOUND_SHARED_SECRET = Deno.env.get("INBOUND_SHARED_SECRET")!;

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

function localPart(address: string): string {
  return address.split("@")[0]?.trim().toLowerCase() ?? "";
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  // Shared-secret check so randoms on the internet can't inject fake mail.
  // Pass it as a query param when you configure the webhook URL, e.g.
  // https://xyz.functions.supabase.co/receive-email?secret=XXXX
  const url = new URL(req.url);
  if (url.searchParams.get("secret") !== INBOUND_SHARED_SECRET) {
    return new Response("Unauthorized", { status: 401 });
  }

  // Providers differ in payload shape. This handles the common
  // "form-encoded" shape (Mailgun-style) and a plain JSON shape
  // (ForwardEmail / generic). Adjust the field names to match your
  // provider's actual webhook payload — check their docs.
  let to = "", from = "", subject = "", text = "", html = "";
  const contentType = req.headers.get("content-type") ?? "";

  if (contentType.includes("application/json")) {
    const body = await req.json();
    to = body.to ?? body.recipient ?? "";
    from = body.from ?? body.sender ?? "";
    subject = body.subject ?? "(no subject)";
    text = body.text ?? body["body-plain"] ?? "";
    html = body.html ?? body["body-html"] ?? "";
  } else {
    const form = await req.formData();
    to = String(form.get("recipient") ?? form.get("to") ?? "");
    from = String(form.get("from") ?? form.get("sender") ?? "");
    subject = String(form.get("subject") ?? "(no subject)");
    text = String(form.get("body-plain") ?? form.get("text") ?? "");
    html = String(form.get("body-html") ?? form.get("html") ?? "");
  }

  const uname = localPart(to);
  if (!uname) {
    return new Response("Could not parse recipient", { status: 400 });
  }

  // Resolve username -> user id via the public directory view.
  const { data: profile, error: lookupError } = await supabase
    .from("username_directory")
    .select("id")
    .eq("username", uname)
    .maybeSingle();

  if (lookupError || !profile) {
    // No such mailbox. Reply 200 anyway so the provider doesn't retry forever;
    // log it so you can see bounces in the function logs.
    console.log(`No mailbox for "${uname}" (to: ${to})`);
    return new Response("No such mailbox", { status: 200 });
  }

  // Find (or lazily create) that user's Inbox folder id.
  const { data: inbox } = await supabase
    .from("folders")
    .select("id")
    .eq("user_id", profile.id)
    .eq("name", "Inbox")
    .maybeSingle();

  const { error: insertError } = await supabase.from("messages").insert({
    user_id: profile.id,
    folder_id: inbox?.id ?? null,
    direction: "in",
    from_address: from,
    to_address: to,
    subject: subject || "(no subject)",
    body_text: text || null,
    body_html: html || null,
    raw: { to, from, subject, receivedAt: new Date().toISOString() },
  });

  if (insertError) {
    console.error(insertError);
    return new Response("Failed to store message", { status: 500 });
  }

  return new Response("OK", { status: 200 });
});
