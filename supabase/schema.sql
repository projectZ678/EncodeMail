-- Encode Mail database. Run this in Supabase SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username = lower(username) and username ~ '^[a-z0-9_]{3,24}$'),
  display_name text not null default '',
  avatar_url text,
  created_at timestamptz not null default now()
);
create table if not exists public.user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  theme text not null default 'dark', accent text not null default '#7c5cff', density text not null default 'comfortable', reading_pane text not null default 'right', show_avatars boolean not null default true, show_previews boolean not null default true,
  updated_at timestamptz not null default now()
);
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(), mailbox_user_id uuid not null references auth.users(id) on delete cascade,
  message_id text, thread_id text, sender text not null, sender_name text, recipients text[] not null default '{}', cc text[] not null default '{}', bcc text[] not null default '{}', subject text not null default '', body_text text, body_html text,
  folder text not null default 'inbox', is_read boolean not null default false, is_starred boolean not null default false, is_archived boolean not null default false, is_spam boolean not null default false, is_deleted boolean not null default false, received_at timestamptz not null default now(), sent_at timestamptz, created_at timestamptz not null default now()
);
create table if not exists public.attachments (
 id uuid primary key default gen_random_uuid(), message_id uuid not null references public.messages(id) on delete cascade, filename text not null, content_type text not null, size bigint not null default 0, storage_path text not null, created_at timestamptz not null default now()
);
create index if not exists messages_mailbox_received_idx on public.messages(mailbox_user_id, received_at desc);
create index if not exists messages_mailbox_folder_idx on public.messages(mailbox_user_id, folder);

alter table public.profiles enable row level security;
alter table public.user_settings enable row level security;
alter table public.messages enable row level security;
alter table public.attachments enable row level security;

drop policy if exists "profiles own" on public.profiles;
create policy "profiles own" on public.profiles for all to authenticated using (id=auth.uid()) with check (id=auth.uid());
drop policy if exists "settings own" on public.user_settings;
create policy "settings own" on public.user_settings for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
drop policy if exists "messages own" on public.messages;
create policy "messages own" on public.messages for all to authenticated using (mailbox_user_id=auth.uid()) with check (mailbox_user_id=auth.uid());
drop policy if exists "attachments own" on public.attachments;
create policy "attachments own" on public.attachments for all to authenticated using (exists(select 1 from public.messages m where m.id=attachments.message_id and m.mailbox_user_id=auth.uid())) with check (exists(select 1 from public.messages m where m.id=attachments.message_id and m.mailbox_user_id=auth.uid()));

-- Storage bucket for attachments.
insert into storage.buckets (id,name,public) values ('attachments','attachments',false) on conflict (id) do nothing;
drop policy if exists "attachment objects own" on storage.objects;
create policy "attachment objects own" on storage.objects for all to authenticated using (bucket_id='attachments' and (storage.foldername(name))[1] = auth.uid()::text) with check (bucket_id='attachments' and (storage.foldername(name))[1] = auth.uid()::text);

-- New users get a profile/settings row when Supabase Auth creates them.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
 insert into public.profiles(id,username,display_name) values(new.id, lower(coalesce(new.raw_user_meta_data->>'username', split_part(new.email,'@',1))), coalesce(new.raw_user_meta_data->>'display_name','')) on conflict(id) do nothing;
 insert into public.user_settings(user_id) values(new.id) on conflict(user_id) do nothing;
 return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
