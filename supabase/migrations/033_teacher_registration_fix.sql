-- Allow anonymous uploads to id-cards bucket in the 'incoming' folder
create policy "Anyone can upload to incoming folder"
  on storage.objects for insert with check (
    bucket_id = 'id-cards' and (storage.foldername(name))[1] = 'incoming'
  );

-- Allow public access to view id-cards (optional, but needed for admin to view them if they don't have special access)
-- Better: allow only authenticated users with 'admin' or 'moderator' role to view all id-cards.
create policy "Admins and moderators can view all id cards"
  on storage.objects for select using (
    bucket_id = 'id-cards' and (
      auth.uid() in (select id from public.users where role in ('admin', 'moderator'))
    )
  );

-- Also allow users to see their own id-cards if they are uploaded with their UID
-- (Existing policy already handles this, but let's make sure it doesn't conflict)
