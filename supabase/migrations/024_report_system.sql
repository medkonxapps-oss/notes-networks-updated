-- Migration 024: Complete Report System

-- 1. Create reports table
CREATE TABLE IF NOT EXISTS public.reports (
    id            uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id   uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    note_id       uuid NOT NULL REFERENCES public.notes(id) ON DELETE CASCADE,
    reason        text NOT NULL CHECK (reason IN ('inappropriate','spam','copyright','misleading','other')),
    details       text,
    status        text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','resolved','dismissed')),
    admin_note    text,
    created_at    timestamptz NOT NULL DEFAULT now()
);

-- 2. Add RLS for reports
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- Users can insert reports
CREATE POLICY "Users can create reports" ON public.reports
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Admins can view and manage all reports
CREATE POLICY "Admins can manage reports" ON public.reports
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- 3. Function to notify user (system notification)
CREATE OR REPLACE FUNCTION public.notify_user(
    p_user_id uuid,
    p_type text,
    p_title text,
    p_message text,
    p_reference_id uuid DEFAULT NULL
) RETURNS void AS $$
BEGIN
    INSERT INTO public.notifications (user_id, type, title, message, reference_id)
    VALUES (p_user_id, p_type, p_title, p_message, p_reference_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Function to resolve report and take action
CREATE OR REPLACE FUNCTION public.resolve_report(
    p_report_id uuid,
    p_status text,
    p_admin_note text DEFAULT NULL,
    p_action text DEFAULT 'none' -- 'none', 'delete', 'notify_edit'
) RETURNS void AS $$
DECLARE
    v_note_id uuid;
    v_author_id uuid;
    v_note_title text;
BEGIN
    -- Get report and note info
    SELECT r.note_id, n.user_id, n.title 
    INTO v_note_id, v_author_id, v_note_title
    FROM public.reports r
    JOIN public.notes n ON r.note_id = n.id
    WHERE r.id = p_report_id;

    -- Update report status
    UPDATE public.reports 
    SET status = p_status, 
        admin_note = p_admin_note,
        created_at = created_at -- keep original timestamp or use now()? typically we want to know when it was resolved
    WHERE id = p_report_id;

    -- Take action
    IF p_action = 'delete' THEN
        -- Delete the note
        DELETE FROM public.notes WHERE id = v_note_id;
        
        -- Notify author about deletion
        PERFORM public.notify_user(
            v_author_id,
            'system',
            'Post Removed',
            'Your post "' || v_note_title || '" has been removed due to: ' || COALESCE(p_admin_note, 'Violation of community guidelines.')
        );
    ELSIF p_action = 'notify_edit' THEN
        -- Notify author to edit
        PERFORM public.notify_user(
            v_author_id,
            'system',
            'Action Required: Edit Post',
            'Please edit your post "' || v_note_title || '". Admin note: ' || COALESCE(p_admin_note, 'Incorrect information.')
        );
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
