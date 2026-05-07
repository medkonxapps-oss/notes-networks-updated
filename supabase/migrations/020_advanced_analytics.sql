-- ═══════════════════════════════════════════════════════════════════════════════
-- Migration 020: Advanced Analytics and View Tracking
-- ═══════════════════════════════════════════════════════════════════════════════

-- ── 1. NOTE VIEWS TRACKING ───────────────────────────────────────────────────
-- Table for detailed view logs (helps with unique views and time-series analysis)
create table if not exists public.note_views (
  id         uuid primary key default gen_random_uuid(),
  note_id    uuid not null references public.notes(id) on delete cascade,
  user_id    uuid references public.users(id) on delete set null,
  ip_hash    text, -- For anonymous tracking/uniqueness
  created_at timestamptz default now()
);

-- Index for analytics speed
create index if not exists note_views_note_id_idx on public.note_views(note_id);
create index if not exists note_views_created_at_idx on public.note_views(created_at);

-- Function to increment view count safely and log it
create or replace function public.increment_note_view(p_note_id uuid, p_user_id uuid default null)
returns void language plpgsql security definer as $$
begin
  -- 1. Log the view
  insert into public.note_views (note_id, user_id)
  values (p_note_id, p_user_id);

  -- 2. Update the counter on the notes table
  update public.notes
  set views_count = views_count + 1
  where id = p_note_id;
end;
$$;

grant execute on function public.increment_note_view(uuid, uuid) to authenticated, anon;

-- ── 2. ANALYTICS VIEWS ───────────────────────────────────────────────────────

-- A. Daily Activity (Uploads, Likes, Saves, Views)
create or replace view public.admin_daily_stats as
with dates as (
  select generate_series(
    current_date - interval '29 days',
    current_date,
    interval '1 day'
  )::date as date
),
note_counts as (
  select created_at::date as date, count(*) as count 
  from public.notes group by 1
),
view_counts as (
  select created_at::date as date, count(*) as count 
  from public.note_views group by 1
),
like_counts as (
  select created_at::date as date, count(*) as count 
  from public.likes group by 1
)
select 
  d.date,
  coalesce(n.count, 0) as uploads,
  coalesce(v.count, 0) as views,
  coalesce(l.count, 0) as likes
from dates d
left join note_counts n on d.date = n.date
left join view_counts v on d.date = v.date
left join like_counts l on d.date = l.date
order by d.date desc;

-- B. Subject Popularity (Total notes and total views per subject)
create or replace view public.admin_subject_analytics as
select 
  subject,
  count(*) as total_notes,
  sum(views_count) as total_views,
  sum(likes_count) as total_likes
from public.notes
group by subject
order by total_views desc;

-- Grant permissions for admin app
grant select on public.admin_daily_stats to authenticated;
grant select on public.admin_subject_analytics to authenticated;

-- ── 3. RLS FOR NOTE_VIEWS ─────────────────────────────────────────────────────
alter table public.note_views enable row level security;

create policy "Admins can view all note views" on public.note_views
  for select to authenticated using (public.is_admin());

create policy "Public can insert views" on public.note_views
  for insert to anon, authenticated with check (true);
