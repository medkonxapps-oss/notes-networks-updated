-- Migration 053: Fix admin/teacher avatar visibility
--
-- Root cause: The avatars storage bucket may not be set to public=true,
-- causing avatar URLs to return 400/403 for unauthenticated or cross-user requests.
-- Also ensures the avatars_read policy has no auth restriction.

-- 1. Force avatars bucket to be public
update storage.buckets
set public = true
where id = 'avatars';

-- 2. Drop and recreate avatars_read with no restrictions (bucket is public)
drop policy if exists "avatars_read" on storage.objects;
create policy "avatars_read" on storage.objects
  for select using (bucket_id = 'avatars');

-- 3. Allow any authenticated user to upload to their own avatar path
--    (covers admin, teacher, student, moderator equally)
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

-- 4. Ensure users_select policy allows reading any active user
--    (admin rows must be readable by regular users for profile/note-card display)
drop policy if exists "users_select" on public.users;

create policy "users_select" on public.users
  for select using (
    -- Admins see everything
    public.is_admin()
    -- Own row always visible
    or auth.uid() = id
    -- Any non-deleted user is readable by authenticated users
    -- (covers admin, teacher, student, moderator — all roles)
    or (deleted_at is null and auth.uid() is not null)
    -- Anon can see active users (for public note cards)
    or (deleted_at is null and is_active = true)
  );
