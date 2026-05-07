-- Migration 026: Reporting Enhancements - Point Deduction & Penalty Event

-- 1. Add 'penalty' to points_ledger event_type check constraint
-- Since check constraints cannot be easily altered in some Postgres versions without dropping/recreating,
-- we'll try to add it.
ALTER TABLE public.points_ledger DROP CONSTRAINT IF EXISTS points_ledger_event_type_check;
ALTER TABLE public.points_ledger ADD CONSTRAINT points_ledger_event_type_check 
    CHECK (event_type IN ('upload','like_received','save_received','streak_bonus','first_upload','verification_bonus','admin_grant','penalty'));

-- 2. Enhance resolve_report function to support point deduction
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
        -- Delete the note
        DELETE FROM public.notes WHERE id = v_note_id;
        
        -- Notify author about deletion (only if not already notified by penalty or combining messages)
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
