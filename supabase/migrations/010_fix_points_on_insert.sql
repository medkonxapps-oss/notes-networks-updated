-- ══════════════════════════════════════════════════════════════════════════════
-- Migration 010: Fix points awarded on note INSERT (not just UPDATE)
-- The app now inserts notes directly as 'active', so the existing trigger
-- (which only fires on UPDATE processing→active) never ran.
-- ══════════════════════════════════════════════════════════════════════════════

-- ── 0. Ensure compute_feed_score exists (migration 003 may not have run) ──────
create or replace function public.compute_feed_score(p_note_id uuid)
returns float as $$
declare
  n           public.notes%rowtype;
  hours_old   float;
  recency     float;
  base_score  float;
begin
  select * into n from public.notes where id = p_note_id;
  if not found then return 0; end if;
  hours_old  := extract(epoch from (now() - n.created_at)) / 3600.0;
  recency    := 1.0 / (1.0 + hours_old * 0.05);
  base_score := (n.likes_count * 2.0) + (n.saves_count * 3.0) + (n.views_count * 0.5);
  return base_score * recency;
end;
$$ language plpgsql;

-- ── 1. Function that handles points + counts for a newly active note ──────────
create or replace function public.award_upload_points(p_note_id uuid, p_user_id uuid)
returns void as $$
declare
  v_is_first boolean;
  v_points   integer;
begin
  -- Check if this is the user's first ever active note
  select not exists(
    select 1 from public.notes
    where user_id = p_user_id
      and status = 'active'
      and id != p_note_id
      and deleted_at is null
  ) into v_is_first;

  -- Base upload points
  v_points := 50;

  -- Insert upload event into ledger
  insert into public.points_ledger (user_id, event_type, points, reference_id)
  values (p_user_id, 'upload', 50, p_note_id);

  -- First upload bonus
  if v_is_first then
    insert into public.points_ledger (user_id, event_type, points, reference_id)
    values (p_user_id, 'first_upload', 100, p_note_id);
    v_points := v_points + 100;
  end if;

  -- Update user: total_points, notes_count, last_upload_date
  update public.users
  set
    total_points     = total_points + v_points,
    notes_count      = notes_count + 1,
    last_upload_date = current_date,
    updated_at       = now()
  where id = p_user_id;

  -- Update folder count if note is in a folder
  update public.folders f
  set notes_count = notes_count + 1
  from public.notes n
  where n.id = p_note_id
    and n.folder_id = f.id
    and n.folder_id is not null;

  -- Compute initial feed score
  update public.notes
  set feed_score = public.compute_feed_score(p_note_id)
  where id = p_note_id;
end;
$$ language plpgsql security definer;

-- ── 2. Trigger function for INSERT ────────────────────────────────────────────
create or replace function public.on_note_inserted()
returns trigger as $$
begin
  -- Only award points when note is inserted directly as 'active'
  if new.status = 'active' then
    perform public.award_upload_points(new.id, new.user_id);
  end if;
  return new;
end;
$$ language plpgsql security definer;

-- ── 3. Trigger function for UPDATE (processing → active) ─────────────────────
create or replace function public.on_note_published()
returns trigger as $$
begin
  -- Only fire when status changes from processing/draft → active
  if new.status = 'active' and old.status in ('processing', 'draft') then
    perform public.award_upload_points(new.id, new.user_id);
  end if;
  return new;
end;
$$ language plpgsql security definer;

-- ── 4. Drop old trigger and recreate both ─────────────────────────────────────
drop trigger if exists trigger_note_published on public.notes;
drop trigger if exists trigger_note_inserted  on public.notes;

-- INSERT trigger — fires when app inserts note directly as 'active'
create trigger trigger_note_inserted
  after insert on public.notes
  for each row execute function public.on_note_inserted();

-- UPDATE trigger — fires when backend worker changes processing → active
create trigger trigger_note_published
  after update on public.notes
  for each row execute function public.on_note_published();

-- ── 5. Fix likes trigger — also deduct points when like is removed ────────────
create or replace function public.update_likes_count()
returns trigger as $$
begin
  if tg_op = 'INSERT' then
    -- Increment note likes count
    update public.notes
    set likes_count = likes_count + 1, updated_at = now()
    where id = new.note_id;

    -- Award +5 points to note owner (not the liker)
    insert into public.points_ledger (user_id, event_type, points, reference_id)
    select user_id, 'like_received', 5, new.note_id
    from public.notes where id = new.note_id;

    update public.users
    set total_points = total_points + 5, updated_at = now()
    where id = (select user_id from public.notes where id = new.note_id)
      -- Don't award points if user liked their own note
      and id != new.user_id;

    -- Notify note owner
    insert into public.notifications (user_id, type, title, message, reference_id)
    select user_id, 'like', 'New Like! +5 pts', 'Someone liked your note', new.note_id
    from public.notes
    where id = new.note_id and user_id != new.user_id;

  elsif tg_op = 'DELETE' then
    update public.notes
    set likes_count = greatest(likes_count - 1, 0)
    where id = old.note_id;
  end if;
  return null;
end;
$$ language plpgsql security definer;

-- ── 6. Fix saves trigger — also deduct points when save is removed ────────────
create or replace function public.update_saves_count()
returns trigger as $$
begin
  if tg_op = 'INSERT' then
    -- Increment note saves count
    update public.notes
    set saves_count = saves_count + 1, updated_at = now()
    where id = new.note_id;

    -- Award +10 points to note owner (not the saver)
    insert into public.points_ledger (user_id, event_type, points, reference_id)
    select user_id, 'save_received', 10, new.note_id
    from public.notes where id = new.note_id;

    update public.users
    set total_points = total_points + 10, updated_at = now()
    where id = (select user_id from public.notes where id = new.note_id)
      -- Don't award points if user saved their own note
      and id != new.user_id;

  elsif tg_op = 'DELETE' then
    update public.notes
    set saves_count = greatest(saves_count - 1, 0)
    where id = old.note_id;
  end if;
  return null;
end;
$$ language plpgsql security definer;

-- Recreate triggers for likes and saves
drop trigger if exists trigger_likes_count on public.likes;
drop trigger if exists trigger_saves_count on public.saves;

create trigger trigger_likes_count
  after insert or delete on public.likes
  for each row execute function public.update_likes_count();

create trigger trigger_saves_count
  after insert or delete on public.saves
  for each row execute function public.update_saves_count();

-- ── 7. Backfill: award points for notes already uploaded as 'active' ──────────
-- Run this once to fix existing notes that never got points
do $$
declare
  r record;
begin
  for r in
    select id, user_id from public.notes
    where status = 'active'
      and deleted_at is null
      -- Only backfill if user has 0 upload points (never got them)
      and not exists (
        select 1 from public.points_ledger
        where user_id = notes.user_id
          and event_type = 'upload'
          and reference_id = notes.id
      )
  loop
    perform public.award_upload_points(r.id, r.user_id);
  end loop;
end;
$$;
