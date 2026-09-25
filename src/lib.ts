import { createClient } from '@supabase/supabase-js';

export const MAIL_DOMAIN = import.meta.env.VITE_MAIL_DOMAIN || 'encode.lol';
export const AUTH_DOMAIN = import.meta.env.VITE_AUTH_DOMAIN || 'accounts.encode.lol';
export const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL || '';
export const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY || '';
export const supabaseConfigured = Boolean(SUPABASE_URL && SUPABASE_ANON_KEY);

export const supabase = supabaseConfigured
  ? createClient(SUPABASE_URL, SUPABASE_ANON_KEY)
  : null;

export const authIdentity = (u:string) => `${u.toLowerCase().trim()}@${AUTH_DOMAIN}`;
export const mailAddress = (u:string) => `${u.toLowerCase().trim()}@${MAIL_DOMAIN}`;
export function initials(name?:string, username?:string){ return (name||username||'?').slice(0,2).toUpperCase(); }
