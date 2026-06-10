-- Allow comment notifications so the push bridge can deliver them too.
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check
  check (type in ('like', 'follow', 'reward', 'system', 'streak', 'save', 'download', 'forum', 'comment'));
