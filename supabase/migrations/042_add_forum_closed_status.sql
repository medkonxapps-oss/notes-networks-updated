-- Add is_closed column to forum_questions
alter table public.forum_questions add column if not exists is_closed boolean not null default false;

-- Add index for is_closed
create index if not exists idx_forum_questions_is_closed on public.forum_questions(is_closed);
