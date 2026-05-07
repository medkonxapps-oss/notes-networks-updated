-- Migration 022: Points notification on save
-- Ensure when a user's note is saved, they get a notification about the points earned.

create or replace function public.update_saves_count()
returns trigger as $$
declare
  note_owner_id uuid;
begin
  if tg_op = 'INSERT' then
    -- Get note owner
    select user_id into note_owner_id from public.notes where id = new.note_id;

    -- Update note saves count
    update public.notes
    set saves_count = saves_count + 1, updated_at = now()
    where id = new.note_id;

    -- If not self-save, award points and notify
    if note_owner_id != new.user_id then
      -- Award +10 points to note owner
      update public.users
      set total_points = total_points + 10, updated_at = now()
      where id = note_owner_id;

      -- Add to points ledger
      insert into public.points_ledger (user_id, event_type, points, reference_id)
      values (note_owner_id, 'save_received', 10, new.note_id);

      -- Notification 1: Note was saved
      insert into public.notifications (user_id, type, title, message, reference_id)
      values (
        note_owner_id, 
        'save', 
        'New Save!', 
        'Someone saved your note: ' || (select title from public.notes where id = new.note_id),
        new.note_id
      );

      -- Notification 2: Points earned
      insert into public.notifications (user_id, type, title, message, reference_id)
      values (
        note_owner_id, 
        'reward', 
        '+10 Points Earned', 
        'You earned 10 points because someone saved your note!',
        new.note_id
      );
    end if;

  elsif tg_op = 'DELETE' then
    update public.notes
    set saves_count = greatest(saves_count - 1, 0)
    where id = old.note_id;
  end if;
  return null;
end;
$$ language plpgsql security definer;
