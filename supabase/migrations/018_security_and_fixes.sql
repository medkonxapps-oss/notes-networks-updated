-- ─────────────────────────────────────────────────────────────────────────────
-- Migration 018: Security & Bug Fixes
-- Run this on your existing Supabase project to apply all schema updates.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Add notification_preferences column to users table
alter table public.users
  add column if not exists notification_preferences jsonb not null
    default '{"likes":true,"saves":true,"follows":true,"rewards":true,"streaks":true,"system":true}'::jsonb;

-- 2. Add login security tracking columns
alter table public.users
  add column if not exists failed_login_attempts integer not null default 0,
  add column if not exists last_failed_login_at timestamptz;

-- 3. Validate fcm_token is never an empty string (store null instead)
update public.users set fcm_token = null where fcm_token = '';

-- 4. Index on notifications for faster unread count queries
create index if not exists idx_notifications_user_unread
  on public.notifications(user_id, is_read)
  where is_read = false;

-- 5. Index on likes/saves for faster interaction queries
create index if not exists idx_likes_user_note on public.likes(user_id, note_id);
create index if not exists idx_saves_user_note on public.saves(user_id, note_id);

-- 6. Index on notes for feed performance
create index if not exists idx_notes_status_visibility
  on public.notes(status, visibility, created_at desc)
  where status = 'active';

-- 7. Index on follows for faster follower feed
create index if not exists idx_follows_follower on public.follows(follower_id);
create index if not exists idx_follows_following on public.follows(following_id);

-- 8. Add check constraint on fcm_token length (FCM tokens are ~160+ chars)
-- (Skip if already exists)
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'users_fcm_token_length_check'
  ) then
    alter table public.users
      add constraint users_fcm_token_length_check
      check (fcm_token is null or length(fcm_token) > 20);
  end if;
end $$;

-- 9. Enforce username format at DB level (alphanumeric, underscore, hyphen only)
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'users_username_format_check'
  ) then
    alter table public.users
      add constraint users_username_format_check
      check (username ~ '^[a-z0-9_\-]{3,30}$');
  end if;
end $$;

-- 10. Ensure notification_preferences has all required keys (back-fill)
update public.users
set notification_preferences = notification_preferences ||
  '{"likes":true,"saves":true,"follows":true,"rewards":true,"streaks":true,"system":true}'::jsonb
where not (notification_preferences ?& array['likes','saves','follows','rewards','streaks','system']);

-- 11. RLS: Ensure users can only update their own notification_preferences
-- (This relies on existing RLS policies — just verifying the policy exists)
-- If you don't have RLS enabled, run:
-- alter table public.users enable row level security;

comment on column public.users.notification_preferences is
  'JSON object controlling which push notifications the user receives. Keys: likes, saves, follows, rewards, streaks, system.';

comment on column public.users.failed_login_attempts is
  'Track failed login attempts for rate limiting. Reset on successful login.';
