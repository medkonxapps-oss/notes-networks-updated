-- Migration 047: Admin Broadcasts & System Notifications
-- Allows admins to send system-wide notifications (in-app + push)

CREATE TABLE IF NOT EXISTS public.app_broadcasts (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    admin_id uuid NOT NULL REFERENCES public.users(id),
    title text NOT NULL,
    message text NOT NULL,
    target_audience text NOT NULL CHECK (target_audience IN ('all', 'students', 'teachers', 'creators')),
    created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.app_broadcasts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can insert broadcasts"
    ON public.app_broadcasts FOR INSERT TO authenticated
    WITH CHECK (public.is_admin());

CREATE POLICY "Admins can view broadcasts"
    ON public.app_broadcasts FOR SELECT TO authenticated
    USING (public.is_admin());

-- Function to distribute the broadcast to users' notification inboxes
CREATE OR REPLACE FUNCTION public.distribute_broadcast()
RETURNS trigger AS $$
BEGIN
    -- Insert into notifications table based on audience
    IF NEW.target_audience = 'all' THEN
        INSERT INTO public.notifications (user_id, type, title, message)
        SELECT id, 'system', NEW.title, NEW.message
        FROM public.users
        WHERE is_active = true AND deleted_at IS NULL;
    ELSIF NEW.target_audience = 'students' THEN
        INSERT INTO public.notifications (user_id, type, title, message)
        SELECT id, 'system', NEW.title, NEW.message
        FROM public.users
        WHERE role = 'student' AND is_active = true AND deleted_at IS NULL;
    ELSIF NEW.target_audience = 'teachers' THEN
        INSERT INTO public.notifications (user_id, type, title, message)
        SELECT id, 'system', NEW.title, NEW.message
        FROM public.users
        WHERE role = 'teacher' AND is_active = true AND deleted_at IS NULL;
    ELSIF NEW.target_audience = 'creators' THEN
        INSERT INTO public.notifications (user_id, type, title, message)
        SELECT id, 'system', NEW.title, NEW.message
        FROM public.users
        WHERE is_verified_creator = true AND is_active = true AND deleted_at IS NULL;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_new_broadcast ON public.app_broadcasts;
CREATE TRIGGER on_new_broadcast
    AFTER INSERT ON public.app_broadcasts
    FOR EACH ROW EXECUTE FUNCTION public.distribute_broadcast();
