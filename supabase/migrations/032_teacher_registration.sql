-- Migration 032: Teacher Registration Support

-- 1. Update role check constraint to include 'teacher'
alter table public.users drop constraint if exists users_role_check;
alter table public.users add constraint users_role_check 
  check (role in ('student', 'creator', 'moderator', 'admin', 'teacher'));

-- 2. Add teacher-specific fields to users table
alter table public.users add column if not exists linkedin_url text;
alter table public.users add column if not exists id_card_url text;
alter table public.users add column if not exists teacher_status text default 'pending' 
  check (teacher_status in ('pending', 'approved', 'rejected'));

-- 3. Update handle_new_user function to include new fields
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.users (
    id, username, full_name, email, phone, 
    institution_name, board, class_level, 
    role, linkedin_url, id_card_url
  )
  values (
    new.id,
    new.raw_user_meta_data->>'username',
    new.raw_user_meta_data->>'full_name',
    new.email,
    new.raw_user_meta_data->>'phone',
    new.raw_user_meta_data->>'institution_name',
    coalesce(new.raw_user_meta_data->>'board', 'CBSE'),
    coalesce(new.raw_user_meta_data->>'class_level', 'Class 10'),
    coalesce(new.raw_user_meta_data->>'role', 'student'),
    new.raw_user_meta_data->>'linkedin_url',
    new.raw_user_meta_data->>'id_card_url'
  );
  return new;
end;
$$ language plpgsql security definer;

-- 4. Storage bucket for ID Cards
insert into storage.buckets (id, name, public) 
values ('id-cards', 'id-cards', false)
on conflict (id) do nothing;

-- RLS for id-cards bucket
create policy "Users can upload their own id cards"
  on storage.objects for insert with check (
    bucket_id = 'id-cards' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can view their own id cards"
  on storage.objects for select using (
    bucket_id = 'id-cards' and (storage.foldername(name))[1] = auth.uid()::text
  );
