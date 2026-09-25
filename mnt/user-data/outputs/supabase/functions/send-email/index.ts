// supabase/functions/send-email/index.ts
//
// Called by the webmail client (with the user's own JWT) to actually send a
// message through Resend, then records it in the Sent folder.
//
// Deploy with:
//   supabase functions deploy send-email
//
// Set secrets with:
//   supabase secrets set RESEND_API_KEY=re_xxxxxxxx

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const MAIL_DOMAIN = "encode.lol";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  const authHeader = req.headers.get("Authorization") ?? "";

  // Client bound to the caller's own JWT, so RLS applies and we always know
  // who's really sending (can't be spoofed as someone else's address).
  const supabase = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) {
    return new Response("Unauthorized", { status: 401, headers: corsHeaders });
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("username")
    .eq("id", userData.user.id)
    .single();

  if (!profile) {
    return new Response("No profile", { status: 400, headers: corsHeaders });
  }

  const fromAddress = `${profile.username}@${MAIL_DOMAIN}`;
  const { to, subject, text, html } = await req.json();

  if (!to || !subject) {
    return new Response("Missing 'to' or 'subject'", { status: 400, headers: corsHeaders });
  }

  const resendResp = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: fromAddress,
      to: [to],
      subject,
      text: text ?? undefined,
      html: html ?? undefined,
    }),
  });

  if (!resendResp.ok) {
    const errText = await resendResp.text();
    console.error("Resend error:", errText);
    return new Response(`Send failed: ${errText}`, { status: 502, headers: corsHeaders });
  }

  // Log it to the Sent folder.
  const { data: sentFolder } = await supabase
    .from("folders")
    .select("id")
    .eq("user_id", userData.user.id)
    .eq("name", "Sent")
    .maybeSingle();

  await supabase.from("messages").insert({
    user_id: userData.user.id,
    folder_id: sentFolder?.id ?? null,
    direction: "out",
    from_address: fromAddress,
    to_address: to,
    subject,
    body_text: text ?? null,
    body_html: html ?? null,
  });

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
