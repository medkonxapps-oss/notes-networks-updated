-- Migration 029: Redemption Notifications and Enhanced Admin View

-- 1. Function to notify user on redemption status change
CREATE OR REPLACE FUNCTION public.handle_redemption_status_change()
RETURNS trigger AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        -- Initial notification for the user
        PERFORM public.notify_user(
            NEW.user_id,
            'system',
            'Redemption Submitted',
            'Your claim for reward has been received. Our team will process it shortly.'
        );
    ELSIF (OLD.status IS DISTINCT FROM NEW.status) THEN
        -- Notification on status change (dispatched, delivered, cancelled)
        PERFORM public.notify_user(
            NEW.user_id,
            'system',
            'Reward Status Update',
            'Your reward status has been updated to: ' || NEW.status
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Trigger for redemption notifications
DROP TRIGGER IF EXISTS on_redemption_change ON public.redemptions;
CREATE TRIGGER on_redemption_change
    AFTER INSERT OR UPDATE ON public.redemptions
    FOR EACH ROW EXECUTE FUNCTION public.handle_redemption_status_change();

-- 3. Enhance resolve_report logic in case it was missed or needs refinement
-- (Already handled in previous migrations, keeping focused on rewards here)
