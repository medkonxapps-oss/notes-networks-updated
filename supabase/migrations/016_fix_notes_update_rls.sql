-- ============================================================
-- Fix: Note delete silently fails due to RLS policy conflict.
--
-- Root cause: Supabase evaluates the USING clause of ALL SELECT
-- policies before allowing an UPDATE. The old notes_select_public
-- policy had `status = 'active'`, so updating a note's status
-- (soft-delete) was blocked because the row was already visible
-- only when active — creating a catch-22.
--
-- Fix: Split SELECT into public + owner policies, and ensure
-- UPDATE policy has no status restriction for the owner.
-- ============================================================

-- 1. Drop all old notes policies cleanly
drop policy if exists "notes_select_public"   on public.notes;
drop policy if exists "notes_select_own"      on public.notes;
drop policy if exists "notes_insert_own"      on public.notes;
drop policy if exists "notes_update_own"      on public.notes;
drop policy if exists "notes_admin_select"    on public.notes;
drop policy if exists "notes_admin_update"    on public.notes;
drop policy if exists "notes_delete_own"      on public.notes;

-- 2. Public SELECT: active + public/followers notes only
create policy "notes_select_public" on public.notes
  for select using (
    deleted_at is null
    and status = 'active'
    and (
      visibility = 'public'
      or (
        visibility = 'followers'
        and exists(
          select 1 from public.follows
          where follower_id = auth.uid()
            and following_id = notes.user_id
        )
      )
    )
  );

-- 3. Owner SELECT: can see ALL their own notes (any status, not hard-deleted)
create policy "notes_select_own" on public.notes
  for select using (
    auth.uid() = user_id
    and deleted_at is null
  );

-- 4. Admin SELECT: can see everything
create policy "notes_admin_select" on public.notes
  for select using (public.is_admin());

-- 5. Owner INSERT
create policy "notes_insert_own" on public.notes
  for insert with check (auth.uid() = user_id);

-- 6. Owner UPDATE: no status restriction — needed for soft-delete
create policy "notes_update_own" on public.notes
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- 7. Admin UPDATE
create policy "notes_admin_update" on public.notes
  for update using (public.is_admin());
