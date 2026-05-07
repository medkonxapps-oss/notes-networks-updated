

-- ═══════════════════════════════════════════════════════════════════════════════
-- Migration 021: Reliable Admin KPI View
-- ═══════════════════════════════════════════════════════════════════════════════

-- Create a robust view for all dashboard counters to avoid client-side aggregation
create or replace view public.admin_kpi_stats as
select
  (select count(*) from public.users where is_active = true) as total_users,
  (select count(*) from public.notes where status = 'active') as active_notes,
  (select coalesce(sum(views_count), 0) from public.notes) as total_views,
  (select coalesce(sum(likes_count), 0) from public.notes) as total_likes,
  (select count(*) from public.reports where status = 'pending') as pending_reports,
  (select count(*) from public.redemptions where status = 'pending') as pending_redemptions,
  (select count(*) from public.notes where status = 'pending_review') as pending_notes;

grant select on public.admin_kpi_stats to authenticated;
