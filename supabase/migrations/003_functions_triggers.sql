-- ── TRIGGER: likes_count ────────────────────────────────────────────────────────
create or replace function public.update_likes_count()
returns trigger as $$
begin
  if tg_op = 'INSERT' then
    update public.notes set likes_count = likes_count + 1, updated_at = now() where id = new.note_id;
    insert into public.points_ledger (user_id, event_type, points, reference_id)
      select user_id, 'like_received', 5, new.note_id from public.notes where id = new.note_id;
    update public.users set total_points = total_points + 5
      where id = (select user_id from public.notes where id = new.note_id);
    -- Send notification to note owner
    insert into public.notifications (user_id, type, title, message, reference_id)
      select user_id, 'like', 'New Like!', 'Someone liked your note', new.note_id
      from public.notes where id = new.note_id and user_id != new.user_id;
  elsif tg_op = 'DELETE' then
    update public.notes set likes_count = greatest(likes_count - 1, 0) where id = old.note_id;
  end if;
  return null;
end;
$$ language plpgsql security definer;

create trigger trigger_likes_count
  after insert or delete on public.likes
  for each row execute function public.update_likes_count();

-- ── TRIGGER: saves_count ────────────────────────────────────────────────────────
create or replace function public.update_saves_count()
returns trigger as $$
begin
  if tg_op = 'INSERT' then
    update public.notes set saves_count = saves_count + 1, updated_at = now() where id = new.note_id;
    insert into public.points_ledger (user_id, event_type, points, reference_id)
      select user_id, 'save_received', 10, new.note_id from public.notes where id = new.note_id;
    update public.users set total_points = total_points + 10
      where id = (select user_id from public.notes where id = new.note_id);
  elsif tg_op = 'DELETE' then
    update public.notes set saves_count = greatest(saves_count - 1, 0) where id = old.note_id;
  end if;
  return null;
end;
$$ language plpgsql security definer;

create trigger trigger_saves_count
  after insert or delete on public.saves
  for each row execute function public.update_saves_count();

-- ── TRIGGER: follow_counts ──────────────────────────────────────────────────────
create or replace function public.update_follow_counts()
returns trigger as $$
begin
  if tg_op = 'INSERT' then
    update public.users set followers_count = followers_count + 1 where id = new.following_id;
    update public.users set following_count = following_count + 1 where id = new.follower_id;
    -- Notify the followed user
    insert into public.notifications (user_id, type, title, message, reference_id)
      values (new.following_id, 'follow', 'New Follower!', 'Someone started following you', new.follower_id);
  elsif tg_op = 'DELETE' then
    update public.users set followers_count = greatest(followers_count - 1, 0) where id = old.following_id;
    update public.users set following_count = greatest(following_count - 1, 0) where id = old.follower_id;
  end if;
  return null;
end;
$$ language plpgsql security definer;

create trigger trigger_follow_counts
  after insert or delete on public.follows
  for each row execute function public.update_follow_counts();

-- ── TRIGGER: on_note_published ──────────────────────────────────────────────────
create or replace function public.on_note_published()
returns trigger as $$
declare
  is_first_upload boolean;
begin
  if new.status = 'active' and old.status = 'processing' then
    -- Check if this is the first upload
    select not exists(
      select 1 from public.notes
      where user_id = new.user_id and status = 'active' and id != new.id
    ) into is_first_upload;

    -- Award upload points
    insert into public.points_ledger (user_id, event_type, points, reference_id)
      values (new.user_id, 'upload', 50, new.id);

    -- Award first upload bonus
    if is_first_upload then
      insert into public.points_ledger (user_id, event_type, points, reference_id)
        values (new.user_id, 'first_upload', 100, new.id);
      update public.users set total_points = total_points + 150 where id = new.user_id;
    else
      update public.users set total_points = total_points + 50 where id = new.user_id;
    end if;

    -- Update notes_count and last_upload_date
    update public.users set
      notes_count = notes_count + 1,
      last_upload_date = current_date,
      updated_at = now()
    where id = new.user_id;

    -- Update folder count
    if new.folder_id is not null then
      update public.folders set notes_count = notes_count + 1 where id = new.folder_id;
    end if;

    -- Compute initial feed score
    update public.notes set feed_score = public.compute_feed_score(new.id)
    where id = new.id;
  end if;
  return new;
end;
$$ language plpgsql security definer;

create trigger trigger_note_published
  after update on public.notes
  for each row execute function public.on_note_published();

-- ── FUNCTION: compute feed score ────────────────────────────────────────────────
create or replace function public.compute_feed_score(p_note_id uuid)
returns float as $$
declare
  n public.notes%rowtype;
  hours_old float;
  recency_mult float;
  base_score float;
begin
  select * into n from public.notes where id = p_note_id;
  hours_old := extract(epoch from (now() - n.created_at)) / 3600;
  recency_mult := 1.0 / (1.0 + hours_old * 0.05);
  base_score := (n.likes_count * 2.0) + (n.saves_count * 3.0) + (n.views_count * 0.5);
  return base_score * recency_mult;
end;
$$ language plpgsql;

-- ── FUNCTION: batch update feed scores (called by cron) ─────────────────────────
create or replace function public.refresh_feed_scores()
returns void as $$
begin
  update public.notes
  set feed_score = public.compute_feed_score(id), updated_at = now()
  where status = 'active' and deleted_at is null;
end;
$$ language plpgsql security definer;

-- ── FUNCTION: updated_at auto-update ────────────────────────────────────────────
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger set_users_updated_at before update on public.users
  for each row execute function public.set_updated_at();
create trigger set_notes_updated_at before update on public.notes
  for each row execute function public.set_updated_at();
