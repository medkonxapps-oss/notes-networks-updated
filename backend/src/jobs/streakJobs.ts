import { supabase } from '../config/supabase';
import admin from 'firebase-admin';

// ── Daily Streak Reset (run at midnight) ─────────────────────────────────────
export async function runDailyStreakReset(): Promise<void> {
  console.log('🔥 Running daily streak reset...');
  try {
    const { data, error } = await supabase.rpc('reset_broken_streaks');
    if (error) throw error;
    console.log(`✅ Streak reset complete — ${data} users reset`);
  } catch (err) {
    console.error('❌ Streak reset failed:', err);
  }
}

// ── Streak Reminder Push Notifications (run at 9 PM) ─────────────────────────
export async function sendStreakReminders(): Promise<void> {
  console.log('⏰ Sending streak reminder notifications...');
  try {
    // Get users at risk of losing streak
    const { data: targets, error } = await supabase.rpc('get_streak_reminder_targets');
    if (error) throw error;
    if (!targets || targets.length === 0) {
      console.log('No streak reminder targets today');
      return;
    }

    console.log(`📣 Sending streak reminders to ${targets.length} users`);

    const firebaseReady = admin.apps.length > 0;
    let sent = 0;
    let failed = 0;

    // Send in batches of 500 (Firebase limit)
    const BATCH = 500;
    for (let i = 0; i < targets.length; i += BATCH) {
      const batch = targets.slice(i, i + BATCH);
      const messages: admin.messaging.Message[] = batch
        .filter((t: any) => !!t.fcm_token)
        .map((t: any) => ({
          token: t.fcm_token,
          notification: {
            title: `🔥 Don't break your ${t.current_streak}-day streak!`,
            body: `Hey ${t.full_name?.split(' ')[0] || 'there'}, upload a note today to keep your streak alive!`,
          },
          data: {
            type: 'streak_reminder',
            streak: String(t.current_streak),
          },
          android: {
            priority: 'high' as const,
            notification: { channelId: 'notesnet_high_importance' },
          },
        }));

      if (firebaseReady && messages.length > 0) {
        try {
          const result = await admin.messaging().sendEach(messages);
          sent += result.successCount;
          failed += result.failureCount;

          // Remove invalid tokens from DB
          const invalidTokens: string[] = [];
          result.responses.forEach((r, idx) => {
            if (!r.success && r.error?.code === 'messaging/registration-token-not-registered') {
              invalidTokens.push(batch[idx].fcm_token);
            }
          });

          if (invalidTokens.length > 0) {
            await supabase
              .from('users')
              .update({ fcm_token: null })
              .in('fcm_token', invalidTokens);
            console.log(`🗑️ Removed ${invalidTokens.length} invalid FCM tokens`);
          }
        } catch (firebaseErr) {
          console.error('Firebase batch error:', firebaseErr);
          failed += messages.length;
        }
      } else {
        // Log mock sends
        console.log(`📱 [MOCKED] Would send ${messages.length} streak reminders`);
        sent += messages.length;
      }
    }

    console.log(`✅ Streak reminders done — sent: ${sent}, failed: ${failed}`);
  } catch (err) {
    console.error('❌ Streak reminder job failed:', err);
  }
}

// ── Weekly Leaderboard Notification (run every Monday) ───────────────────────
export async function sendWeeklyLeaderboardNotification(): Promise<void> {
  console.log('🏆 Sending weekly leaderboard notifications...');
  try {
    // Get top 3 users of the week
    const { data: top3 } = await supabase
      .from('users')
      .select('id, full_name, username, total_points, fcm_token')
      .eq('is_active', true)
      .order('total_points', { ascending: false })
      .limit(3);

    if (!top3 || top3.length === 0) return;

    // Notify each top 3 user
    for (let i = 0; i < top3.length; i++) {
      const u = top3[i];
      const rank = i + 1;
      const emoji = rank === 1 ? '🥇' : rank === 2 ? '🥈' : '🥉';

      // DB notification
      await supabase.from('notifications').insert({
        user_id: u.id,
        type: 'reward',
        title: `${emoji} You're #${rank} on the leaderboard!`,
        message: `Great job! You're ranked #${rank} this week with ${u.total_points} points.`,
      }).then(({ error }) => { if (error) console.error('Notification insert error:', error); });

      // Push notification
      if (u.fcm_token && admin.apps.length > 0) {
        await admin.messaging().send({
          token: u.fcm_token,
          notification: {
            title: `${emoji} You're #${rank} on the leaderboard!`,
            body: `You have ${u.total_points} points this week. Keep it up!`,
          },
          data: { type: 'leaderboard', rank: String(rank) },
        }).catch(console.error);
      }
    }

    console.log('✅ Weekly leaderboard notifications sent');
  } catch (err) {
    console.error('❌ Weekly leaderboard notification failed:', err);
  }
}
