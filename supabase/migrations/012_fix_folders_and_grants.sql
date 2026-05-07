-- ══════════════════════════════════════════════════════════════════════════════
-- Migration 012: Fix folders RLS + ensure all table grants are applied
-- Run this in Supabase SQL Editor
-- ══════════════════════════════════════════════════════════════════════════════

-- ── Folders: ensure RLS policies exist and grants are applied ─────────────────
drop policy if exists "folders_select"     on public.folders;
drop policy if exists "folders_insert"     on public.folders;
drop policy if exists "folders_update_own" on public.folders;
drop policy if exists "folders_delete_own" on public.folders;

create policy "folders_select"     on public.folders for select using (true);
create policy "folders_insert"     on public.folders for insert with check (auth.uid() = user_id);
create policy "folders_update_own" on public.folders for update using (auth.uid() = user_id);
create policy "folders_delete_own" on public.folders for delete using (auth.uid() = user_id);

-- Grant table-level permissions (required in addition to RLS policies)
grant usage  on schema public to authenticated, anon;
grant select, insert, update, delete on public.folders to authenticated;

-- ── Re-apply all other critical grants in case they were missed ───────────────
grant select, insert, update on public.notes       to authenticated;
grant select                  on public.notes       to anon;
grant select, insert, delete  on public.likes       to authenticated;
grant select, insert, update, delete on public.saves to authenticated;
grant select, insert, delete  on public.follows     to authenticated;
grant select, update          on public.notifications to authenticated;
grant select                  on public.rewards_catalog to anon, authenticated;
grant select, insert          on public.redemptions to authenticated;
grant select                  on public.badges      to anon, authenticated;
grant select                  on public.user_badges to authenticated;
grant insert                  on public.reports     to authenticated;
grant select                  on public.users       to anon, authenticated;
grant update                  on public.users       to authenticated;
grant select                  on public.points_ledger to authenticated;
grant select, insert, update  on public.support_tickets to authenticated;
grant select                  on public.feature_flags to anon, authenticated;

-- Sequences
grant usage, select on all sequences in schema public to authenticated;
