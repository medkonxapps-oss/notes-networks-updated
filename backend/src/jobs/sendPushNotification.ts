import { Worker } from 'bullmq';
import { supabase } from '../config/supabase';
import { redis } from '../config/redis';
import admin from 'firebase-admin';
import dotenv from 'dotenv';

dotenv.config();

// Initialize Firebase Admin only if credentials are provided
if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  try {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    console.log('🔥 Firebase Admin initialized successfully');
  } catch (error) {
    console.error('❌ Failed to initialize Firebase Admin:', error);
  }
} else {
  console.warn('⚠️ FIREBASE_SERVICE_ACCOUNT not set. Push notifications will be mocked.');
}

async function sendPushNotificationJob(job: any) {
  const { noteId, userId, type, title, body, targetUserId } = job.data;

  // Get target user's FCM token
  const { data: user } = await supabase
    .from('users')
    .select('fcm_token')
    .eq('id', targetUserId || userId)
    .maybeSingle();

  if (!user?.fcm_token) {
    console.log(`No FCM token for user ${targetUserId || userId}`);
    return;
  }

  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    try {
      await admin.messaging().send({
        token: user.fcm_token,
        notification: { title, body },
        data: { noteId: noteId || '', type: type || 'system' },
      });
      console.log(`📱 Push notification sent: ${title} → ${user.fcm_token.slice(0, 20)}...`);
    } catch (error) {
      console.error(`❌ Failed to send push to ${user.fcm_token}:`, error);
    }
  } else {
    console.log(`📱 [MOCKED] Push notification sent: ${title} → ${user.fcm_token.slice(0, 20)}...`);
  }
}

export const pushNotificationWorker = new Worker(
  'notify-followers',
  sendPushNotificationJob,
  { connection: redis, concurrency: 10 }
);
