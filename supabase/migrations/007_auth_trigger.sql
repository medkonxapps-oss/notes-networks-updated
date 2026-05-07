-- Function to handle new user creation in public.users
-- This runs as security definer to bypass RLS when creating the initial profile
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.users (id, username, full_name, email, phone, institution_name, board, class_level)
  values (
    new.id,
    new.raw_user_meta_data->>'username',
    new.raw_user_meta_data->>'full_name',
    new.email,
    new.raw_user_meta_data->>'phone',
    new.raw_user_meta_data->>'institution_name',
    coalesce(new.raw_user_meta_data->>'board', 'CBSE'),
    coalesce(new.raw_user_meta_data->>'class_level', 'Class 10')
  );
  return new;
end;
$$ language plpgsql security definer;

-- Trigger to call the function on auth.users insert
-- We use a separate migration to ensure all tables exist before the trigger is created
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
