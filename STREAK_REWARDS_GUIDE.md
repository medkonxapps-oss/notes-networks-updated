# 🔥 Streak & Rewards System — Complete Guide

## How It Works (End-to-End)

### Points Earning
| Action | Points | Where Triggered |
|--------|--------|-----------------|
| Upload a note | +50 | DB trigger `on_note_inserted` / `on_note_published` |
| First ever upload | +100 | Same trigger (one-time bonus) |
| Receive a like | +5 | DB trigger `update_likes_count` |
| Receive a save | +10 | DB trigger `update_saves_count` |
| Note downloaded | +10 | RPC `process_download()` called from app |
| Daily streak bonus | +25 | `update_streak_on_upload()` called inside upload trigger |
| 7-day milestone | +100 | Same, when streak hits 7 |
| 30-day milestone | +500 | Same, when streak hits 30 |
| 100-day milestone | +2000 | Same, when streak hits 100 |
| Verification bonus | +200 | Admin manually grants |

---

### Streak Logic (DB function: `update_streak_on_upload`)
- **Consecutive day** (last_upload_date = yesterday) → streak +1
- **Same day** (already uploaded today) → no change, no double bonus
- **Gap of 2+ days** → streak resets to 1
- **First upload ever** → streak starts at 1
- **Streak is updated atomically** inside `award_upload_points` — no race condition

### Streak Reset (Backend cron: midnight daily)
```
cron.schedule('0 0 * * *', runDailyStreakReset)
```
Calls DB function `reset_broken_streaks()` which resets `current_streak = 0`
for any user whose `last_upload_date < current_date - 1 day`.

### Streak Reminders (Backend cron: 9 PM daily)
```
cron.schedule('0 21 * * *', sendStreakReminders)
```
Calls `get_streak_reminder_targets()` — returns users with active streaks
who haven't uploaded today AND have `notification_preferences.streaks = true`.
Sends FCM push via Firebase Admin in batches of 500.
Invalid tokens are auto-cleaned from DB.

---

### Badges
| Badge Type | Trigger |
|-----------|---------|
| `upload_count` | Awarded at 1, 10, 50, 100 notes |
| `streak` | Awarded at 7-day and 30-day streak |
| `verified` | Awarded when admin verifies creator |
| `total_likes` | (future — extend `award_upload_points`) |

All awarded via `award_badge_if_new(user_id, badge_type)` — idempotent, safe to call multiple times.

---

### Reward Redemption (Atomic — no race conditions)
1. User taps "Redeem" in app
2. App calls `rewardsService.redeem(rewardId)` 
3. Service calls Supabase RPC `redeem_reward(p_reward_id, p_user_id)`
4. DB function:
   - `SELECT ... FOR UPDATE` locks reward row (prevents double-spend)
   - `SELECT ... FOR UPDATE` locks user row (prevents concurrent deductions)
   - Checks stock > 0 and user points >= cost
   - Atomically deducts points + decrements stock + creates redemption record
   - Notifies user
5. Returns `{success, remaining_points, reward_name}` or `{success: false, error: "..."}`

### Redemption Cancellation (Auto refund)
- Admin cancels redemption in admin panel → Flutter updates DB status to 'cancelled'
- DB trigger `trigger_redemption_cancel` fires → auto refunds points + restores stock
- Safety net: refund is idempotent (trigger only fires on status change TO 'cancelled')

---

## Files Changed

### Database
- `supabase/migrations/052_complete_streak_rewards_system.sql`
  - `update_streak_on_upload(user_id)` — complete streak logic
  - `award_upload_points(note_id, user_id)` — integrated streak + badges
  - `reset_broken_streaks()` — daily cron target
  - `get_streak_reminder_targets()` — 9PM cron target
  - `redeem_reward(reward_id, user_id)` — atomic with row locks
  - `handle_redemption_cancellation()` — auto refund trigger
  - `award_badge_if_new(user_id, badge_type)` — idempotent badge award
  - `points_ledger` constraint update (adds 'redemption' type)
  - Performance indexes for streak queries

### Backend
- `backend/src/jobs/streakJobs.ts` (NEW)
  - `runDailyStreakReset()` — calls `reset_broken_streaks()` RPC
  - `sendStreakReminders()` — FCM batch push with invalid token cleanup
  - `sendWeeklyLeaderboardNotification()` — top 3 get push + DB notification
- `backend/src/index.ts`
  - Wired streak cron jobs (were empty stubs before)

### Flutter App
- `packages/shared/lib/services/rewards_service.dart`
  - `redeem(rewardId)` — now uses atomic `redeem_reward` RPC (no race condition)
  - `getStreakInfo()` — returns `StreakInfo` with `uploadedToday` check
  - `getMyBadges()` — returns `List<UserBadge>` with badge metadata
  - `getPointsHistory()` — returns `List<PointsEvent>` with labels
  - New models: `StreakInfo`, `UserBadge`, `PointsEvent`

- `packages/app/lib/features/rewards/screens/rewards_screen.dart` (REWRITE)
  - 3 tabs: **Streak** / **Redeem** / **History**
  - Streak tab: live streak card (shows if uploaded today), milestone progress bars, badges grid, how-to-earn table
  - Redeem tab: reward grid with stock indicator, proper locked/sold-out states
  - History tab: points ledger with event labels and time-ago

- `packages/app/lib/features/rewards/screens/redemption_history_screen.dart` (REWRITE)
  - Summary banner: total spent, pending count, delivered count
  - Each card: status timeline dots, status-specific messages, refund message on cancel

- `packages/app/lib/features/upload/screens/upload_success_screen.dart`
  - Dynamic `_UploadRewardSummary` widget shows actual streak + bonus breakdown

- `packages/app/lib/shared/providers/providers.dart`
  - Added `streakInfoProvider`, `myBadgesProvider`, `pointsHistoryProvider`

### Admin Panel
- `packages/admin/lib/features/rewards_mgr/redemptions_tab.dart`
  - `_updateStatus()` now: notifies user, refunds points on cancel, adds to points ledger, writes audit log

---

## How to Deploy

1. **Run migration**: `supabase/migrations/052_complete_streak_rewards_system.sql`
2. **Deploy backend**: Rebuild Docker/PM2 — streak cron jobs are now live
3. **Deploy Flutter app**: Rebuild and publish

## Verifying It Works

```sql
-- Test streak update manually
select * from update_streak_on_upload('your-user-uuid');

-- Check a user's streak
select current_streak, longest_streak, last_upload_date from users where id = 'your-uuid';

-- Check points ledger  
select event_type, points, created_at from points_ledger
where user_id = 'your-uuid' order by created_at desc limit 10;

-- Simulate streak reset
select reset_broken_streaks();

-- Check streak reminder targets
select count(*) from get_streak_reminder_targets();
```
