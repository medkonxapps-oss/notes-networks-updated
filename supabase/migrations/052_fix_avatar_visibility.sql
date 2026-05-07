-- Migration 052: Fix profile image (avatar) visibility for all user types
--
-- Problems fixed:
-- 1. get_popular_notes() and search_notes_fuzzy() return setof public.notes
--    with NO joined user data → authorAvatarUrl is always null in the app.
-- 2. users_select RLS policy hides inactive users, so their avatar can't be
--    shown in historical note cards.
-- 3. Ensure avatars storage bucket is truly public (no auth required to read).

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Drop existing functions first (required when changing return type)
-- ─────────────────────────────────────────────────────────────────────────────
drop function if exists public.get_popular_notes(integer);
drop function if exists public.search_notes_fuzzy(text, text, integer);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Define a composite type for notes with author info
-- ─────────────────────────────────────────────────────────────────────────────
drop type if exists public.note_with_author cascade;
create type public.note_with_author as (
  -- all columns from public.notes
  id                uuid,
  user_id           uuid,
  folder_id         uuid,
  title             text,
  description       text,
  subject           text,
  class_level       text,
  board             text,
  file_type         text,
  file_keys         text[],
  thumbnail_key     text,
  page_count        integer,
  file_size_bytes   integer,
  visibility        text,
  status            text,
  tags              text[],
  likes_count       integer,
  saves_count       integer,
  views_count       integer,
  feed_score        double precision,
  is_sponsored      boolean,
  search_count      integer,
  created_at        timestamptz,
  updated_at        timestamptz,
  deleted_at        timestamptz,
  -- joined author fields
  author_name       text,
  author_username   text,
  author_avatar_url text,
  author_is_verified boolean
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Fix get_popular_notes — include author info in result
-- ─────────────────────────────────────────────────────────────────────────────
create function public.get_popular_notes(p_limit integer default 10)
returns setof public.note_with_author
language plpgsql security definer as $$
begin
  return query
  select
    n.id, n.user_id, n.folder_id, n.title, n.description,
    n.subject, n.class_level, n.board, n.file_type, n.file_keys,
    n.thumbnail_key, n.page_count, n.file_size_bytes,
    n.visibility, n.status, n.tags,
    n.likes_count, n.saves_count, n.views_count,
    n.feed_score, n.is_sponsored, n.search_count,
    n.created_at, n.updated_at, n.deleted_at,
    u.full_name            as author_name,
    u.username             as author_username,
    u.avatar_url           as author_avatar_url,
    u.is_verified_creator  as author_is_verified
  from public.notes n
  left join public.users u on u.id = n.user_id
  where n.status = 'active'
    and n.visibility = 'public'
    and n.deleted_at is null
  order by (n.feed_score * 5 + n.search_count) desc
  limit p_limit;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Fix search_notes_fuzzy — include author info in result
-- ─────────────────────────────────────────────────────────────────────────────
create function public.search_notes_fuzzy(
  p_query   text,
  p_subject text    default null,
  p_limit   integer default 30
)
returns setof public.note_with_author
language plpgsql security definer as $$
begin
  return query
  select
    n.id, n.user_id, n.folder_id, n.title, n.description,
    n.subject, n.class_level, n.board, n.file_type, n.file_keys,
    n.thumbnail_key, n.page_count, n.file_size_bytes,
    n.visibility, n.status, n.tags,
    n.likes_count, n.saves_count, n.views_count,
    n.feed_score, n.is_sponsored, n.search_count,
    n.created_at, n.updated_at, n.deleted_at,
    u.full_name            as author_name,
    u.username             as author_username,
    u.avatar_url           as author_avatar_url,
    u.is_verified_creator  as author_is_verified
  from public.notes n
  left join public.users u on u.id = n.user_id
  where n.status = 'active'
    and n.visibility = 'public'
    and n.deleted_at is null
    and (p_subject is null or n.subject = p_subject)
    and (
      n.title       % p_query or
      n.description % p_query or
      n.title       ilike '%' || p_query || '%' or
      n.description ilike '%' || p_query || '%'
    )
  order by similarity(n.title, p_query) desc, n.feed_score desc, n.search_count desc
  limit p_limit;
end;
$$;

-- Re-grant execute permissions
grant execute on function public.get_popular_notes(integer)              to authenticated, anon;
grant execute on function public.search_notes_fuzzy(text, text, integer) to authenticated, anon;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Fix users_select RLS — allow authenticated users to read any non-deleted
--    user row so historical note cards always show the author's avatar/name
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists "users_select" on public.users;

create policy "users_select" on public.users
  for select using (
    -- Admins see everything
    public.is_admin()
    -- Own row always visible
    or auth.uid() = id
    -- Active, non-deleted users visible to everyone
    or (deleted_at is null and is_active = true)
    -- Inactive users still readable by authenticated users
    -- (needed so note cards can show their avatar/name)
    or (auth.uid() is not null and deleted_at is null)
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Ensure avatars bucket is public so avatar URLs work without a session
-- ─────────────────────────────────────────────────────────────────────────────
update storage.buckets
set public = true
where id = 'avatars';

drop policy if exists "avatars_read" on storage.objects;
create policy "avatars_read" on storage.objects
  for select using (bucket_id = 'avatars');
