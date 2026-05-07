-- Add UPDATE policy for notes-files bucket to allow upserting files (like cover pages/thumbnails)
drop policy if exists "notes_files_update" on storage.objects;
create policy "notes_files_update" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'notes-files'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
