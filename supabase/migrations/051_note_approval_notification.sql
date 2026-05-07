-- Migration 051: Notify user when their note is approved
create or replace function public.on_note_published()
returns trigger as $$
begin
  if new.status = 'active' and old.status in ('processing', 'draft', 'pending_review') then
    -- Award points
    perform public.award_upload_points(new.id, new.user_id);
    
    -- Notify the user
    insert into public.notifications (user_id, type, title, message, reference_id)
    values (
      new.user_id,
      'system',
      'Note Approved!',
      'Your note "' || new.title || '" has been verified and is now live! +50 points awarded.',
      new.id
    );
  end if;
  return new;
end;
$$ language plpgsql security definer;
