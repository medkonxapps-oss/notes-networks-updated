-- Enable RLS on all tables
alter table public.users enable row level security;
alter table public.notes enable row level security;
alter table public.folders enable row level security;
alter table public.follows enable row level security;
alter table public.likes enable row level security;
alter table public.saves enable row level security;
alter table public.notifications enable row level security;
alter table public.reports enable row level security;
alter table public.points_ledger enable row level security;
alter table public.user_badges enable row level security;
alter table public.redemptions enable row level security;
alter table public.rewards_catalog enable row level security;
alter table public.badges enable row level security;

-- Helper: is current user admin or moderator?
create or replace function public.is_admin()
returns boolean as $$
  select exists(
    select 1 from public.users
    where id = auth.uid() and role in ('admin','moderator')
  );
$$ language sql security definer;

-- ── USERS RLS ──────────────────────────────────────────────────────────────────
create policy "users_select_active" on public.users
  for select using (deleted_at is null and is_active = true);
create policy "users_insert_own" on public.users
  for insert with check (auth.uid() = id);
create policy "users_update_own" on public.users
  for update using (auth.uid() = id);
create policy "users_admin_all" on public.users
  for all using (public.is_admin());

-- ── NOTES RLS ──────────────────────────────────────────────────────────────────
create policy "notes_select_public" on public.notes for select using (
  status = 'active' and deleted_at is null and (
    visibility = 'public'
    or user_id = auth.uid()
    or (visibility = 'followers' and exists(
      select 1 from public.follows
      where follower_id = auth.uid() and following_id = notes.user_id
    ))
  )
);
create policy "notes_insert_own" on public.notes
  for insert with check (auth.uid() = user_id);
create policy "notes_update_own" on public.notes
  for update using (auth.uid() = user_id or public.is_admin());
create policy "notes_admin_select" on public.notes
  for select using (public.is_admin());

-- ── FOLDERS RLS ────────────────────────────────────────────────────────────────
create policy "folders_select" on public.folders for select using (true);
create policy "folders_insert" on public.folders
  for insert with check (auth.uid() = user_id);
create policy "folders_update_own" on public.folders
  for update using (auth.uid() = user_id);
create policy "folders_delete_own" on public.folders
  for delete using (auth.uid() = user_id);

-- ── LIKES RLS ──────────────────────────────────────────────────────────────────
create policy "likes_select" on public.likes for select using (true);
create policy "likes_insert" on public.likes
  for insert with check (auth.uid() = user_id);
create policy "likes_delete" on public.likes
  for delete using (auth.uid() = user_id);

-- ── SAVES RLS ──────────────────────────────────────────────────────────────────
create policy "saves_select_own" on public.saves
  for select using (auth.uid() = user_id);
create policy "saves_insert" on public.saves
  for insert with check (auth.uid() = user_id);
create policy "saves_delete" on public.saves
  for delete using (auth.uid() = user_id);
create policy "saves_update" on public.saves
  for update using (auth.uid() = user_id);

-- ── FOLLOWS RLS ────────────────────────────────────────────────────────────────
create policy "follows_select" on public.follows for select using (true);
create policy "follows_insert" on public.follows
  for insert with check (auth.uid() = follower_id);
create policy "follows_delete" on public.follows
  for delete using (auth.uid() = follower_id);

-- ── NOTIFICATIONS RLS ──────────────────────────────────────────────────────────
create policy "notifications_own" on public.notifications
  for all using (auth.uid() = user_id);

-- ── POINTS LEDGER RLS ──────────────────────────────────────────────────────────
create policy "points_select_own" on public.points_ledger
  for select using (auth.uid() = user_id);
-- Inserts only via security definer functions

-- ── REPORTS RLS ────────────────────────────────────────────────────────────────
create policy "reports_insert" on public.reports
  for insert with check (auth.uid() = reporter_id);
create policy "reports_admin" on public.reports
  for all using (public.is_admin());

-- ── USER BADGES ────────────────────────────────────────────────────────────────
create policy "user_badges_select" on public.user_badges for select using (true);
create policy "user_badges_admin" on public.user_badges
  for all using (public.is_admin());

-- ── BADGES (catalog) ────────────────────────────────────────────────────────────
create policy "badges_select" on public.badges for select using (true);
create policy "badges_admin" on public.badges for all using (public.is_admin());

-- ── REWARDS CATALOG ────────────────────────────────────────────────────────────
create policy "rewards_select_active" on public.rewards_catalog
  for select using (is_active = true);
create policy "rewards_admin" on public.rewards_catalog for all using (public.is_admin());

-- ── REDEMPTIONS ────────────────────────────────────────────────────────────────
create policy "redemptions_own" on public.redemptions
  for select using (auth.uid() = user_id);
create policy "redemptions_insert" on public.redemptions
  for insert with check (auth.uid() = user_id);
create policy "redemptions_admin" on public.redemptions
  for all using (public.is_admin());
