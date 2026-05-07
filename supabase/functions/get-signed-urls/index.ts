import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req: Request) => {
  const { noteId, userId, pageCount, includeThumbnail } = await req.json();

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const urls: { pages: string[]; thumbnail?: string } = { pages: [] };

  // Generate signed URLs for all pages
  for (let i = 0; i < pageCount; i++) {
    const { data } = await supabase.storage
      .from('note-pages')
      .createSignedUrl(`${userId}/${noteId}/page_${i}.jpg`, 3600);
    if (data?.signedUrl) urls.pages.push(data.signedUrl);
  }

  // Generate thumbnail URL if requested
  if (includeThumbnail) {
    const { data } = await supabase.storage
      .from('thumbnails')
      .createSignedUrl(`${userId}/${noteId}/thumb.jpg`, 3600);
    if (data?.signedUrl) urls.thumbnail = data.signedUrl;
  }

  return new Response(JSON.stringify(urls), {
    headers: { 'Content-Type': 'application/json' },
  });
});
