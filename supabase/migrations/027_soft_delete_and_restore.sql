-- Migration 027: Soft Delete via Reports and Restore Functionality

-- 1. Update resolve_report to use soft delete instead of hard delete
CREATE OR REPLACE FUNCTION public.resolve_report(
    p_report_id uuid,
    p_status text,
    p_admin_note text DEFAULT NULL,
    p_action text DEFAULT 'none', -- 'none', 'delete', 'notify_edit'
    p_penalty_points integer DEFAULT 0
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
        admin_note = p_admin_note
    WHERE id = p_report_id;

    -- Apply penalty if points provided
    IF p_penalty_points > 0 THEN
        -- Insert negative points into ledger
        INSERT INTO public.points_ledger (user_id, event_type, points, reference_id)
        VALUES (v_author_id, 'penalty', -p_penalty_points, v_note_id);

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
            'You have been penalized ' || p_penalty_points || ' points due to a report on your post: ' || v_note_title
        );
    END IF;

    -- Take action
    IF p_action = 'delete' THEN
        -- SOFT Delete the note (set status to removed)
        UPDATE public.notes 
        SET status = 'removed', 
            deleted_at = now(),
            updated_at = now()
        WHERE id = v_note_id;
        
        -- Notify author about deletion
        IF p_penalty_points = 0 THEN
            PERFORM public.notify_user(
                v_author_id,
                'system',
                'Post Removed',
                'Your post "' || v_note_title || '" has been removed due to: ' || COALESCE(p_admin_note, 'Violation of community guidelines.')
            );
        END IF;
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

-- 2. Function for admins to restore a removed note
CREATE OR REPLACE FUNCTION public.restore_note(
    p_note_id uuid
) RETURNS void AS $$
BEGIN
    -- Only allow if the caller is an admin
    IF NOT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid() AND role = 'admin'
    ) THEN
        RAISE EXCEPTION 'Only admins can restore notes';
    END IF;

    -- Restore the note
    UPDATE public.notes 
    SET status = 'active', 
        deleted_at = NULL,
        updated_at = now()
    WHERE id = p_note_id;

    -- Also mark any reports for this note as dismissed if they were resolved with 'delete'
    -- Actually, maybe keep them as resolved but note they were restored.
    -- For simplicity, let's just restore the note.
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
