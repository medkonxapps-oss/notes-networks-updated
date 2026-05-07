-- Fix existing PDF notes that have broken placeholder page_0.jpg keys.
-- Restores file_keys to the original uploaded PDF file key.
--
-- Pattern: original PDF was uploaded as  {user_id}/{note_id}/original_0.pdf
-- Broken processed key looks like:       {user_id}/{note_id}/page_0.jpg
--
-- This sets file_keys back to the original PDF path so SfPdfViewer can render it.

UPDATE notes
SET
  file_keys = ARRAY[
    -- Reconstruct original PDF key from user_id + id
    user_id::text || '/' || id::text || '/original_0.pdf'
  ],
  page_count = 1,
  updated_at = now()
WHERE
  file_type = 'pdf'
  -- Only fix notes whose current file_keys look like processed page images
  AND file_keys[1] LIKE '%/page_0.jpg';
