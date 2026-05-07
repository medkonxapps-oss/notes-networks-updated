-- ── 019: Add missing admin_resync_all_counts and updated compute_feed_score ────
-- These functions were defined in 017 but may not have been applied to the DB.
-- Running create or replace is safe and idempotent.

-- ── 1. Updated compute_feed_score (multi-param version) ──────────────────────
create or replace function public.compute_feed_score(
  p_likes integer,
  p_saves integer,
  p_views integer,
  p_created_at timestamptz,
  p_is_sponsored boolean
)
returns float
language plpgsql
immutable
security definer
set search_path = public
as $$
declare
  age_hours float;
  gravity   float := 1.5;
  score     float;
begin
  age_hours := greatest(extract(epoch from (now() - p_created_at)) / 3600.0, 0.1);
  score := (p_likes * 3.0 + p_saves * 5.0 + p_views * 0.1) / power(age_hours + 2, gravity);
  if p_is_sponsored then score := score * 1.5; end if;
  return score;
end;
$$;

-- ── 2. Trigger to recompute feed_score on likes/saves/views update ────────────
create or replace function public.refresh_feed_score()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.notes
  set feed_score = public.compute_feed_score(likes_count, saves_count, views_count, created_at, is_sponsored)
  where id = new.id;
  return new;
end;
$$;

drop trigger if exists trigger_refresh_feed_score on public.notes;
create trigger trigger_refresh_feed_score
  after update of likes_count, saves_count, views_count on public.notes
  for each row execute function public.refresh_feed_score();

-- ── 3. admin_resync_all_counts ────────────────────────────────────────────────
-- security definer + set search_path bypasses RLS so bulk updates work.
-- WHERE true is explicit to satisfy Supabase's safe-update check.
create or replace function public.admin_resync_all_counts()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Resync notes like/save counts from actual rows (all notes, no filter needed)
  update public.notes n
  set
    likes_count = (select count(*) from public.likes l where l.note_id = n.id),
    saves_count = (select count(*) from public.saves s where s.note_id = n.id)
  where n.deleted_at is null;

  -- Resync user follower/following/notes counts
  update public.users u
  set
    followers_count = (select count(*) from public.follows f where f.following_id = u.id),
    following_count = (select count(*) from public.follows f where f.follower_id  = u.id),
    notes_count     = (select count(*) from public.notes  n where n.user_id = u.id and n.status = 'active' and n.deleted_at is null)
  where u.deleted_at is null;

  -- Refresh feed scores for all active notes
  update public.notes
  set feed_score = public.compute_feed_score(likes_count, saves_count, views_count, created_at, is_sponsored)
  where status = 'active'
    and deleted_at is null;
end;
$$;

-- Grant execute to authenticated (admin panel uses authenticated role)
grant execute on function public.admin_resync_all_counts() to authenticated;
grant execute on function public.compute_feed_score(integer, integer, integer, timestamptz, boolean) to authenticated;
grant execute on function public.refresh_feed_score() to authenticated;
