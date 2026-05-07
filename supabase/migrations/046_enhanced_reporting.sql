-- Migration 046: Enhanced Reporting System (Profiles & Notes)
-- This migration extends the reporting system to support profile reports
-- and improves the resolution logic.

-- 1. Modify public.reports table
ALTER TABLE public.reports 
  ALTER COLUMN note_id DROP NOT NULL;

ALTER TABLE public.reports 
  ADD COLUMN IF NOT EXISTS target_user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS target_type text NOT NULL DEFAULT 'note' CHECK (target_type IN ('note', 'user', 'comment', 'forum_post'));

-- Update existing reports to have target_type = 'note'
UPDATE public.reports SET target_type = 'note' WHERE note_id IS NOT NULL;

-- 2. Update resolve_report function to handle profile reports
CREATE OR REPLACE FUNCTION public.resolve_report(
    p_report_id uuid,
    p_status text,
    p_admin_note text DEFAULT NULL,
    p_action text DEFAULT 'none', -- 'none', 'delete', 'notify_edit', 'suspend', 'warn'
    p_penalty_points integer DEFAULT 0
) RETURNS void AS $$
DECLARE
    v_target_type text;
    v_note_id uuid;
    v_target_user_id uuid;
    v_author_id uuid;
    v_item_title text;
BEGIN
    -- Get report info
    SELECT r.target_type, r.note_id, r.target_user_id
    INTO v_target_type, v_note_id, v_target_user_id
    FROM public.reports r
    WHERE r.id = p_report_id;

    -- Determine author and title based on type
    IF v_target_type = 'note' THEN
        SELECT n.user_id, n.title INTO v_author_id, v_item_title
        FROM public.notes n WHERE n.id = v_note_id;
    ELSIF v_target_type = 'user' THEN
        SELECT id, full_name INTO v_author_id, v_item_title
        FROM public.users WHERE id = v_target_user_id;
    END IF;

    -- Update report status
    UPDATE public.reports 
    SET status = p_status, 
        admin_note = p_admin_note
    WHERE id = p_report_id;

    -- Apply penalty if points provided
    IF p_penalty_points > 0 AND v_author_id IS NOT NULL THEN
        -- Insert negative points into ledger
        INSERT INTO public.points_ledger (user_id, event_type, points, reference_id)
        VALUES (v_author_id, 'penalty', -p_penalty_points, COALESCE(v_note_id, v_target_user_id));

        -- Update user total_points
        UPDATE public.users
        SET total_points = GREATEST(total_points - p_penalty_points, 0),
            updated_at = now()
        WHERE id = v_author_id;

        -- Notify user about penalty
        PERFORM public.notify_user(
            v_author_id,
            'system',
            'Points Deducted',
            'You have been penalized ' || p_penalty_points || ' points due to a report on your ' || v_target_type || ': ' || COALESCE(v_item_title, '')
        );
    END IF;

    -- Take action
    IF p_action = 'delete' AND v_target_type = 'note' THEN
        DELETE FROM public.notes WHERE id = v_note_id;
        
        IF p_penalty_points = 0 THEN
            PERFORM public.notify_user(
                v_author_id,
                'system',
                'Post Removed',
                'Your post "' || v_item_title || '" has been removed due to: ' || COALESCE(p_admin_note, 'Violation of community guidelines.')
            );
        END IF;
    ELSIF p_action = 'deactivate' AND v_author_id IS NOT NULL THEN
        -- Deactivate user account
        UPDATE public.users 
        SET is_active = false,
            updated_at = now()
        WHERE id = v_author_id;

        PERFORM public.notify_user(
            v_author_id,
            'system',
            'Account Deactivated',
            'Your account has been deactivated by an admin. Reason: ' || COALESCE(p_admin_note, 'Violation of community guidelines.')
        );
    ELSIF p_action = 'delete_user' AND v_author_id IS NOT NULL THEN
        -- Permanently delete user (Soft delete by setting deleted_at)
        UPDATE public.users 
        SET deleted_at = now(),
            is_active = false
        WHERE id = v_author_id;
    ELSIF p_action = 'suspend' AND v_author_id IS NOT NULL THEN
        -- Suspend user for 7 days by default if not specified in admin_note
        UPDATE public.users 
        SET suspension_until = now() + interval '7 days'
        WHERE id = v_author_id;

        PERFORM public.notify_user(
            v_author_id,
            'system',
            'Account Suspended',
            'Your account has been suspended for 7 days due to multiple violations. Admin note: ' || COALESCE(p_admin_note, 'N/A')
        );
    ELSIF p_action = 'warn' AND v_author_id IS NOT NULL THEN
        PERFORM public.notify_user(
            v_author_id,
            'system',
            'Official Warning',
            'This is an official warning regarding your ' || v_target_type || '. Admin note: ' || COALESCE(p_admin_note, 'Please follow community guidelines.')
        );
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
