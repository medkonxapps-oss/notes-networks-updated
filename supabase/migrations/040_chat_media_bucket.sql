-- Migration 040: Chat Media Bucket

-- 1. Create chat-media bucket
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'chat-media',
  'chat-media',
  true, -- Make public for easy loading in app
  10485760, -- 10MB limit
  array['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

-- 2. Storage RLS: authenticated users can upload if they are part of the room
-- Note: the path format is room_id/filename.extension
create policy "chat_media_upload" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'chat-media'
    and exists (
      select 1 from public.chat_rooms
      where id::text = (storage.foldername(name))[1]
      and (student_id = auth.uid() or teacher_id = auth.uid())
    )
  );

-- Anyone authenticated can read (simplifies things, but RLS on room handles privacy of URL)
create policy "chat_media_read" on storage.objects
  for select to authenticated
  using (bucket_id = 'chat-media');
