import { Worker } from 'bullmq';
import { supabase } from '../config/supabase';
import { redis } from '../config/redis';
import admin from 'firebase-admin';
import dotenv from 'dotenv';

dotenv.config();

// Initialize Firebase Admin
if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  try {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    console.log('🔥 Firebase Admin initialized from JSON string');
  } catch (error) {
    console.error('❌ Failed to initialize Firebase Admin from JSON:', error);
  }
} else if (process.env.FIREBASE_PROJECT_ID && process.env.FIREBASE_PRIVATE_KEY && process.env.FIREBASE_CLIENT_EMAIL) {
  try {
    // Handle potential missing line breaks in private key if passed as a single line
    let privateKey = process.env.FIREBASE_PRIVATE_KEY;
    if (!privateKey.includes('-----BEGIN PRIVATE KEY-----')) {
      // If it's just a hex or raw string, this might still fail, but we'll try to format it
      // if it's a standard RSA key from Firebase
      console.warn('⚠️ FIREBASE_PRIVATE_KEY format looks unusual. Ensure it is a valid PEM key.');
    }
    
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        privateKey: privateKey.replace(/\\n/g, '\n'),
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      }),
    });
    console.log('🔥 Firebase Admin initialized from individual env vars');
  } catch (error) {
    console.error('❌ Failed to initialize Firebase Admin from env vars:', error);
  }
} else {
  console.warn('⚠️ Firebase credentials not set. Push notifications will be mocked.');
}

async function sendPushNotificationJob(job: any) {
  const { name } = job;
  const data = job.data;

  if (name === 'notify') {
    // Handle "New Note from Followed Creator" notification
    const { noteId, userId } = data;
    
    // 1. Get creator info and note title
    const [{ data: creator }, { data: note }] = await Promise.all([
      supabase.from('users').select('full_name, username').eq('id', userId).single(),
      supabase.from('notes').select('title').eq('id', noteId).single(),
    ]);

    if (!creator || !note) return;

    // 2. Get followers' FCM tokens
    const { data: followers } = await supabase
      .from('follows')
      .select('follower:users(id, fcm_token)')
      .eq('following_id', userId);

    if (!followers || followers.length === 0) return;

    const tokens = followers
      .map((f: any) => f.follower?.fcm_token)
      .filter((t: string) => !!t);

    if (tokens.length === 0) return;

    const title = 'New Note! 📄';
    const body = `${creator.full_name} (@${creator.username}) just uploaded: ${note.title}`;

    await sendToTokens(tokens, title, body, { noteId, type: 'note_published' });

  } else {
    // Handle direct "send-push" or other types
    const { noteId, userId, type, title, body, targetUserId, roomId } = data;

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

    await sendToTokens([user.fcm_token], title, body, { 
      noteId: noteId || '', 
      type: type || 'system',
      roomId: roomId || ''
    });
  }
}

async function sendToTokens(tokens: string[], title: string, body: string, data: any) {
  const firebaseReady = admin.apps.length > 0;

  if (firebaseReady) {
    try {
      // Send in batches of 500
      const BATCH = 500;
      for (let i = 0; i < tokens.length; i += BATCH) {
        const batch = tokens.slice(i, i + BATCH);
        const messages = batch.map(token => ({
          token,
          notification: { title, body },
          data: data,
          android: {
            priority: 'high' as const,
            notification: {
              channelId: 'notesnet_high_importance',
              sound: 'default',
            },
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
              },
            },
          },
        }));

        await admin.messaging().sendEach(messages);
      }
      console.log(`📱 Push notification sent: ${title} to ${tokens.length} tokens`);
    } catch (error) {
      console.error(`❌ Failed to send push notifications:`, error);
    }
  } else {
    console.log(`📱 [MOCKED] Push notification sent: ${title} to ${tokens.length} tokens`);
  }
}

export const pushNotificationWorker = new Worker(
  'notify-followers',
  sendPushNotificationJob,
  { connection: redis, concurrency: 10 }
);

