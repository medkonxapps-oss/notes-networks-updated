-- ══════════════════════════════════════════════════════════════════════════════
-- Migration 008: Fix all permission errors and RLS gaps
-- Run this in Supabase SQL Editor
-- ══════════════════════════════════════════════════════════════════════════════

-- ── 1. GRANT table-level permissions to authenticated & anon roles ─────────────
-- RLS policies alone are not enough — Postgres also requires role-level GRANTs.

grant usage on schema public to anon, authenticated;

-- Users table
grant select on public.users to anon, authenticated;
grant update on public.users to authenticated;

-- Notes table
grant select, insert, update on public.notes to authenticated;
grant select on public.notes to anon;

-- Folders
grant select, insert, update, delete on public.folders to authenticated;

-- Follows
grant select, insert, delete on public.follows to authenticated;

-- Likes
grant select, insert, delete on public.likes to authenticated;

-- Saves
grant select, insert, update, delete on public.saves to authenticated;

-- Notifications  ← THIS IS THE FIX FOR "permission denied for table notifications"
grant select, update on public.notifications to authenticated;

-- Points ledger (read-only for users, writes via security definer functions)
grant select on public.points_ledger to authenticated;

-- Reports
grant insert on public.reports to authenticated;

-- Badges & user_badges
grant select on public.badges to anon, authenticated;
grant select on public.user_badges to authenticated;

-- Rewards catalog  ← THIS IS THE FIX FOR "Rewards Error"
grant select on public.rewards_catalog to anon, authenticated;

-- Redemptions
grant select, insert on public.redemptions to authenticated;

-- Sequences (needed for inserts)
grant usage, select on all sequences in schema public to authenticated;

-- ── 2. FIX notes status constraint to allow 'draft' ───────────────────────────
-- The app's createNoteDraft was using 'draft' status (now fixed to 'processing'
-- in code, but add 'draft' to constraint as safety net)
alter table public.notes
  drop constraint if exists notes_status_check;

alter table public.notes
  add constraint notes_status_check
  check (status in ('draft', 'processing', 'active', 'removed', 'pending_review'));

-- ── 3. FIX notes RLS — allow owner to see their own notes in any status ────────
-- The current policy only shows 'active' notes, which means a user can't see
-- their own notes that are still 'processing' after upload.
drop policy if exists "notes_select_public" on public.notes;
drop policy if exists "notes_insert_own" on public.notes;
drop policy if exists "notes_update_own" on public.notes;
drop policy if exists "notes_admin_select" on public.notes;

create policy "notes_select_public" on public.notes for select using (
  deleted_at is null and (
    -- Owner can always see their own notes regardless of status
    user_id = auth.uid()
    or (
      -- Others can only see active notes
      status = 'active' and (
        visibility = 'public'
        or (visibility = 'followers' and exists(
          select 1 from public.follows
          where follower_id = auth.uid() and following_id = notes.user_id
        ))
      )
    )
  )
);

-- Also allow anon users to see public active notes
drop policy if exists "notes_select_anon" on public.notes;
create policy "notes_select_anon" on public.notes for select using (
  deleted_at is null
  and status = 'active'
  and visibility = 'public'
);

-- ── 4. FIX notifications RLS — 'for all' doesn't cover SELECT in all Postgres versions ──
-- Drop and recreate with explicit SELECT policy
drop policy if exists "notifications_own" on public.notifications;
drop policy if exists "notifications_select_own" on public.notifications;
drop policy if exists "notifications_update_own" on public.notifications;
drop policy if exists "notifications_insert_system" on public.notifications;

create policy "notifications_select_own" on public.notifications
  for select using (auth.uid() = user_id);

create policy "notifications_update_own" on public.notifications
  for update using (auth.uid() = user_id);

create policy "notifications_insert_system" on public.notifications
  for insert with check (true); -- inserts done by backend/triggers only

-- ── 5. FIX auth trigger — handle null username gracefully ─────────────────────
-- If username is null in metadata, the insert fails with NOT NULL violation.
-- Add a fallback using the email prefix.
create or replace function public.handle_new_user()
returns trigger as $$
declare
  v_username text;
  v_full_name text;
begin
  v_username  := coalesce(
    nullif(trim(new.raw_user_meta_data->>'username'), ''),
    split_part(new.email, '@', 1)
  );
  v_full_name := coalesce(
    nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
    v_username
  );

  -- Make username unique if it already exists
  while exists (select 1 from public.users where username = v_username) loop
    v_username := v_username || floor(random() * 1000)::text;
  end loop;

  insert into public.users (id, username, full_name, email, board, class_level)
  values (
    new.id,
    v_username,
    v_full_name,
    new.email,
    coalesce(nullif(trim(new.raw_user_meta_data->>'board'), ''), 'CBSE'),
    coalesce(nullif(trim(new.raw_user_meta_data->>'class_level'), ''), 'Class 10')
  )
  on conflict (id) do nothing; -- idempotent: don't fail if row already exists

  return new;
end;
$$ language plpgsql security definer;

-- Recreate trigger
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ── 6. CREATE storage bucket for notes-files ──────────────────────────────────
-- Run this only if the bucket doesn't exist yet
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'notes-files',
  'notes-files',
  false,
  52428800, -- 50MB limit
  array['application/pdf', 'image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

-- Storage RLS: authenticated users can upload to their own folder
drop policy if exists "notes_files_upload" on storage.objects;
create policy "notes_files_upload" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'notes-files'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- Authenticated users can read any file (for signed URLs and direct access)
drop policy if exists "notes_files_read" on storage.objects;
create policy "notes_files_read" on storage.objects
  for select to authenticated
  using (bucket_id = 'notes-files');

-- Allow anon to read public files (for public notes thumbnails)
drop policy if exists "notes_files_read_anon" on storage.objects;
create policy "notes_files_read_anon" on storage.objects
  for select to anon
  using (bucket_id = 'notes-files');

-- Users can delete their own files
drop policy if exists "notes_files_delete" on storage.objects;
create policy "notes_files_delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'notes-files'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- ── 7. CREATE avatars bucket ──────────────────────────────────────────────────
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true, -- public so avatar URLs work without signing
  5242880, -- 5MB limit
  array['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

drop policy if exists "avatars_upload" on storage.objects;
create policy "avatars_upload" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "avatars_update" on storage.objects;
create policy "avatars_update" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "avatars_read" on storage.objects;
create policy "avatars_read" on storage.objects
  for select using (bucket_id = 'avatars');

-- ── 8. BACKFILL: create public.users rows for any existing auth users ──────────
-- This fixes the foreign key error for users who signed up before the trigger existed
insert into public.users (id, username, full_name, email, board, class_level)
select
  au.id,
  coalesce(
    nullif(trim(au.raw_user_meta_data->>'username'), ''),
    split_part(au.email, '@', 1)
  ),
  coalesce(
    nullif(trim(au.raw_user_meta_data->>'full_name'), ''),
    split_part(au.email, '@', 1)
  ),
  au.email,
  coalesce(nullif(trim(au.raw_user_meta_data->>'board'), ''), 'CBSE'),
  coalesce(nullif(trim(au.raw_user_meta_data->>'class_level'), ''), 'Class 10')
from auth.users au
where not exists (
  select 1 from public.users pu where pu.id = au.id
);
