-- Migration 031: Better Search (Fuzzy Search & Popular Results)

-- 1. Enable pg_trgm extension for fuzzy search (similarity)
create extension if not exists pg_trgm;

-- 2. Add search_count to users and notes for popularity tracking
alter table public.users add column if not exists search_count integer not null default 0;
alter table public.notes add column if not exists search_count integer not null default 0;

-- 3. Function to increment user search count (Popularity tracking)
create or replace function public.increment_user_search(p_user_id uuid)
returns void language plpgsql security definer as $$
begin
  update public.users set search_count = search_count + 1 where id = p_user_id;
end;
$$;

-- 4. Function to increment note search count
create or replace function public.increment_note_search(p_note_id uuid)
returns void language plpgsql security definer as $$
begin
  update public.users set search_count = search_count + 1 where id = p_note_id;
end;
$$;

-- 5. RPC for Popular Creators (to show when search is blank)
create or replace function public.get_popular_creators(p_limit integer default 10)
returns setof public.users language plpgsql security definer as $$
begin
  return query
  select * from public.users
  where is_active = true and deleted_at is null
  order by (followers_count * 2 + search_count) desc, total_points desc
  limit p_limit;
end;
$$;

-- 6. RPC for Popular Notes (Trending)
create or replace function public.get_popular_notes(p_limit integer default 10)
returns setof public.notes language plpgsql security definer as $$
begin
  return query
  select * from public.notes
  where status = 'active' and visibility = 'public' and deleted_at is null
  order by (feed_score * 5 + search_count) desc
  limit p_limit;
end;
$$;

-- 7. Improved User Search with Similarity (Fuzzy Search)
-- This allows finding "Gemini" even if user types "Gemni"
create or replace function public.search_users_fuzzy(p_query text, p_limit integer default 20)
returns setof public.users language plpgsql security definer as $$
begin
  return query
  select * from public.users
  where is_active = true and deleted_at is null
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

-- 8. Improved Note Search with Similarity
create or replace function public.search_notes_fuzzy(p_query text, p_subject text default null, p_limit integer default 30)
returns setof public.notes language plpgsql security definer as $$
begin
  return query
  select * from public.notes
  where status = 'active' and visibility = 'public' and deleted_at is null
  and (p_subject is null or subject = p_subject)
  and (
    title % p_query or 
    description % p_query or 
    title ilike '%' || p_query || '%' or 
    description ilike '%' || p_query || '%'
  )
  order by similarity(title, p_query) desc, feed_score desc, search_count desc
  limit p_limit;
end;
$$;

-- 9. GIST Indexes for Trigram search
create index if not exists idx_users_username_trgm on public.users using gist (username gist_trgm_ops);
create index if not exists idx_users_full_name_trgm on public.users using gist (full_name gist_trgm_ops);
create index if not exists idx_notes_title_trgm on public.notes using gist (title gist_trgm_ops);

-- 10. Grants
grant execute on function public.increment_user_search(uuid) to authenticated;
grant execute on function public.increment_note_search(uuid) to authenticated;
grant execute on function public.get_popular_creators(integer) to authenticated;
grant execute on function public.get_popular_notes(integer) to authenticated;
grant execute on function public.search_users_fuzzy(text, integer) to authenticated;
grant execute on function public.search_notes_fuzzy(text, text, integer) to authenticated;
