// Encode Mail outbound Edge Function.
// Configure MAIL_API_URL + MAIL_API_KEY as Supabase secrets for your mail provider.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type'};
Deno.serve(async(req)=>{if(req.method==='OPTIONS')return new Response('ok',{headers:cors});try{
 const auth=req.headers.get('Authorization'); if(!auth) throw new Error('Unauthorized');
 const sb=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:auth}}});
 const {data:{user},error}=await sb.auth.getUser(); if(error||!user) throw new Error('Unauthorized');
 const {data:p}=await sb.from('profiles').select('username,display_name').eq('id',user.id).single(); if(!p) throw new Error('Profile missing');
 const input=await req.json(); const to=Array.isArray(input.to)?input.to.map((x:string)=>x.trim()).filter(Boolean):[]; if(!to.length)throw new Error('Recipient required');
 const api=Deno.env.get('MAIL_API_URL'), key=Deno.env.get('MAIL_API_KEY'), domain=Deno.env.get('MAIL_DOMAIN')||'encode.lol';
 if(!api||!key)throw new Error('Outbound provider is not configured.');
 const from=`${p.username}@${domain}`;
 const r=await fetch(api,{method:'POST',headers:{Authorization:`Bearer ${key}`,'Content-Type':'application/json'},body:JSON.stringify({from,to,subject:input.subject||'',text:input.body_text||''})});
 if(!r.ok)throw new Error(`Mail provider returned ${r.status}`);
 const {error:insertError}=await sb.from('messages').insert({mailbox_user_id:user.id,sender:from,sender_name:p.display_name,recipients:to,subject:input.subject||'',body_text:input.body_text||'',folder:'sent',is_read:true,sent_at:new Date().toISOString(),received_at:new Date().toISOString()}); if(insertError)throw insertError;
 return new Response(JSON.stringify({ok:true}),{headers:{...cors,'Content-Type':'application/json'}});
}catch(e){return new Response(JSON.stringify({error:e instanceof Error?e.message:'Unknown error'}),{status:400,headers:{...cors,'Content-Type':'application/json'}})}});
