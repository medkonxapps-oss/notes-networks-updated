-- Migration 035: Restrict teacher uploads until approved

-- 1. Create a function to check if a user can upload
create or replace function public.can_user_upload(user_id uuid)
returns boolean as $$
declare
  user_role text;
  t_status text;
begin
  select role, teacher_status into user_role, t_status
  from public.users
  where id = user_id;

  -- If user is a teacher, they must be approved
  if user_role = 'teacher' then
    return t_status = 'approved';
  end if;

  -- Other roles (student, creator, admin, moderator) can upload
  -- (Assuming creators are already approved or don't need this specific check)
  return true;
end;
$$ language plpgsql security definer;

-- 2. Update notes insert policy
drop policy if exists "notes_insert_own" on public.notes;
create policy "notes_insert_own" on public.notes
  for insert with check (
    auth.uid() = user_id 
    and public.can_user_upload(auth.uid())
  );

-- 3. Also restrict folder creation for unapproved teachers
drop policy if exists "folders_insert" on public.folders;
create policy "folders_insert" on public.folders
  for insert with check (
    auth.uid() = user_id
    and public.can_user_upload(auth.uid())
  );
