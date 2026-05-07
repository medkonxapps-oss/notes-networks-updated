import { supabase } from '../config/supabase';
import fs from 'fs/promises';

export async function uploadToSupabase(
  bucket: string,
  key: string,
  filePath: string,
  contentType: string = 'image/jpeg'
): Promise<void> {
  const fileBuffer = await fs.readFile(filePath);
  const { error } = await supabase.storage
    .from(bucket)
    .upload(key, fileBuffer, {
      contentType,
      upsert: true,
    });
  if (error) throw new Error(`Storage upload failed: ${error.message}`);

  // Clean up temp file
  await fs.unlink(filePath).catch(() => {});
}
