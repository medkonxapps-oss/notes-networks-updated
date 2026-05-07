import { Router, Request, Response } from 'express';
import { processUploadQueue } from '../jobs/queue';
import { supabase } from '../config/supabase';
import { MailService } from '../services/mailService';

const router = Router();

import crypto from 'crypto';

// Timing-safe webhook secret comparison (prevents timing attacks)
function verifyWebhookSecret(req: Request, res: Response, next: Function) {
  const secret = req.headers['x-webhook-secret'];
  const expected = process.env.WEBHOOK_SECRET;

  if (!expected || typeof secret !== 'string') {
    console.warn('⚠️ Webhook secret missing or malformed');
    return res.status(401).json({ error: 'Unauthorized' });
  }

  // Use timingSafeEqual to prevent timing attacks
  try {
    const secretBuf = Buffer.from(secret, 'utf8');
    const expectedBuf = Buffer.from(expected, 'utf8');
    const match =
      secretBuf.length === expectedBuf.length &&
      crypto.timingSafeEqual(secretBuf, expectedBuf);
    if (!match) {
      console.warn('⚠️ Invalid webhook secret from', req.ip);
      return res.status(401).json({ error: 'Unauthorized' });
    }
  } catch {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  next();
}

// POST /webhook/note-published
// Called by Supabase Edge Function relay when a new note is inserted
router.post('/note-published', verifyWebhookSecret, async (req: Request, res: Response) => {
  try {
    const note = req.body;
    if (!note?.id || !note?.user_id) {
      return res.status(400).json({ error: 'Invalid payload' });
    }

    await processUploadQueue.add('process', {
      noteId: note.id,
      userId: note.user_id,
      fileType: note.file_type,
      fileKeys: note.file_keys,
    }, {
      attempts: 3,
      backoff: { type: 'exponential', delay: 5000 },
    });

    console.log(`📬 Queued processing for note: ${note.id}`);
    res.json({ queued: true, noteId: note.id });
  } catch (error: any) {
    console.error('Webhook error:', error);
    res.status(500).json({ error: error.message });
  }
});

// POST /webhook/teacher-status-updated
// Called by Supabase Edge Function relay when a teacher's status changes
router.post('/teacher-status-updated', verifyWebhookSecret, async (req: Request, res: Response) => {
  try {
    const { user, new_status } = req.body;
    if (!user?.email || !new_status) {
      return res.status(400).json({ error: 'Invalid payload' });
    }

    const isApproved = new_status === 'approved';
    const title = isApproved ? 'Account Approved! 🎉' : 'Verification Update';
    const body = isApproved 
      ? `Hello ${user.full_name}, your teacher account has been verified. You can now login!` 
      : `Hello ${user.full_name}, your teacher verification was not successful.`;

    // 1. Send Push Notification (if they have a token)
    if (user.fcm_token) {
      // Logic for push notification would go here
      console.log(`📱 Push notification logged for ${user.email}`);
    }

    // 2. Send Email using SendGrid
    if (isApproved) {
      await MailService.sendTeacherApprovalEmail(user.email, user.full_name);
    } else if (new_status === 'rejected') {
      await MailService.sendTeacherRejectionEmail(user.email, user.full_name);
    }
    
    res.json({ success: true, notified: user.email });
  } catch (error: any) {
    console.error('Teacher status webhook error:', error);
    res.status(500).json({ error: error.message });
  }
});

// POST /webhook/chat-message
// Called by Supabase Edge Function relay when a new message is inserted
router.post('/chat-message', verifyWebhookSecret, async (req: Request, res: Response) => {
  try {
    const { message, sender_id, receiver_id } = req.body;
    if (!message || !sender_id || !receiver_id) {
      return res.status(400).json({ error: 'Invalid payload' });
    }

    // Fetch sender and receiver profiles
    const [{ data: sender }, { data: receiver }] = await Promise.all([
      supabase.from('users').select('full_name').eq('id', sender_id).single(),
      supabase.from('users').select('id, fcm_token').eq('id', receiver_id).single(),
    ]);

    // Send Push Notification via BullMQ
    if (receiver?.fcm_token) {
      await processUploadQueue.add('send-push', {
        type: 'chat',
        title: `New message from ${sender?.full_name || 'Teacher'}`,
        body: message.content.length > 100 ? message.content.slice(0, 97) + '...' : message.content,
        targetUserId: receiver.id,
        roomId: message.room_id,
      });
    }

    res.json({ success: true });
  } catch (error: any) {
    console.error('Chat webhook error:', error);
    res.status(500).json({ error: error.message });
  }
});

// POST /webhook/reprocess-note
// Re-queues a note for PDF-to-image reprocessing (fixes broken placeholder images)
router.post('/reprocess-note', verifyWebhookSecret, async (req: Request, res: Response) => {
  try {
    const { noteId } = req.body;
    if (!noteId) return res.status(400).json({ error: 'noteId required' });

    // Fetch original file info from DB
    const { data: note, error } = await supabase
      .from('notes')
      .select('id, user_id, file_type, file_keys')
      .eq('id', noteId)
      .maybeSingle();

    if (error || !note) return res.status(404).json({ error: 'Note not found' });

    // Find original file key
    const originalKeys = (note.file_keys as string[]).filter(
      (k: string) => k.includes('original_') || (!k.includes('page_') && !k.includes('thumb'))
    );

    if (originalKeys.length === 0) {
      return res.status(400).json({ error: 'No original file keys found' });
    }

    await processUploadQueue.add('process', {
      noteId: note.id,
      userId: note.user_id,
      fileType: note.file_type,
      fileKeys: originalKeys,
    }, {
      attempts: 3,
      backoff: { type: 'exponential', delay: 5000 },
    });

    res.json({ queued: true, noteId });
  } catch (error: any) {
    console.error('Reprocess error:', error);
    res.status(500).json({ error: error.message });
  }
});

// POST /webhook/system-notification
// Called by Supabase Edge Function relay when a new system notification is created
router.post('/system-notification', verifyWebhookSecret, async (req: Request, res: Response) => {
  try {
    const notification = req.body;
    if (!notification?.user_id || !notification?.title || !notification?.message) {
      return res.status(400).json({ error: 'Invalid payload' });
    }

    // Only process system and forum notifications for push
    if (!['system', 'forum', 'reward'].includes(notification.type)) {
       return res.json({ success: true, skipped: true });
    }

    // Queue push notification
    await processUploadQueue.add('send-push', {
      type: notification.type,
      title: notification.title,
      body: notification.message,
      targetUserId: notification.user_id,
      noteId: notification.reference_id || null,
    });

    console.log(`📱 Queued push notification for user: ${notification.user_id}`);
    res.json({ queued: true });
  } catch (error: any) {
    console.error('System notification webhook error:', error);
    res.status(500).json({ error: error.message });
  }
});

export default router;
