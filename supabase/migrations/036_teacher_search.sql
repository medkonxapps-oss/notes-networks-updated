-- Migration 036: Teacher Search and Popularity

-- 1. Function for Popular Teachers (to show when search is blank)
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

-- 2. Improved Teacher Search with Similarity
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

-- 3. Grants
grant execute on function public.get_popular_teachers(integer) to authenticated;
grant execute on function public.search_teachers_fuzzy(text, integer) to authenticated;
