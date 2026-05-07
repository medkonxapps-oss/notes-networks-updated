-- Migration 030: Forum System and Notifications
-- This migration ensures forum tables exist and adds support for nested replies and notifications.

-- 1. Create forum_questions table if not exists
create table if not exists public.forum_questions (
    id            uuid primary key default uuid_generate_v4(),
    user_id       uuid not null references public.users(id) on delete cascade,
    title         varchar(200) not null,
    content       text not null,
    subject       varchar(80) not null,
    views_count   integer not null default 0,
    answers_count integer not null default 0,
    fts           tsvector generated always as (to_tsvector('english', title || ' ' || content)) stored,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),
    deleted_at    timestamptz
);

-- 2. Create forum_answers table if not exists
create table if not exists public.forum_answers (
    id            uuid primary key default uuid_generate_v4(),
    question_id   uuid not null references public.forum_questions(id) on delete cascade,
    user_id       uuid not null references public.users(id) on delete cascade,
    parent_id     uuid references public.forum_answers(id) on delete cascade,
    content       text not null,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),
    deleted_at    timestamptz
);

-- 3. Add parent_id to forum_answers if it doesn't exist (in case table was already there)
do $$
begin
    if not exists (select 1 from information_schema.columns where table_name='forum_answers' and column_name='parent_id') then
        alter table public.forum_answers add column parent_id uuid references public.forum_answers(id) on delete cascade;
    end if;
end $$;

-- 4. Triggers for answers_count on forum_questions
create or replace function public.update_forum_answers_count() returns trigger as $$
begin
    if tg_op = 'INSERT' then
        update public.forum_questions set answers_count = answers_count + 1 where id = new.question_id;
    elsif tg_op = 'DELETE' then
        update public.forum_questions set answers_count = greatest(answers_count - 1, 0) where id = old.question_id;
    end if;
    return null;
end;
$$ language plpgsql security definer;

drop trigger if exists trigger_forum_answers_count on public.forum_answers;
create trigger trigger_forum_answers_count 
after insert or delete on public.forum_answers 
for each row execute function public.update_forum_answers_count();

-- 5. NOTIFICATION TYPE EXTENSION
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check 
check (type in ('like', 'follow', 'reward', 'system', 'streak', 'save', 'download', 'forum'));

-- 6. Notification Trigger for Forum
create or replace function public.handle_forum_notification() returns trigger as $$
declare
    v_target_user_id uuid;
    v_notif_title text;
    v_notif_message text;
    v_question_title text;
    v_author_name text;
begin
    -- Get author name
    select full_name into v_author_name from public.users where id = new.user_id;
    
    -- Get question title
    select title into v_question_title from public.forum_questions where id = new.question_id;

    if new.parent_id is null then
        -- This is a top-level answer. Notify the question owner.
        select user_id into v_target_user_id from public.forum_questions where id = new.question_id;
        v_notif_title := 'New Answer';
        v_notif_message := v_author_name || ' answered your question: ' || v_question_title;
    else
        -- This is a reply to an answer. Notify the parent answer owner.
        select user_id into v_target_user_id from public.forum_answers where id = new.parent_id;
        v_notif_title := 'New Reply';
        v_notif_message := v_author_name || ' replied to your answer in: ' || v_question_title;
    end if;

    -- Send notification only if target user is not the author themselves
    if v_target_user_id is not null and v_target_user_id != new.user_id then
        insert into public.notifications (user_id, type, title, message, reference_id)
        values (v_target_user_id, 'forum', v_notif_title, v_notif_message, new.question_id);
    end if;

    return new;
end;
$$ language plpgsql security definer;

drop trigger if exists trigger_forum_notification on public.forum_answers;
create trigger trigger_forum_notification 
after insert on public.forum_answers 
for each row execute function public.handle_forum_notification();

-- 7. RPC for views_count
create or replace function public.increment_forum_views(p_question_id uuid) returns void as $$
begin
    update public.forum_questions 
    set views_count = views_count + 1 
    where id = p_question_id;
end;
$$ language plpgsql security definer;

-- 8. Indexes
create index if not exists idx_forum_questions_user_id on public.forum_questions(user_id);
create index if not exists idx_forum_questions_subject on public.forum_questions(subject);
create index if not exists idx_forum_answers_question_id on public.forum_answers(question_id);
create index if not exists idx_forum_answers_parent_id on public.forum_answers(parent_id);
create index if not exists idx_forum_questions_fts on public.forum_questions using gin(fts);

-- 8. RLS Policies
alter table public.forum_questions enable row level security;
alter table public.forum_answers enable row level security;

drop policy if exists "Forum questions select" on public.forum_questions;
create policy "Forum questions select" on public.forum_questions for select using (deleted_at is null);

drop policy if exists "Forum questions insert" on public.forum_questions;
create policy "Forum questions insert" on public.forum_questions for insert with check (auth.uid() = user_id);

drop policy if exists "Forum questions update" on public.forum_questions;
create policy "Forum questions update" on public.forum_questions for update using (auth.uid() = user_id);

drop policy if exists "Forum answers select" on public.forum_answers;
create policy "Forum answers select" on public.forum_answers for select using (deleted_at is null);

drop policy if exists "Forum answers insert" on public.forum_answers;
create policy "Forum answers insert" on public.forum_answers for insert with check (auth.uid() = user_id);

drop policy if exists "Forum answers update" on public.forum_answers;
create policy "Forum answers update" on public.forum_answers for update using (auth.uid() = user_id);

-- 9. Grants
grant select, insert, update on public.forum_questions to authenticated;
grant select, insert, update on public.forum_answers to authenticated;
grant execute on function public.increment_forum_views(uuid) to authenticated;
