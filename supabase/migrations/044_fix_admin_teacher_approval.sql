-- Migration 044: Fix admin teacher approval
-- Problem: is_admin() queries users table which is RLS-protected,
-- causing infinite RLS recursion → always returns false.
-- Fix: use a separate shadow table (not RLS-protected) for admin role lookup,
-- OR use set_config/current_setting trick, OR simplest: check JWT claims.
-- We use the most reliable approach: a security definer function that
-- temporarily disables RLS via a direct lookup on the underlying table.

-- 1. Create a helper that reads role WITHOUT triggering RLS
--    by using SET LOCAL row_security = off inside security definer context.
create or replace function public.get_my_role()
returns text as $$
declare
  v_role text;
begin
  -- security definer + set local row_security off bypasses RLS for this query
  set local row_security = off;
  select role into v_role from public.users where id = auth.uid();
  return v_role;
end;
$$ language plpgsql security definer stable;

-- 2. Rewrite is_admin() to use get_my_role() — no RLS recursion
create or replace function public.is_admin()
returns boolean as $$
  select public.get_my_role() in ('admin', 'moderator');
$$ language sql security definer stable;

-- 3. Drop and recreate users policies to be explicit
drop policy if exists "users_admin_all"    on public.users;
drop policy if exists "users_admin_select" on public.users;
drop policy if exists "users_admin_update" on public.users;
drop policy if exists "users_admin_delete" on public.users;
drop policy if exists "users_admin_insert" on public.users;
drop policy if exists "users_select_active" on public.users;
drop policy if exists "users_insert_own"   on public.users;
drop policy if exists "users_update_own"   on public.users;

-- Recreate clean policies
create policy "users_select" on public.users
  for select using (
    public.is_admin()
    or (deleted_at is null and is_active = true)
    or auth.uid() = id
  );

create policy "users_insert" on public.users
  for insert with check (auth.uid() = id or public.is_admin());

create policy "users_update" on public.users
  for update using (auth.uid() = id or public.is_admin());

create policy "users_delete" on public.users
  for delete using (public.is_admin());

-- 4. Dedicated security definer RPC for teacher approval
--    Bypasses RLS entirely; does its own auth check inside.
create or replace function public.admin_approve_teacher(
  target_user_id uuid,
  new_status text
)
returns void as $$
declare
  v_role text;
begin
  -- Get caller role without RLS
  set local row_security = off;
  select role into v_role from public.users where id = auth.uid();

  if v_role not in ('admin', 'moderator') then
    raise exception 'Unauthorized: admin only';
  end if;

  if new_status not in ('approved', 'rejected', 'pending') then
    raise exception 'Invalid status';
  end if;

  update public.users
  set
    teacher_status = new_status,
    role = case when new_status = 'approved' then 'teacher' else role end,
    updated_at = now()
  where id = target_user_id;
end;
$$ language plpgsql security definer;

grant execute on function public.admin_approve_teacher(uuid, text) to authenticated;
grant execute on function public.get_my_role() to authenticated;

-- 5. Fix id-cards storage policy so admin can view any ID card
drop policy if exists "Admins can view all id cards" on storage.objects;
create policy "Admins can view all id cards"
  on storage.objects for select using (
    bucket_id = 'id-cards' and public.is_admin()
  );
