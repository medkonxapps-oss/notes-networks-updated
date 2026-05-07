-- Migration 025: Fix reports table permissions for admin panel
-- The reports table only had INSERT granted to authenticated (migration 008).
-- Admin panel needs SELECT, UPDATE, DELETE to view and manage reports.

-- Grant full access to authenticated role (RLS policies still enforce row-level security)
GRANT SELECT, INSERT, UPDATE, DELETE ON public.reports TO authenticated;

-- Ensure the "Admins can manage reports" policy covers SELECT explicitly.
-- The FOR ALL policy in 024 should cover it, but some Postgres versions need
-- explicit SELECT policy when RLS is enabled. Add a dedicated one to be safe.
DROP POLICY IF EXISTS "Admins can select reports" ON public.reports;
CREATE POLICY "Admins can select reports" ON public.reports
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Also allow reporters to see their own reports
DROP POLICY IF EXISTS "Users can view own reports" ON public.reports;
CREATE POLICY "Users can view own reports" ON public.reports
    FOR SELECT USING (reporter_id = auth.uid());
