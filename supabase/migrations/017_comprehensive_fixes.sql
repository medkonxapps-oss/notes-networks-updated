-- ═══════════════════════════════════════════════════════════════════════════════
-- Migration 017: Comprehensive fixes — security, scalability, like/save idempotency
-- ═══════════════════════════════════════════════════════════════════════════════

-- ── 1. FOLLOWERS / FOLLOWING COUNT RPC FUNCTIONS 





create or replace function public.increment_follower_count(target_user_id uuid)
returns void language plpgsql security definer as $$
begin
  update public.users set followers_count = followers_count + 1 where id = target_user_id;
end;
$$;

create or replace function public.decrement_follower_count(target_user_id uuid)
returns void language plpgsql security definer as $$
begin
  update public.users set followers_count = greatest(followers_count - 1, 0) where id = target_user_id;
end;
$$;

create or replace function public.increment_following_count(target_user_id uuid)
returns void language plpgsql security definer as $$
begin
  update public.users set following_count = following_count + 1 where id = target_user_id;
end;
$$;

create or replace function public.decrement_following_count(target_user_id uuid)
returns void language plpgsql security definer as $$
begin
  update public.users set following_count = greatest(following_count - 1, 0) where id = target_user_id;
end;
$$;

-- ── 2. LIKE/SAVE UPSERT FUNCTIONS (fix double-toggle from race conditions) ──
-- These replace the app-level insert-then-delete with atomic DB-level toggles.
-- The app still works with insert/delete but these RPC versions are safer.

create or replace function public.toggle_like(p_note_id uuid, p_user_id uuid)
returns jsonb language plpgsql security definer as $$
declare
  v_exists boolean;
  v_author_id uuid;
  v_note_title text;
  v_user_name text;
begin
  -- Check if like already exists
  select exists(select 1 from public.likes where note_id = p_note_id and user_id = p_user_id)
  into v_exists;

  if v_exists then
    -- Unlike
    delete from public.likes where note_id = p_note_id and user_id = p_user_id;
    return jsonb_build_object('action', 'unliked', 'is_liked', false);
  else
    -- Like (ON CONFLICT DO NOTHING for safety)
    insert into public.likes (note_id, user_id) values (p_note_id, p_user_id)
    on conflict (user_id, note_id) do nothing;

    -- Notify author
    select user_id, title into v_author_id, v_note_title from public.notes where id = p_note_id;
    select full_name into v_user_name from public.users where id = p_user_id;

    if v_author_id != p_user_id then
      insert into public.notifications (user_id, type, title, message, reference_id)
      values (v_author_id, 'like', 'New Like',
        v_user_name || ' liked your note: ' || v_note_title, p_note_id)
      on conflict do nothing;
    end if;

    return jsonb_build_object('action', 'liked', 'is_liked', true);
  end if;
end;
$$;

create or replace function public.toggle_save(p_note_id uuid, p_user_id uuid)
returns jsonb language plpgsql security definer as $$
declare
  v_exists boolean;
  v_author_id uuid;
  v_note_title text;
  v_user_name text;
begin
  select exists(select 1 from public.saves where note_id = p_note_id and user_id = p_user_id)
  into v_exists;

  if v_exists then
    delete from public.saves where note_id = p_note_id and user_id = p_user_id;
    return jsonb_build_object('action', 'unsaved', 'is_saved', false);
  else
    insert into public.saves (note_id, user_id) values (p_note_id, p_user_id)
    on conflict (user_id, note_id) do nothing;

    select user_id, title into v_author_id, v_note_title from public.notes where id = p_note_id;
    select full_name into v_user_name from public.users where id = p_user_id;

    if v_author_id != p_user_id then
      insert into public.notifications (user_id, type, title, message, reference_id)
      values (v_author_id, 'like', 'Note Saved',
        v_user_name || ' saved your note: ' || v_note_title, p_note_id)
      on conflict do nothing;
    end if;

    return jsonb_build_object('action', 'saved', 'is_saved', true);
  end if;
end;
$$;

-- ── 3. SECURITY: Grant execute on new functions to authenticated users ────────
grant execute on function public.toggle_like(uuid, uuid) to authenticated;
grant execute on function public.toggle_save(uuid, uuid) to authenticated;
grant execute on function public.increment_follower_count(uuid) to authenticated;
grant execute on function public.decrement_follower_count(uuid) to authenticated;
grant execute on function public.increment_following_count(uuid) to authenticated;
grant execute on function public.decrement_following_count(uuid) to authenticated;

-- ── 4. PERFORMANCE INDEXES ────────────────────────────────────────────────────
-- Indexes for fast followers/following list queries
create index if not exists idx_follows_following_id_created on public.follows(following_id, created_at desc);
create index if not exists idx_follows_follower_id_created on public.follows(follower_id, created_at desc);

-- Composite index for feed queries (most common bottleneck)
create index if not exists idx_notes_feed_score_status_visibility
  on public.notes(feed_score desc, status, visibility);

-- Index for subject-filtered feeds
create index if not exists idx_notes_subject_status
  on public.notes(subject, status, feed_score desc);

-- Index for user notes by folder
create index if not exists idx_notes_user_folder_status
  on public.notes(user_id, folder_id, status);

-- Index for notifications per user (unread count is called often)
create index if not exists idx_notifications_user_read
  on public.notifications(user_id, is_read, created_at desc);

-- Index for leaderboard queries
create index if not exists idx_users_points_active
  on public.users(total_points desc) where is_active = true;

-- Index for likes lookup (is_liked check)
create index if not exists idx_likes_user_note on public.likes(user_id, note_id);
create index if not exists idx_saves_user_note on public.saves(user_id, note_id);

-- ── 5. SECURITY: Tighten RLS Policies ─────────────────────────────────────────

-- Follows: Users can only manage their own follows
drop policy if exists "Users can manage their follows" on public.follows;
create policy "Users can insert their own follows" on public.follows
  for insert to authenticated
  with check (auth.uid() = follower_id and follower_id != following_id);

create policy "Users can delete their own follows" on public.follows
  for delete to authenticated
  using (auth.uid() = follower_id);

create policy "Anyone can view follows" on public.follows
  for select to authenticated
  using (true);

-- Notifications: Users can only see their own
drop policy if exists "Users can view their notifications" on public.notifications;
create policy "Users can view their own notifications" on public.notifications
  for select to authenticated
  using (auth.uid() = user_id);

create policy "Users can update their own notifications" on public.notifications
  for update to authenticated
  using (auth.uid() = user_id);

-- Reports: Users can only submit, not read others'
drop policy if exists "Users can create reports" on public.reports;
create policy "Users can insert reports" on public.reports
  for insert to authenticated
  with check (auth.uid() = reporter_id);

-- ── 6. FEED SCORE FUNCTION (improved algorithm) ───────────────────────────────
create or replace function public.compute_feed_score(
  p_likes integer, p_saves integer, p_views integer,
  p_created_at timestamptz, p_is_sponsored boolean
)
returns float language plpgsql immutable as $$
declare
  age_hours float;
  gravity float := 1.5;
  score float;
begin
  age_hours := greatest(extract(epoch from (now() - p_created_at)) / 3600.0, 0.1);
  score := (p_likes * 3.0 + p_saves * 5.0 + p_views * 0.1) / power(age_hours + 2, gravity);
  if p_is_sponsored then score := score * 1.5; end if;
  return score;
end;
$$;

-- Trigger to recompute feed_score on likes/saves/views update
create or replace function public.refresh_feed_score()
returns trigger language plpgsql security definer as $$
begin
  update public.notes set
    feed_score = public.compute_feed_score(likes_count, saves_count, views_count, created_at, is_sponsored)
  where id = new.id;
  return new;
end;
$$;

drop trigger if exists trigger_refresh_feed_score on public.notes;
create trigger trigger_refresh_feed_score
  after update of likes_count, saves_count, views_count on public.notes
  for each row execute function public.refresh_feed_score();

-- ── 7. FOLLOWERS/FOLLOWING COUNT SYNC TRIGGER ─────────────────────────────────
-- Ensure follower/following counts stay in sync via DB triggers
-- (more reliable than RPC calls from app)
create or replace function public.sync_follow_counts()
returns trigger language plpgsql security definer as $$
begin
  if TG_OP = 'INSERT' then
    update public.users set followers_count = followers_count + 1 where id = new.following_id;
    update public.users set following_count = following_count + 1 where id = new.follower_id;
    return new;
  elsif TG_OP = 'DELETE' then
    update public.users set followers_count = greatest(followers_count - 1, 0) where id = old.following_id;
    update public.users set following_count = greatest(following_count - 1, 0) where id = old.follower_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists trigger_sync_follow_counts on public.follows;
create trigger trigger_sync_follow_counts
  after insert or delete on public.follows
  for each row execute function public.sync_follow_counts();

-- ── 8. SAVE NOTIFICATION TYPE FIX ─────────────────────────────────────────────
-- The notification type check constraint doesn't include 'save'
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check
  check (type in ('like', 'follow', 'reward', 'system', 'streak', 'save'));

-- ── 9. ADMIN HELPER: Resync all counts (run once to fix existing data) ─────────
create or replace function public.admin_resync_all_counts()
returns void language plpgsql security definer as $$
begin
  -- Resync notes like/save counts from actual rows
  update public.notes n set
    likes_count = (select count(*) from public.likes l where l.note_id = n.id),
    saves_count = (select count(*) from public.saves s where s.note_id = n.id);

  -- Resync user follower/following counts
  update public.users u set
    followers_count = (select count(*) from public.follows f where f.following_id = u.id),
    following_count = (select count(*) from public.follows f where f.follower_id = u.id),
    notes_count = (select count(*) from public.notes n where n.user_id = u.id and n.status = 'active');

  -- Refresh all feed scores
  update public.notes set
    feed_score = public.compute_feed_score(likes_count, saves_count, views_count, created_at, is_sponsored)
  where status = 'active';
end;
$$;

grant execute on function public.admin_resync_all_counts() to authenticated;

-- ── 10. SOFT DELETE for follows (preserve history) ───────────────────────────
-- Add deleted_at to follows for audit trail (optional enhancement)
alter table public.follows add column if not exists deleted_at timestamptz;
