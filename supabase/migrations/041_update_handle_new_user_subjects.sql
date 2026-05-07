-- Migration 041: Update handle_new_user for subjects (specialization)
create or replace function public.handle_new_user()
returns trigger as $$
declare
  subjects_json jsonb;
begin
  subjects_json := new.raw_user_meta_data->'subjects';
  
  insert into public.users (
    id, username, full_name, email, phone, 
    institution_name, board, class_level, 
    role, linkedin_url, id_card_url, subjects
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
    new.raw_user_meta_data->>'id_card_url',
    case 
      when subjects_json is null then array[]::text[]
      else (select array_agg(x)::text[] from jsonb_array_elements_text(subjects_json) x)
    end
  );
  return new;
end;
$$ language plpgsql security definer;
