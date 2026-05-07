-- Additional performance indexes
create index if not exists idx_notes_board on public.notes(board);
create index if not exists idx_notes_class_level on public.notes(class_level);
create index if not exists idx_notes_visibility on public.notes(visibility);
create index if not exists idx_notes_compound on public.notes(status, visibility, feed_score desc);
create index if not exists idx_users_streak on public.users(current_streak desc);
create index if not exists idx_users_verified on public.users(is_verified_creator) where is_verified_creator = true;
create index if not exists idx_notifications_unread on public.notifications(user_id, created_at desc) where is_read = false;
