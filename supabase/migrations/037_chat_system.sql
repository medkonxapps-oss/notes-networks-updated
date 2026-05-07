-- Migration 037: Chat System for Student-Teacher Doubt Solving

-- 1. Create chat_rooms table
-- This helps in grouping messages between two users
create table if not exists public.chat_rooms (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references public.users(id) on delete cascade not null,
  teacher_id uuid references public.users(id) on delete cascade not null,
  last_message_text text,
  last_message_at timestamptz default now(),
  created_at timestamptz default now(),
  
  -- Prevent duplicate rooms between same student and teacher
  unique(student_id, teacher_id)
);

-- 2. Create messages table
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid references public.chat_rooms(id) on delete cascade not null,
  sender_id uuid references public.users(id) not null,
  receiver_id uuid references public.users(id) not null,
  content text not null,
  image_url text, -- For sending images/doubts
  is_read boolean default false,
  created_at timestamptz default now()
);

-- 3. Enable RLS
alter table public.chat_rooms enable row level security;
alter table public.messages enable row level security;

-- 4. Chat Rooms Policies
-- Users can only see rooms they are part of
create policy "chat_rooms_select" on public.chat_rooms
  for select using (auth.uid() = student_id or auth.uid() = teacher_id);

-- Only students can initiate a room with a teacher (initial doubt)
create policy "chat_rooms_insert" on public.chat_rooms
  for insert with check (
    auth.uid() = student_id 
    and exists (
      select 1 from public.users 
      where id = teacher_id and role = 'teacher'
    )
  );

-- 5. Messages Policies (The Core Restriction)
-- Users can only see messages in rooms they belong to
create policy "messages_select" on public.messages
  for select using (
    exists (
      select 1 from public.chat_rooms 
      where id = room_id and (student_id = auth.uid() or teacher_id = auth.uid())
    )
  );

-- STRICT RULE: Only allow message if one person is a teacher
create policy "messages_insert" on public.messages
  for insert with check (
    auth.uid() = sender_id 
    and (
      -- Case 1: Student sending to Teacher
      (
        exists (select 1 from public.users where id = sender_id and role = 'student')
        and exists (select 1 from public.users where id = receiver_id and role = 'teacher')
      )
      OR
      -- Case 2: Teacher replying to Student
      (
        exists (select 1 from public.users where id = sender_id and role = 'teacher')
        and exists (select 1 from public.users where id = receiver_id and role = 'student')
      )
    )
  );

-- 6. Trigger to update last_message in chat_rooms
create or replace function public.handle_new_message()
returns trigger as $$
begin
  update public.chat_rooms
  set 
    last_message_text = left(new.content, 100),
    last_message_at = new.created_at
  where id = new.room_id;
  return new;
end;
$$ language plpgsql security definer;

create trigger on_new_message
  after insert on public.messages
  for each row
  execute function public.handle_new_message();

-- 7. Add Realtime
alter publication supabase_realtime add table public.chat_rooms;
alter publication supabase_realtime add table public.messages;

-- 8. Indexes for performance
create index idx_messages_room_id on public.messages(room_id);
create index idx_chat_rooms_student on public.chat_rooms(student_id);
create index idx_chat_rooms_teacher on public.chat_rooms(teacher_id);

-- 9. Grants (CRITICAL FIX: Allow authenticated users to access these tables)
grant select, insert, update on public.chat_rooms to authenticated;
grant select, insert, update on public.messages to authenticated;
