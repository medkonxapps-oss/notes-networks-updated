-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ── USERS ──────────────────────────────────────────────────────────────────────
create table if not exists public.users (
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
  role                  text not null default 'student'
                          check (role in ('student','creator','moderator','admin')),
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
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  deleted_at            timestamptz
);
create index idx_users_username on public.users(username);
create index idx_users_email on public.users(email);
create index idx_users_role on public.users(role);
create index idx_users_points on public.users(total_points desc);

-- ── FOLDERS ────────────────────────────────────────────────────────────────────
create table if not exists public.folders (
  id           uuid primary key default uuid_generate_v4(),
  user_id      uuid not null references public.users(id) on delete cascade,
  name         varchar(80) not null,
  color_hex    varchar(7) not null default '#4F46E5',
  notes_count  integer not null default 0,
  created_at   timestamptz not null default now()
);
create index idx_folders_user_id on public.folders(user_id);
create unique index idx_folders_user_name on public.folders(user_id, lower(name));

-- ── NOTES ──────────────────────────────────────────────────────────────────────
create table if not exists public.notes (
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
  visibility       text not null default 'public'
                     check (visibility in ('public','followers')),
  status           text not null default 'processing'
                     check (status in ('processing','active','removed','pending_review')),
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
create index idx_notes_user_id on public.notes(user_id);
create index idx_notes_folder_id on public.notes(folder_id);
create index idx_notes_subject on public.notes(subject);
create index idx_notes_status on public.notes(status);
create index idx_notes_feed_score on public.notes(feed_score desc);
create index idx_notes_tags on public.notes using gin(tags);
create index idx_notes_created_at on public.notes(created_at desc);

-- ── FOLLOWS ────────────────────────────────────────────────────────────────────
create table if not exists public.follows (
  id            uuid primary key default uuid_generate_v4(),
  follower_id   uuid not null references public.users(id) on delete cascade,
  following_id  uuid not null references public.users(id) on delete cascade,
  created_at    timestamptz not null default now(),
  unique(follower_id, following_id),
  check (follower_id != following_id)
);
create index idx_follows_follower on public.follows(follower_id);
create index idx_follows_following on public.follows(following_id);

-- ── LIKES ──────────────────────────────────────────────────────────────────────
create table if not exists public.likes (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references public.users(id) on delete cascade,
  note_id     uuid not null references public.notes(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique(user_id, note_id)
);
create index idx_likes_note_id on public.likes(note_id);
create index idx_likes_user_id on public.likes(user_id);

-- ── SAVES ──────────────────────────────────────────────────────────────────────
create table if not exists public.saves (
  id              uuid primary key default uuid_generate_v4(),
  user_id         uuid not null references public.users(id) on delete cascade,
  note_id         uuid not null references public.notes(id) on delete cascade,
  cached_locally  boolean not null default false,
  created_at      timestamptz not null default now(),
  unique(user_id, note_id)
);
create index idx_saves_user_id on public.saves(user_id);
create index idx_saves_note_id on public.saves(note_id);

-- ── POINTS LEDGER ──────────────────────────────────────────────────────────────
create table if not exists public.points_ledger (
  id            uuid primary key default uuid_generate_v4(),
  user_id       uuid not null references public.users(id) on delete cascade,
  event_type    text not null check (event_type in (
                  'upload','like_received','save_received',
                  'streak_bonus','first_upload','verification_bonus','admin_grant')),
  points        integer not null,
  reference_id  uuid,
  created_at    timestamptz not null default now()
);
create index idx_points_user_id on public.points_ledger(user_id);
create index idx_points_created_at on public.points_ledger(created_at desc);

-- ── BADGES ─────────────────────────────────────────────────────────────────────
create table if not exists public.badges (
  id              uuid primary key default uuid_generate_v4(),
  name            varchar(80) not null unique,
  description     text not null,
  icon_key        text not null,
  badge_type      text not null check (badge_type in ('upload_count','total_likes','streak','manual','verified')),
  required_value  integer not null default 0,
  created_at      timestamptz not null default now()
);

create table if not exists public.user_badges (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references public.users(id) on delete cascade,
  badge_id    uuid not null references public.badges(id) on delete cascade,
  earned_at   timestamptz not null default now(),
  unique(user_id, badge_id)
);

-- ── REWARDS ────────────────────────────────────────────────────────────────────
create table if not exists public.rewards_catalog (
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

create table if not exists public.redemptions (
  id             uuid primary key default uuid_generate_v4(),
  user_id        uuid not null references public.users(id) on delete cascade,
  reward_id      uuid not null references public.rewards_catalog(id),
  points_spent   integer not null,
  status         text not null default 'pending'
                   check (status in ('pending','dispatched','delivered','cancelled')),
  delivery_info  jsonb,
  created_at     timestamptz not null default now()
);

-- ── NOTIFICATIONS ──────────────────────────────────────────────────────────────
create table if not exists public.notifications (
  id            uuid primary key default uuid_generate_v4(),
  user_id       uuid not null references public.users(id) on delete cascade,
  type          text not null check (type in ('like','follow','reward','system','streak')),
  title         varchar(100) not null,
  message       text not null,
  reference_id  uuid,
  is_read       boolean not null default false,
  created_at    timestamptz not null default now()
);
create index idx_notifications_user_id on public.notifications(user_id, is_read);

-- ── REPORTS ────────────────────────────────────────────────────────────────────
create table if not exists public.reports (
  id            uuid primary key default uuid_generate_v4(),
  reporter_id   uuid not null references public.users(id) on delete cascade,
  note_id       uuid not null references public.notes(id) on delete cascade,
  reason        text not null check (reason in ('inappropriate','spam','copyright','misleading','other')),
  details       text,
  status        text not null default 'pending'
                  check (status in ('pending','resolved','dismissed')),
  admin_note    text,
  created_at    timestamptz not null default now()
);

-- ── ADMIN TABLES ───────────────────────────────────────────────────────────────
create table if not exists public.admin_audit_log (
  id           uuid primary key default uuid_generate_v4(),
  admin_id     uuid not null references public.users(id),
  action       varchar(80) not null,
  target_type  varchar(40) not null,
  target_id    uuid,
  details      jsonb,
  ip_address   inet,
  created_at   timestamptz not null default now()
);

create table if not exists public.feature_flags (
  id          uuid primary key default uuid_generate_v4(),
  flag_name   varchar(80) not null unique,
  is_enabled  boolean not null default true,
  value       text,
  description text,
  updated_by  uuid references public.users(id),
  updated_at  timestamptz not null default now()
);

create table if not exists public.support_tickets (
  id               uuid primary key default uuid_generate_v4(),
  user_id          uuid not null references public.users(id) on delete cascade,
  subject          varchar(150) not null,
  body             text not null,
  status           text not null default 'open'
                     check (status in ('open','in_progress','resolved')),
  assigned_to      uuid references public.users(id),
  resolution_note  text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create table if not exists public.sponsored_notes (
  id                  uuid primary key default uuid_generate_v4(),
  brand_name          varchar(100) not null,
  note_id             uuid not null references public.notes(id) on delete cascade,
  campaign_start      date not null,
  campaign_end        date not null,
  budget_impressions  integer not null default 0,
  impressions_served  integer not null default 0,
  is_active           boolean not null default true,
  created_at          timestamptz not null default now()
);
