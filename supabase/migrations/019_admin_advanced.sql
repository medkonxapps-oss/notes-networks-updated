-- ─────────────────────────────────────────────────────────────────────────────
-- Migration 019: Advanced Admin Panel Features
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Admin Audit Log Table
create table if not exists public.admin_audit_log (
  id            uuid primary key default gen_random_uuid(),
  admin_id      uuid not null references public.users(id) on delete set null,
  action        text not null,         -- e.g. 'approve_note', 'suspend_user'
  target_id     text,                  -- ID of the affected row (note, user, etc.)
  target_type   text,                  -- 'note' | 'user' | 'report' | 'config'
  details       text,                  -- human-readable summary
  metadata      jsonb,                 -- any extra structured data
  ip_address    text,
  created_at    timestamptz not null default now()
);

-- Index for efficient filtering
create index if not exists idx_audit_log_admin on public.admin_audit_log(admin_id);
create index if not exists idx_audit_log_action on public.admin_audit_log(action);
create index if not exists idx_audit_log_created on public.admin_audit_log(created_at desc);
create index if not exists idx_audit_log_target on public.admin_audit_log(target_id);

-- 2. Admin Roles - Add permissions JSONB column if missing
alter table public.admin_roles
  add column if not exists permissions jsonb not null
  default '{"dashboard":true,"users":true,"notes":true,"moderation":true,"analytics":true,"rewards":true,"notifications":true,"support":true,"config":false,"audit_log":false}'::jsonb;

-- 3. Update admin_kpi_stats view to include pending_teachers
create or replace view public.admin_kpi_stats as
select
  (select count(*) from public.users where is_active = true and deleted_at is null)::int              as total_users,
  (select count(*) from public.notes where status = 'active')::int                                    as active_notes,
  (select coalesce(sum(views_count), 0) from public.notes where status = 'active')::int               as total_views,
  (select coalesce(sum(likes_count), 0) from public.notes where status = 'active')::int               as total_likes,
  (select count(*) from public.notes where status = 'pending_review')::int                            as pending_notes,
  (select count(*) from public.reports where status = 'pending')::int                                 as pending_reports,
  (select count(*) from public.reward_redemptions where status = 'pending')::int                      as pending_redemptions,
  (select count(*) from public.users where teacher_status = 'pending_review')::int                    as pending_teachers,
  (select count(*) from public.users where is_active = true and updated_at > now() - interval '7d')::int as active_users_7d,
  (select coalesce(avg(current_streak), 0) from public.users where is_active = true)::float           as avg_streak,
  (select count(*) from public.notes where views_count > 0)::int                                      as notes_with_views,
  (select count(*) from public.users where is_verified_creator = true)::int                           as verified_creators;

-- 4. Support tickets - add admin_reply, priority, category, resolved_at if missing
alter table public.support_tickets
  add column if not exists admin_reply text,
  add column if not exists priority    text not null default 'normal' check (priority in ('low', 'normal', 'high', 'urgent')),
  add column if not exists category    text,
  add column if not exists resolved_at timestamptz;

create index if not exists idx_support_status_priority on public.support_tickets(status, priority);

-- 5. Helper function to log admin actions
create or replace function public.log_admin_action(
  p_admin_id    uuid,
  p_action      text,
  p_target_id   text default null,
  p_target_type text default null,
  p_details     text default null,
  p_metadata    jsonb default null
) returns void language plpgsql security definer as $$
begin
  insert into public.admin_audit_log(admin_id, action, target_id, target_type, details, metadata)
  values (p_admin_id, p_action, p_target_id, p_target_type, p_details, p_metadata);
end;
$$;

-- 6. RLS: Audit log readable only by admins
alter table public.admin_audit_log enable row level security;

create policy "Audit log readable by admins" on public.admin_audit_log
  for select using (
    exists (select 1 from public.admin_roles where user_id = auth.uid())
  );

create policy "Audit log writable by service role only" on public.admin_audit_log
  for insert with check (false); -- Only insertable via log_admin_action() which is SECURITY DEFINER

-- 7. Notification preferences: add missing keys via back-fill
update public.users
set notification_preferences = '{"likes":true,"saves":true,"follows":true,"rewards":true,"streaks":true,"system":true}'::jsonb || notification_preferences
where not (notification_preferences ?& array['likes','saves','follows','rewards','streaks','system']);

-- Done
comment on table public.admin_audit_log is 'Immutable audit trail of all admin actions. Written only via log_admin_action().';
