-- ══════════════════════════════════════════════════════════════════════════════
-- Migration 013: Fix note delete — decrement notes_count on user
-- ══════════════════════════════════════════════════════════════════════════════

-- Trigger: when a note's status changes to 'removed', decrement notes_count
create or replace function public.on_note_removed()
returns trigger as $$
begin
  -- Only fire when status changes TO 'removed' from an active state
  if new.status = 'removed' and old.status in ('active', 'processing', 'draft') then
    update public.users
    set notes_count = greatest(notes_count - 1, 0),
        updated_at  = now()
    where id = new.user_id;

    -- Also update folder count if note was in a folder
    if old.folder_id is not null then
      update public.folders
      set notes_count = greatest(notes_count - 1, 0)
      where id = old.folder_id;
    end if;
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists trigger_note_removed on public.notes;
create trigger trigger_note_removed
  after update on public.notes
  for each row execute function public.on_note_removed();

-- Also grant delete on folders to authenticated (for folder delete)
grant delete on public.folders to authenticated;
grant update on public.notes to authenticated;
