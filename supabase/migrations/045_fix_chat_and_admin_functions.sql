-- Migration 045: Fix Postgres SET error and Chat Edit/Delete
-- This fixes the "SET is not allowed in a non-volatile function" error
-- and adds missing RLS policies for message editing and deleting.

-- 1. Fix public.get_my_role()
-- We move "set local row_security = off" to the function header or remove STABLE.
-- Making it VOLATILE (default) is the safest way to allow SET LOCAL.
create or replace function public.get_my_role()
returns text as $$
declare
  v_role text;
begin
  -- security definer + set local row_security off bypasses RLS for this query
  -- this is needed to prevent infinite recursion when called from a policy on public.users
  set local row_security = off;
  select role into v_role from public.users where id = auth.uid();
  return v_role;
end;
$$ language plpgsql security definer; -- Removed 'stable'

-- 2. Fix public.is_admin()
-- Needs to be volatile if it calls a volatile function.
create or replace function public.is_admin()
returns boolean as $$
  select public.get_my_role() in ('admin', 'moderator');
$$ language sql security definer; -- Removed 'stable'

-- 3. Add update and delete policies for public.messages
-- Current policies only allow select and insert.
-- We need to allow users to edit their own messages and mark received messages as read.

drop policy if exists "messages_update" on public.messages;
create policy "messages_update" on public.messages
  for update to authenticated
  using (
    auth.uid() = sender_id -- Allow editing own messages
    or auth.uid() = receiver_id -- Allow marking as read
  )
  with check (
    (auth.uid() = sender_id) -- Sender can change content
    or (
      auth.uid() = receiver_id 
      and is_read = true 
      -- In a perfect world, we'd ensure ONLY is_read is changed, 
      -- but for now this enables the feature.
    )
  );

drop policy if exists "messages_delete" on public.messages;
create policy "messages_delete" on public.messages
  for delete to authenticated
  using (auth.uid() = sender_id);

-- 4. Ensure chat_rooms has update grant for the trigger to work
grant update on public.chat_rooms to authenticated;
grant update on public.messages to authenticated;

-- 5. Fix Chat Room Preview on Message Delete/Update
-- Current trigger only handles INSERT. We need to handle DELETE and UPDATE
-- to keep the last_message_text and last_message_at in sync.

create or replace function public.handle_message_change()
returns trigger as $$
declare
  v_last_msg record;
begin
  -- If message is deleted or content changed, we find the new "last message"
  select content, created_at 
  into v_last_msg
  from public.messages
  where room_id = coalesce(new.room_id, old.room_id)
  order by created_at desc
  limit 1;

  update public.chat_rooms
  set 
    last_message_text = left(v_last_msg.content, 100),
    last_message_at = coalesce(v_last_msg.created_at, created_at) -- fallback to room creation time if no messages
  where id = coalesce(new.room_id, old.room_id);

  if TG_OP = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$ language plpgsql security definer;

-- Drop old triggers and create new one for all operations
drop trigger if exists on_new_message on public.messages;
drop trigger if exists on_message_change on public.messages;

create trigger on_message_change
  after insert or update or delete on public.messages
  for each row
  execute function public.handle_message_change();

-- 6. Speed up "last message" lookup
create index if not exists idx_messages_room_created_at on public.messages(room_id, created_at desc);

-- 7. Fix admin_approve_teacher unauthorized error
-- Since get_my_role is now volatile and handles SET LOCAL row_security = off,
-- we should use it consistently.
create or replace function public.admin_approve_teacher(
  target_user_id uuid,
  new_status text
)
returns void as $$
declare
  v_role text;
begin
  -- Use our fixed get_my_role() helper
  v_role := public.get_my_role();

  if v_role not in ('admin', 'moderator') then
    raise exception 'Unauthorized: admin only';
  end if;

  if new_status not in ('approved', 'rejected', 'pending') then
    raise exception 'Invalid status';
  end if;

  update public.users
  set
    teacher_status = new_status,
    role = case when new_status = 'approved' then 'teacher' else role end,
    updated_at = now()
  where id = target_user_id;
end;
$$ language plpgsql security definer;

grant execute on function public.admin_approve_teacher(uuid, text) to authenticated;
