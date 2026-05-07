-- ══════════════════════════════════════════════════════════════════════════════
-- Migration 009: Fix admin panel — missing tables, RLS, and grants
-- Run this in Supabase SQL Editor
-- ══════════════════════════════════════════════════════════════════════════════

-- ── 0. CREATE is_admin() FIRST — policies below depend on it ─────────────────
create or replace function public.is_admin()
returns boolean as $$
  select coalesce(
    (select role in ('admin','moderator')
     from public.users
     where id = auth.uid()
     and deleted_at is null),
    false
  );
$$ language sql security definer stable;

-- ── 1. CREATE MISSING TABLES ──────────────────────────────────────────────────

-- support_tickets (queried by Support screen)
create table if not exists public.support_tickets (
  id               uuid primary key default uuid_generate_v4(),
  user_id          uuid not null references public.users(id) on delete cascade,
  subject          varchar(150) not null,
  body             text not null,
  status           text not null default 'open'
                     check (status in ('open','in_progress','resolved')),
  assigned_to      uuid references public.users(id),
  resolution_note  text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- feature_flags (queried by Config screen)
create table if not exists public.feature_flags (
  id          uuid primary key default uuid_generate_v4(),
  flag_name   varchar(80) not null unique,
  is_enabled  boolean not null default true,
  value       text,
  description text,
  updated_by  uuid references public.users(id),
  updated_at  timestamptz not null default now()
);

-- admin_audit_log
create table if not exists public.admin_audit_log (
  id           uuid primary key default uuid_generate_v4(),
  admin_id     uuid not null references public.users(id),
  action       varchar(80) not null,
  target_type  varchar(40) not null,
  target_id    uuid,
  details      jsonb,
  ip_address   inet,
  created_at   timestamptz not null default now()
);

-- sponsored_notes
create table if not exists public.sponsored_notes (
  id                  uuid primary key default uuid_generate_v4(),
  brand_name          varchar(100) not null,
  note_id             uuid not null references public.notes(id) on delete cascade,
  campaign_start      date not null,
  campaign_end        date not null,
  budget_impressions  integer not null default 0,
  impressions_served  integer not null default 0,
  is_active           boolean not null default true,
  created_at          timestamptz not null default now()
);

-- ── 2. SEED default feature flags ────────────────────────────────────────────
insert into public.feature_flags (flag_name, is_enabled, description)
values
  ('sponsored_notes',     true,  'Show sponsored notes in feed'),
  ('streak_system',       true,  'Enable daily streak tracking'),
  ('rewards_enabled',     true,  'Enable rewards redemption'),
  ('maintenance_mode',    false, 'Block app access for non-admins'),
  ('new_user_onboarding', true,  'Show onboarding flow for new users')
on conflict (flag_name) do nothing;

-- ── 3. ENABLE RLS on new tables ───────────────────────────────────────────────
alter table public.support_tickets  enable row level security;
alter table public.feature_flags    enable row level security;
alter table public.admin_audit_log  enable row level security;
alter table public.sponsored_notes  enable row level security;

-- ── 4. RLS POLICIES ───────────────────────────────────────────────────────────

-- support_tickets
drop policy if exists "support_tickets_own"    on public.support_tickets;
drop policy if exists "support_tickets_insert" on public.support_tickets;
drop policy if exists "support_tickets_admin"  on public.support_tickets;

create policy "support_tickets_own" on public.support_tickets
  for select using (auth.uid() = user_id or public.is_admin());
create policy "support_tickets_insert" on public.support_tickets
  for insert with check (auth.uid() = user_id);
create policy "support_tickets_admin" on public.support_tickets
  for update using (public.is_admin());

-- feature_flags
drop policy if exists "feature_flags_select" on public.feature_flags;
drop policy if exists "feature_flags_admin"  on public.feature_flags;

create policy "feature_flags_select" on public.feature_flags
  for select using (true);
create policy "feature_flags_admin" on public.feature_flags
  for all using (public.is_admin());

-- admin_audit_log
drop policy if exists "audit_log_admin" on public.admin_audit_log;
create policy "audit_log_admin" on public.admin_audit_log
  for all using (public.is_admin());

-- sponsored_notes
drop policy if exists "sponsored_notes_select" on public.sponsored_notes;
drop policy if exists "sponsored_notes_admin"  on public.sponsored_notes;

create policy "sponsored_notes_select" on public.sponsored_notes
  for select using (is_active = true or public.is_admin());
create policy "sponsored_notes_admin" on public.sponsored_notes
  for all using (public.is_admin());

-- ── 5. GRANTS ─────────────────────────────────────────────────────────────────
grant select, insert, update on public.support_tickets  to authenticated;
grant select                  on public.feature_flags   to anon, authenticated;
grant update                  on public.feature_flags   to authenticated;
grant select                  on public.sponsored_notes to anon, authenticated;
grant select, insert          on public.admin_audit_log to authenticated;
grant update                  on public.reports         to authenticated;
grant select, insert, update  on public.notes           to authenticated;

-- ── 6. admin_add_points RPC ───────────────────────────────────────────────────
create or replace function public.admin_add_points(user_id uuid, amount integer)
returns void as $$
begin
  insert into public.points_ledger (user_id, event_type, points)
  values (user_id, 'admin_grant', amount);

  update public.users
  set total_points = total_points + amount,
      updated_at   = now()
  where id = user_id;
end;
$$ language plpgsql security definer;

grant execute on function public.admin_add_points(uuid, integer) to authenticated;
