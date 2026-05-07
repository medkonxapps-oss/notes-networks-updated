-- 1. Fix get_popular_creators to exclude teachers
create or replace function public.get_popular_creators(p_limit integer default 10)
returns setof public.users language plpgsql security definer as $$
begin
  return query
  select * from public.users
  where is_active = true 
    and deleted_at is null 
    and role != 'teacher' -- Exclude teachers from creators tab
  order by (followers_count * 2 + search_count) desc, total_points desc
  limit p_limit;
end;
$$;

-- 2. Fix search_users_fuzzy to exclude teachers
create or replace function public.search_users_fuzzy(p_query text, p_limit integer default 20)
returns setof public.users language plpgsql security definer as $$
begin
  return query
  select * from public.users
  where is_active = true 
    and deleted_at is null
    and role != 'teacher' -- Exclude teachers from creators tab
    and (
      username % p_query or 
      full_name % p_query or 
      username ilike '%' || p_query || '%' or 
      full_name ilike '%' || p_query || '%'
    )
  order by (similarity(username, p_query) + similarity(full_name, p_query)) desc, search_count desc
  limit p_limit;
end;
$$;

-- 3. Ensure Teacher RPCs are solid (re-apply with clarity)
create or replace function public.get_popular_teachers(p_limit integer default 10)
returns setof public.users language plpgsql security definer as $$
begin
  return query
  select * from public.users
  where role = 'teacher'
    and teacher_status = 'approved'
    and is_active = true
    and deleted_at is null
  order by (followers_count * 3 + search_count * 2) desc, total_points desc
  limit p_limit;
end;
$$;

create or replace function public.search_teachers_fuzzy(p_query text, p_limit integer default 20)
returns setof public.users language plpgsql security definer as $$
begin
  return query
  select * from public.users
  where role = 'teacher'
    and teacher_status = 'approved'
    and is_active = true
    and deleted_at is null
    and (
      username % p_query or
      full_name % p_query or
      institution_name % p_query or
      username ilike '%' || p_query || '%' or
      full_name ilike '%' || p_query || '%' or
      institution_name ilike '%' || p_query || '%'
    )
  order by (similarity(username, p_query) + similarity(full_name, p_query) + similarity(institution_name, p_query)) desc, search_count desc
  limit p_limit;
end;
$$;
