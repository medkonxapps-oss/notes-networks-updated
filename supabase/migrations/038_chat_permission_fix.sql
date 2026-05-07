-- Migration 038: Force Fix Chat Permissions
-- Run this if you get "permission denied for table chat_rooms"

-- 1. Ensure schema usage
grant usage on schema public to anon, authenticated;

-- 2. Chat Rooms Permissions
grant all privileges on table public.chat_rooms to authenticated;
grant all privileges on table public.chat_rooms to service_role;
grant all privileges on table public.chat_rooms to postgres;

-- 3. Messages Permissions
grant all privileges on table public.messages to authenticated;
grant all privileges on table public.messages to service_role;
grant all privileges on table public.messages to postgres;

-- 4. Double check RLS is actually on
alter table public.chat_rooms enable row level security;
alter table public.messages enable row level security;

-- 5. Add a generic policy for service role (optional but safe)
drop policy if exists "service_role_all_chat_rooms" on public.chat_rooms;
create policy "service_role_all_chat_rooms" on public.chat_rooms for all with check (true);

drop policy if exists "service_role_all_messages" on public.messages;
create policy "service_role_all_messages" on public.messages for all with check (true);
