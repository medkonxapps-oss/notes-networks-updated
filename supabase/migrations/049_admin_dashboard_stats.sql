-- Migration 049: Admin Dashboard Stats
-- Provides efficient aggregated statistics for the admin dashboard.

CREATE OR REPLACE VIEW public.admin_dashboard_stats AS
SELECT
    (SELECT count(*) FROM public.users WHERE deleted_at IS NULL) as total_users,
    (SELECT count(*) FROM public.notes WHERE status = 'approved') as total_notes,
    (SELECT count(*) FROM public.notes WHERE status = 'pending_review') as pending_notes_count,
    (SELECT count(*) FROM public.reports WHERE status = 'pending') as pending_reports_count,
    (SELECT count(*) FROM public.users WHERE role = 'teacher' AND teacher_status = 'approved') as verified_teachers_count,
    (SELECT count(*) FROM public.users WHERE role = 'teacher' AND teacher_status = 'pending') as pending_teachers_count,
    (SELECT COALESCE(sum(points), 0) FROM public.points_ledger WHERE points > 0) as total_points_awarded;

-- Grant access to authenticated admins
GRANT SELECT ON public.admin_dashboard_stats TO authenticated;
