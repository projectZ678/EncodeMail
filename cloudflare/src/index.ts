/**
 * Cloudflare Email Worker for Encode Mail.
 * 1) Configure your MX records for encode.lol to Cloudflare Email Service.
 * 2) Add SUPABASE_SERVICE_ROLE_KEY as a Wrangler secret (never commit it).
 * 3) Deploy this Worker and configure Email Routing to send mail to it.
 */
interface Env { SUPABASE_URL:string; SUPABASE_SERVICE_ROLE_KEY:string; MAIL_DOMAIN:string }
export default { async email(message:any, env:Env, _ctx:any){
 const to = String(message.to || '').toLowerCase(); const username = to.split('@')[0];
 if(!username) return message.reject('Invalid recipient');
 const lookup = await fetch(`${env.SUPABASE_URL}/rest/v1/profiles?select=id,username&username=eq.${encodeURIComponent(username)}`,{headers:{apikey:env.SUPABASE_SERVICE_ROLE_KEY,Authorization:`Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`}});
 if(!lookup.ok) return message.reject('Mailbox lookup failed'); const rows:any[] = await lookup.json(); if(!rows[0]) return message.reject('Mailbox does not exist');
 const raw = await new Response(message.raw).text(); const subject = raw.match(/^Subject:\s*(.*)$/mi)?.[1] || '';
 const from = String(message.from||''); const uid=rows[0].id;
 const payload={mailbox_user_id:uid,sender:from,sender_name:from,recipients:[to],subject,body_text:raw,folder:'inbox',message_id:message.headers?.get?.('Message-ID')||null};
 const res=await fetch(`${env.SUPABASE_URL}/rest/v1/messages`,{method:'POST',headers:{apikey:env.SUPABASE_SERVICE_ROLE_KEY,Authorization:`Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`, 'Content-Type':'application/json',Prefer:'return=minimal'},body:JSON.stringify(payload)});
 if(!res.ok) return message.reject('Could not store message');
 return message.accept();
}}
