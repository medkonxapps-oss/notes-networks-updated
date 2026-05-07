-- Migration 023: Points notification on download
-- Award points and send explicit notifications when a note is downloaded.

create or replace function public.process_download(p_note_id uuid, p_user_id uuid)
returns void language plpgsql security definer as $$
declare
  v_author_id uuid;
  v_note_title text;
  v_user_name text;
begin
  select user_id, title into v_author_id, v_note_title from public.notes where id = p_note_id;
  select full_name into v_user_name from public.users where id = p_user_id;

  if v_author_id != p_user_id then
    -- Award +10 points to author
    update public.users set total_points = total_points + 10 where id = v_author_id;

    -- Add to points ledger
    insert into public.points_ledger (user_id, event_type, points, reference_id)
    values (v_author_id, 'download_received', 10, p_note_id);

    -- Notification 1: Note was downloaded
    insert into public.notifications (user_id, type, title, message, reference_id)
    values (
      v_author_id, 
      'download', 
      'Note Downloaded', 
      v_user_name || ' downloaded your note for offline: ' || v_note_title,
      p_note_id
    ) on conflict do nothing;

    -- Notification 2: Points earned
    insert into public.notifications (user_id, type, title, message, reference_id)
    values (
      v_author_id, 
      'reward', 
      '+10 Points Earned', 
      'You earned 10 points because someone downloaded your note!',
      p_note_id
    ) on conflict do nothing;
  end if;
end;
$$;
