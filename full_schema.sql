-- ── 1. DATABASE RESET ───────────────────────────────────────────────────────────
drop schema if exists public cascade;
create schema public;


-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ── 2. TABLES CREATION ──────────────────────────────────────────────────────────
-- USERS
create table public.users (
  id                    uuid primary key default uuid_generate_v4(),
  username              varchar(30) unique not null,
  full_name             varchar(100) not null,
  email                 varchar(255) unique not null,
  phone                 varchar(15) unique,
  avatar_url            text,
  bio                   varchar(300),
  city                  varchar(100),
  board                 varchar(50) not null default 'CBSE',
  class_level           varchar(30) not null default 'Class 10',
  subjects              text[] default '{}',
  role                  text not null default 'student' check (role in ('student','creator','moderator','admin')),
  is_verified_creator   boolean not null default false,
  is_active             boolean not null default true,
  suspension_until      timestamptz,
  total_points          integer not null default 0,
  current_streak        integer not null default 0,
  longest_streak        integer not null default 0,
  last_upload_date      date,
  followers_count       integer not null default 0,
  following_count       integer not null default 0,
  notes_count           integer not null default 0,
  fcm_token             text,
  notification_preferences jsonb not null default '{"likes":true,"saves":true,"follows":true,"rewards":true,"streaks":true,"system":true}'::jsonb,
  failed_login_attempts integer not null default 0,
  last_failed_login_at  timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  deleted_at            timestamptz
);

-- FOLDERS
create table public.folders (
  id           uuid primary key default uuid_generate_v4(),
  user_id      uuid not null references public.users(id) on delete cascade,
  name         varchar(80) not null,
  color_hex    varchar(7) not null default '#4F46E5',
  notes_count  integer not null default 0,
  created_at   timestamptz not null default now()
);

-- NOTES
create table public.notes (
  id               uuid primary key default uuid_generate_v4(),
  user_id          uuid not null references public.users(id) on delete cascade,
  folder_id        uuid references public.folders(id) on delete set null,
  title            varchar(150) not null,
  description      text,
  subject          varchar(80) not null,
  class_level      varchar(30) not null,
  board            varchar(50) not null,
  file_type        text not null check (file_type in ('pdf','image_set')),
  file_keys        text[] not null default '{}',
  thumbnail_key    text,
  page_count       integer not null default 1,
  file_size_bytes  bigint not null default 0,
  visibility       text not null default 'public' check (visibility in ('public','followers')),
  status           text not null default 'processing' check (status in ('processing','active','removed','pending_review')),
  tags             text[] not null default '{}',
  likes_count      integer not null default 0,
  saves_count      integer not null default 0,
  views_count      integer not null default 0,
  feed_score       float not null default 0,
  is_sponsored     boolean not null default false,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  deleted_at       timestamptz
);

-- FOLLOWS
create table public.follows (
  id            uuid primary key default uuid_generate_v4(),
  follower_id   uuid not null references public.users(id) on delete cascade,
  following_id  uuid not null references public.users(id) on delete cascade,
  created_at    timestamptz not null default now(),
  unique(follower_id, following_id),
  check (follower_id != following_id)
);

-- LIKES
create table public.likes (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references public.users(id) on delete cascade,
  note_id     uuid not null references public.notes(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique(user_id, note_id)
);

-- SAVES
create table public.saves (
  id              uuid primary key default uuid_generate_v4(),
  user_id         uuid not null references public.users(id) on delete cascade,
  note_id         uuid not null references public.notes(id) on delete cascade,
  cached_locally  boolean not null default false,
  created_at      timestamptz not null default now(),
  unique(user_id, note_id)
);

-- POINTS LEDGER
create table public.points_ledger (
  id            uuid primary key default uuid_generate_v4(),
  user_id       uuid not null references public.users(id) on delete cascade,
  event_type    text not null check (event_type in ('upload','like_received','save_received','streak_bonus','first_upload','verification_bonus','admin_grant')),
  points        integer not null,
  reference_id  uuid,
  created_at    timestamptz not null default now()
);

-- REPORTS
create table public.reports (
  id            uuid primary key default uuid_generate_v4(),
  reporter_id   uuid not null references public.users(id) on delete cascade,
  note_id       uuid not null references public.notes(id) on delete cascade,
  reason        text not null check (reason in ('inappropriate','spam','copyright','misleading','other')),
  details       text,
  status        text not null default 'pending' check (status in ('pending','resolved','dismissed')),
  admin_note    text,
  created_at    timestamptz not null default now()
);

-- NOTIFICATIONS
create table public.notifications (
  id            uuid primary key default uuid_generate_v4(),
  user_id       uuid not null references public.users(id) on delete cascade,
  type          text not null check (type in ('like','follow','reward','system','streak')),
  title         varchar(100) not null,
  message       text not null,
  reference_id  uuid,
  is_read       boolean not null default false,
  created_at    timestamptz not null default now()
);

-- BADGES
create table public.badges (
  id              uuid primary key default uuid_generate_v4(),
  name            varchar(80) not null unique,
  description     text not null,
  icon_key        text not null,
  badge_type      text not null check (badge_type in ('upload_count','total_likes','streak','manual','verified')),
  required_value  integer not null default 0,
  created_at      timestamptz not null default now()
);

create table public.user_badges (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references public.users(id) on delete cascade,
  badge_id    uuid not null references public.badges(id) on delete cascade,
  earned_at   timestamptz not null default now(),
  unique(user_id, badge_id)
);

-- REWARDS
create table public.rewards_catalog (
  id            uuid primary key default uuid_generate_v4(),
  name          varchar(100) not null,
  description   text not null,
  points_cost   integer not null,
  reward_type   text not null check (reward_type in ('voucher','courier','coupon')),
  image_key     text,
  stock         integer not null default 999,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);

create table public.redemptions (
  id             uuid primary key default uuid_generate_v4(),
  user_id        uuid not null references public.users(id) on delete cascade,
  reward_id      uuid not null references public.rewards_catalog(id),
  points_spent   integer not null,
  status         text not null default 'pending' check (status in ('pending','dispatched','delivered','cancelled')),
  delivery_info  jsonb,
  created_at     timestamptz not null default now()
);

-- FEATURE FLAGS
create table public.feature_flags (
  id          uuid primary key default uuid_generate_v4(),
  flag_name   varchar(80) not null unique,
  is_enabled  boolean not null default true,
  value       text,
  description text,
  updated_at  timestamptz not null default now()
);

-- ── 3. FUNCTIONS & TRIGGERS ────────────────────────────────────────────────────
-- Auto-update updated_at
create or replace function public.set_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger set_users_updated_at before update on public.users for each row execute function public.set_updated_at();
create trigger set_notes_updated_at before update on public.notes for each row execute function public.set_updated_at();

-- Likes Count Trigger
create or replace function public.update_likes_count() returns trigger as $$
begin
  if tg_op = 'INSERT' then
    update public.notes set likes_count = likes_count + 1 where id = new.note_id;
  elsif tg_op = 'DELETE' then
    update public.notes set likes_count = greatest(likes_count - 1, 0) where id = old.note_id;
  end if;
  return null;
end;
$$ language plpgsql security definer;

create trigger trigger_likes_count after insert or delete on public.likes for each row execute function public.update_likes_count();

-- Admin: Add Points RPC
create or replace function public.admin_add_points(user_id uuid, amount integer) returns void as $$
begin
  insert into public.points_ledger (user_id, event_type, points) values (user_id, 'admin_grant', amount);
  update public.users set total_points = total_points + amount where id = user_id;
end;
$$ language plpgsql security definer;

-- ── 4. INDEXES ─────────────────────────────────────────────────────────────────
create index if not exists idx_notes_subject on public.notes(subject);
create index if not exists idx_notes_status on public.notes(status);
create index if not exists idx_users_role on public.users(role);

-- ── 5. RLS POLICIES ────────────────────────────────────────────────────────────
alter table public.users enable row level security;
alter table public.notes enable row level security;
alter table public.folders enable row level security;
alter table public.reports enable row level security;

create policy "Select active users" on public.users for select using (is_active = true);
create policy "Users manage own notes" on public.notes for all using (auth.uid() = user_id);
create policy "Public notes select" on public.notes for select using (visibility = 'public' and status = 'active');

-- ── 6. SEED DATA ───────────────────────────────────────────────────────────────
insert into public.badges (name, description, icon_key, badge_type, required_value) values
  ('First Note', 'Upload your first note', 'badge_first', 'upload_count', 1),
  ('Verified Creator', 'Verified by admin', 'badge_verified', 'verified', 0);

insert into public.rewards_catalog (name, description, points_cost, reward_type, stock) values
  ('Amazon ₹100 Voucher', 'Redeem for ₹100 Amazon gift card', 1000, 'voucher', 100);

insert into public.feature_flags (flag_name, is_enabled, description) values
  ('sponsored_notes', true, 'Show sponsored notes in feed');

-- ── 7. FINAL PERMISSIONS (Important for Admin Panel) ──────────────────────────
grant usage on schema public to postgres, anon, authenticated, service_role;
grant all privileges on all tables in schema public to postgres, service_role;
grant all privileges on all sequences in schema public to postgres, service_role;
grant all privileges on all functions in schema public to postgres, service_role;

-- Ensure future tables also get these permissions
alter default privileges in schema public grant all on tables to postgres, service_role;
alter default privileges in schema public grant all on sequences to postgres, service_role;
alter default privileges in schema public grant all on functions to postgres, service_role;
