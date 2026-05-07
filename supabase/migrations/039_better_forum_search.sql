-- Migration 039: Better Forum Search (Fuzzy Search)

-- 1. Function for Fuzzy Forum Search
create or replace function public.search_forum_fuzzy(p_query text, p_subject text default null, p_limit integer default 20)
returns setof public.forum_questions language plpgsql security definer as $$
begin
  return query
  select * from public.forum_questions
  where deleted_at is null
  and (p_subject is null or subject = p_subject or p_subject = 'All')
  and (
    title % p_query or 
    content % p_query or 
    subject % p_query or
    title ilike '%' || p_query || '%' or 
    content ilike '%' || p_query || '%'
  )
  order by (similarity(title, p_query) * 2 + similarity(content, p_query)) desc
  limit p_limit;
end;
$$;

-- 2. Grants
grant execute on function public.search_forum_fuzzy(text, text, integer) to authenticated;
