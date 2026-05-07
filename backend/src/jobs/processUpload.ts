import { Job, Worker } from 'bullmq';
import { supabase } from '../config/supabase';
import { compressPageImage, generateThumbnail, generatePdfThumbnail } from '../processors/imageProcessor';
import { uploadToSupabase } from '../services/storageService';
import { notifyFollowersQueue } from './queue';
import { redis } from '../config/redis';
import os from 'os';
import path from 'path';
import fs from 'fs/promises';
import sharp from 'sharp';
import { PDFDocument } from 'pdf-lib';

interface ProcessUploadData {
  noteId: string;
  userId: string;
  fileType: 'pdf' | 'image_set';
  fileKeys: string[];
}

async function processUploadJob(job: Job<ProcessUploadData>) {
  const { noteId, userId, fileType, fileKeys } = job.data;
  console.log(`Processing upload job for note: ${noteId}`);

  try {
    if (fileType === 'pdf') {
      const pdfKey = fileKeys[0];
      const thumbKey = `${userId}/${noteId}/thumb.jpg`;

      // Download PDF to get page count
      const { data: pdfData, error: downloadError } = await supabase.storage
        .from('notes-files')
        .download(pdfKey);

      let pageCount = 1;
      let pdfBuffer: Buffer | null = null;

      if (!downloadError && pdfData) {
        try {
          pdfBuffer = Buffer.from(await pdfData.arrayBuffer());
          const pdfDoc = await PDFDocument.load(pdfBuffer, { ignoreEncryption: true });
          pageCount = pdfDoc.getPageCount();
          console.log(`📄 PDF Page Count: ${pageCount}`);
        } catch (e) {
          console.error('Error reading PDF page count:', e);
        }
      }

      // Generate a preview thumbnail for the feed card from the first page of the PDF
      let thumbPath: string;
      if (pdfBuffer) {
        thumbPath = await generatePdfThumbnail(pdfBuffer, noteId);
      } else {
        // Ultimate fallback if PDF download failed
        thumbPath = path.join(os.tmpdir(), `${noteId}_fallback_thumb.jpg`);
        await sharp({
          create: { width: 800, height: 450, channels: 3, background: { r: 99, g: 102, b: 241 } },
        })
          .jpeg({ quality: 80 })
          .toFile(thumbPath);
      }

      await uploadToSupabase('notes-files', thumbKey, thumbPath);

      // Update note: set actual page count
      const { error: updateError } = await supabase.from('notes').update({
        status: 'active',
        file_keys: [pdfKey],
        thumbnail_key: thumbKey,
        page_count: pageCount,
        updated_at: new Date().toISOString(),
      }).eq('id', noteId);

      if (updateError) throw new Error(`Failed to update note: ${updateError.message}`);

      await job.updateProgress(100);
      console.log(`✅ PDF note ${noteId} ready`);

    } else {
      // Image set — download, compress, re-upload each image
      const pageImagePaths: string[] = [];

      for (let i = 0; i < fileKeys.length; i++) {
        const { data, error } = await supabase.storage
          .from('notes-files')
          .download(fileKeys[i]);

        if (error || !data) continue;

        const imageBuffer = Buffer.from(await data.arrayBuffer());
        const compressed = await compressPageImage(imageBuffer, i, noteId);
        pageImagePaths.push(compressed);
        await job.updateProgress(Math.round((i / fileKeys.length) * 70));
      }
      console.log(`🖼️ Images processed: ${pageImagePaths.length} pages`);

      // Upload compressed pages
      const pageKeys: string[] = [];
      for (let i = 0; i < pageImagePaths.length; i++) {
        const key = `${userId}/${noteId}/page_${i}.jpg`;
        await uploadToSupabase('notes-files', key, pageImagePaths[i]);
        pageKeys.push(key);
        await job.updateProgress(Math.round(70 + (i / pageImagePaths.length) * 20));
      }

      // Generate thumbnail from first compressed page
      const thumbKey = `${userId}/${noteId}/thumb.jpg`;
      if (pageImagePaths.length > 0) {
        const firstPageBuffer = await fs.readFile(pageImagePaths[0]).catch(() => Buffer.alloc(0));
        if (firstPageBuffer.length > 0) {
          const thumbPath = await generateThumbnail(firstPageBuffer, noteId);
          await uploadToSupabase('notes-files', thumbKey, thumbPath);
        }
      }

      const { error: updateError } = await supabase.from('notes').update({
        status: 'active',
        file_keys: pageKeys.length > 0 ? pageKeys : undefined,
        thumbnail_key: thumbKey,
        page_count: pageKeys.length > 0 ? pageKeys.length : undefined,
        updated_at: new Date().toISOString(),
      }).eq('id', noteId);

      if (updateError) throw new Error(`Failed to update note: ${updateError.message}`);

      await job.updateProgress(100);
      console.log(`✅ Image note ${noteId} published successfully`);
    }

    // Queue follower notification
    await notifyFollowersQueue.add('notify', { noteId, userId });

  } catch (error) {
    console.error(`❌ processUpload failed for ${noteId}:`, error);
    await supabase.from('notes').update({
      status: 'active',
      updated_at: new Date().toISOString(),
    }).eq('id', noteId).eq('status', 'processing');
    throw error;
  }
}

export const processUploadWorker = new Worker(
  'process-upload',
  processUploadJob,
  { connection: redis, concurrency: 3 }
);

processUploadWorker.on('completed', (job) => {
  console.log(`✅ Job ${job.id} completed`);
});

processUploadWorker.on('failed', (job, err) => {
  console.error(`❌ Job ${job?.id} failed:`, err.message);
});
