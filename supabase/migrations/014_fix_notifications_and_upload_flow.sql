-- ══════════════════════════════════════════════════════════════════════════════
-- Migration 014: Fix notifications + make all uploads require admin review
-- ══════════════════════════════════════════════════════════════════════════════

-- ── 1. Fix notifications table permissions ────────────────────────────────────
-- Triggers run as security definer but the table still needs grants
grant select, insert, update on public.notifications to authenticated;
grant insert on public.notifications to service_role;

-- Drop and recreate notification policies cleanly
drop policy if exists "notifications_select_own"   on public.notifications;
drop policy if exists "notifications_update_own"   on public.notifications;
drop policy if exists "notifications_insert_system" on public.notifications;
drop policy if exists "notifications_own"          on public.notifications;

-- Users can read and update (mark read) their own notifications
create policy "notifications_select_own" on public.notifications
  for select using (auth.uid() = user_id);

create policy "notifications_update_own" on public.notifications
  for update using (auth.uid() = user_id);

-- Inserts come from DB triggers (security definer) and admin panel — allow all inserts
create policy "notifications_insert_any" on public.notifications
  for insert with check (true);

-- ── 2. Fix likes trigger — ensure notification insert works ───────────────────
create or replace function public.update_likes_count()
returns trigger as $$
begin
  if tg_op = 'INSERT' then
    update public.notes
    set likes_count = likes_count + 1, updated_at = now()
    where id = new.note_id;

    -- Award +5 points to note owner (not if self-like)
    update public.users
    set total_points = total_points + 5, updated_at = now()
    where id = (select user_id from public.notes where id = new.note_id)
      and id != new.user_id;

    insert into public.points_ledger (user_id, event_type, points, reference_id)
    select user_id, 'like_received', 5, new.note_id
    from public.notes
    where id = new.note_id and user_id != new.user_id;

    -- Send notification to note owner (not if self-like)
    insert into public.notifications (user_id, type, title, message, reference_id)
    select
      n.user_id,
      'like',
      'New Like! +5 pts',
      'Someone liked your note "' || n.title || '"',
      new.note_id
    from public.notes n
    where n.id = new.note_id
      and n.user_id != new.user_id;

  elsif tg_op = 'DELETE' then
    update public.notes
    set likes_count = greatest(likes_count - 1, 0)
    where id = old.note_id;
  end if;
  return null;
end;
$$ language plpgsql security definer;

-- ── 3. Fix saves trigger — ensure notification insert works ───────────────────
create or replace function public.update_saves_count()
returns trigger as $$
begin
  if tg_op = 'INSERT' then
    update public.notes
    set saves_count = saves_count + 1, updated_at = now()
    where id = new.note_id;

    -- Award +10 points to note owner (not if self-save)
    update public.users
    set total_points = total_points + 10, updated_at = now()
    where id = (select user_id from public.notes where id = new.note_id)
      and id != new.user_id;

    insert into public.points_ledger (user_id, event_type, points, reference_id)
    select user_id, 'save_received', 10, new.note_id
    from public.notes
    where id = new.note_id and user_id != new.user_id;

  elsif tg_op = 'DELETE' then
    update public.notes
    set saves_count = greatest(saves_count - 1, 0)
    where id = old.note_id;
  end if;
  return null;
end;
$$ language plpgsql security definer;

-- ── 4. Fix follow trigger — ensure notification insert works ──────────────────
create or replace function public.update_follow_counts()
returns trigger as $$
begin
  if tg_op = 'INSERT' then
    update public.users set followers_count = followers_count + 1 where id = new.following_id;
    update public.users set following_count = following_count + 1 where id = new.follower_id;

    insert into public.notifications (user_id, type, title, message, reference_id)
    values (
      new.following_id,
      'follow',
      'New Follower!',
      'Someone started following you',
      new.follower_id
    );
  elsif tg_op = 'DELETE' then
    update public.users set followers_count = greatest(followers_count - 1, 0) where id = old.following_id;
    update public.users set following_count = greatest(following_count - 1, 0) where id = old.follower_id;
  end if;
  return null;
end;
$$ language plpgsql security definer;

-- Recreate triggers
drop trigger if exists trigger_likes_count  on public.likes;
drop trigger if exists trigger_saves_count  on public.saves;
drop trigger if exists trigger_follow_counts on public.follows;

create trigger trigger_likes_count
  after insert or delete on public.likes
  for each row execute function public.update_likes_count();

create trigger trigger_saves_count
  after insert or delete on public.saves
  for each row execute function public.update_saves_count();

create trigger trigger_follow_counts
  after insert or delete on public.follows
  for each row execute function public.update_follow_counts();

-- ── 5. Make all new notes go to pending_review by default ─────────────────────
-- Update the on_note_inserted trigger to only award points when status = 'active'
-- (not pending_review — points awarded after admin approves)
create or replace function public.on_note_inserted()
returns trigger as $$
begin
  if new.status = 'active' then
    perform public.award_upload_points(new.id, new.user_id);
  end if;
  return new;
end;
$$ language plpgsql security definer;

-- Update on_note_published to handle pending_review → active transition
create or replace function public.on_note_published()
returns trigger as $$
begin
  if new.status = 'active' and old.status in ('processing', 'draft', 'pending_review') then
    perform public.award_upload_points(new.id, new.user_id);
  end if;
  return new;
end;
$$ language plpgsql security definer;

-- ── 6. Notify admin when a new note is submitted for review ───────────────────
-- Insert a notification for all admin users when a pending_review note is created
create or replace function public.notify_admin_on_pending_review()
returns trigger as $$
begin
  if new.status = 'pending_review' then
    -- Notify all admins
    insert into public.notifications (user_id, type, title, message, reference_id)
    select id, 'system', 'New Note for Review',
      'A new note "' || new.title || '" is waiting for your review.',
      new.id
    from public.users
    where role in ('admin', 'moderator')
      and is_active = true;
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists trigger_notify_admin_review on public.notes;
create trigger trigger_notify_admin_review
  after insert on public.notes
  for each row execute function public.notify_admin_on_pending_review();
