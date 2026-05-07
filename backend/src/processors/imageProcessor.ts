import sharp from 'sharp';
import path from 'path';
import fs from 'fs/promises';
import os from 'os';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

export async function compressPageImage(
  inputBuffer: Buffer,
  pageIndex: number,
  noteId: string
): Promise<string> {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), `note-${noteId}-`));
  const outputPath = path.join(tmpDir, `page_${pageIndex}.jpg`);

  await sharp(inputBuffer)
    .resize(1200, 1600, { fit: 'inside', withoutEnlargement: true })
    .jpeg({ quality: 82, progressive: true })
    .toFile(outputPath);

  return outputPath;
}

export async function generateThumbnail(
  inputBuffer: Buffer,
  noteId: string
): Promise<string> {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), `thumb-${noteId}-`));
  const outputPath = path.join(tmpDir, 'thumb.jpg');

  await sharp(inputBuffer)
    .resize(800, 450, { fit: 'cover', position: 'top' })
    .jpeg({ quality: 80 })
    .toFile(outputPath);

  return outputPath;
}

export async function generatePdfThumbnail(
  pdfBuffer: Buffer,
  noteId: string
): Promise<string> {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), `pdf-thumb-${noteId}-`));
  const pdfPath = path.join(tmpDir, 'input.pdf');
  const outputBase = path.join(tmpDir, 'thumb');
  
  await fs.writeFile(pdfPath, pdfBuffer);

  try {
    // Try using pdftocairo (available in poppler-utils in Docker)
    // -f 1 -l 1 means only first page
    // -singlefile means don't append page number to output
    await execAsync(`pdftocairo -jpeg -f 1 -l 1 -scale-to-x 800 -scale-to-y -1 -singlefile "${pdfPath}" "${outputBase}"`);
    
    const generatedThumb = `${outputBase}.jpg`;
    
    // Now use sharp to crop it to 16:9 aspect ratio (800x450)
    const finalThumbPath = path.join(tmpDir, 'final_thumb.jpg');
    await sharp(generatedThumb)
      .resize(800, 450, { fit: 'cover', position: 'top' })
      .jpeg({ quality: 80 })
      .toFile(finalThumbPath);
      
    return finalThumbPath;
  } catch (error) {
    console.error('pdftocairo failed, falling back to solid color:', error);
    // Fallback to solid color if pdftocairo is not available (e.g. during local dev on Windows)
    const finalThumbPath = path.join(tmpDir, 'fallback_thumb.jpg');
    await sharp({
      create: { width: 800, height: 450, channels: 3, background: { r: 99, g: 102, b: 241 } },
    })
      .jpeg({ quality: 80 })
      .toFile(finalThumbPath);
    return finalThumbPath;
  }
}
