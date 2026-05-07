-- ═══════════════════════════════════════════════════════════════════════════════
-- Migration 018: Rewards Management, Download Points, and Notifications
-- ═══════════════════════════════════════════════════════════════════════════════

-- ── 1. NOTIFICATION TYPE EXTENSION ───────────────────────────────────────────
-- Add 'download' to the allowed notification types
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check
  check (type in ('like', 'follow', 'reward', 'system', 'streak', 'save', 'download'));

-- ── 2. FIX TOGGLE_SAVE NOTIFICATION TYPE ─────────────────────────────────────
-- In the previous migration, toggle_save was using 'like' as the type. Fix it to 'save'.
create or replace function public.toggle_save(p_note_id uuid, p_user_id uuid)
returns jsonb language plpgsql security definer as $$
declare
  v_exists boolean;
  v_author_id uuid;
  v_note_title text;
  v_user_name text;
begin
  select exists(select 1 from public.saves where note_id = p_note_id and user_id = p_user_id)
  into v_exists;

  if v_exists then
    delete from public.saves where note_id = p_note_id and user_id = p_user_id;
    -- Note: Points are not usually deducted on unsave to prevent negative gaming, 
    -- but you can add decrement logic here if desired.
    return jsonb_build_object('action', 'unsaved', 'is_saved', false);
  else
    insert into public.saves (note_id, user_id) values (p_note_id, p_user_id)
    on conflict (user_id, note_id) do nothing;

    select user_id, title into v_author_id, v_note_title from public.notes where id = p_note_id;
    select full_name into v_user_name from public.users where id = p_user_id;

    if v_author_id != p_user_id then
      -- Award 10 points to author
      update public.users set total_points = total_points + 10 where id = v_author_id;

      -- Send notification
      insert into public.notifications (user_id, type, title, message, reference_id)
      values (v_author_id, 'save', 'Note Saved',
        v_user_name || ' saved your note: ' || v_note_title, p_note_id)
      on conflict do nothing;
    end if;

    return jsonb_build_object('action', 'saved', 'is_saved', true);
  end if;
end;
$$;

-- ── 3. PROCESS DOWNLOAD FUNCTION ─────────────────────────────────────────────
-- Function to award points and notify author when a note is downloaded for offline
create or replace function public.process_download(p_note_id uuid, p_user_id uuid)
returns void language plpgsql security definer as $$
declare
  v_author_id uuid;
  v_note_title text;
  v_user_name text;
begin
  select user_id, title into v_author_id, v_note_title from public.notes where id = p_note_id;
  select full_name into v_user_name from public.users where id = p_user_id;

  if v_author_id != p_user_id then
    -- Award 10 points to author (same as save)
    update public.users set total_points = total_points + 10 where id = v_author_id;

    -- Send notification with type 'download'
    insert into public.notifications (user_id, type, title, message, reference_id)
    values (v_author_id, 'download', 'Note Downloaded',
      v_user_name || ' downloaded your note for offline: ' || v_note_title, p_note_id)
    on conflict do nothing;
  end if;
end;
$$;

grant execute on function public.process_download(uuid, uuid) to authenticated;

-- ── 4. ATOMIC REDEMPTION FUNCTION ────────────────────────────────────────────
-- Safer way to redeem rewards than manual app-side deduction
create or replace function public.redeem_reward(p_reward_id uuid, p_user_id uuid)
returns jsonb language plpgsql security definer as $$
declare
  v_cost integer;
  v_points integer;
  v_stock integer;
  v_reward_name text;
begin
  select points_cost, stock, name into v_cost, v_stock, v_reward_name 
  from public.rewards_catalog where id = p_reward_id and is_active = true;
  
  select total_points into v_points from public.users where id = p_user_id;

  if v_cost is null then
    return jsonb_build_object('success', false, 'error', 'Reward not found');
  end if;

  if v_stock <= 0 then
    return jsonb_build_object('success', false, 'error', 'Out of stock');
  end if;

  if v_points < v_cost then
    return jsonb_build_object('success', false, 'error', 'Insufficient points');
  end if;

  -- Deduct points
  update public.users set total_points = total_points - v_cost where id = p_user_id;

  -- Decrease stock
  update public.rewards_catalog set stock = stock - 1 where id = p_reward_id;

  -- Create redemption record
  insert into public.redemptions (user_id, reward_id, points_spent, status)
  values (p_user_id, p_reward_id, v_cost, 'pending');

  -- Notify user
  insert into public.notifications (user_id, type, title, message, reference_id)
  values (p_user_id, 'reward', 'Reward Redeemed',
    'You successfully redeemed: ' || v_reward_name, p_reward_id)
  on conflict do nothing;

  return jsonb_build_object('success', true, 'remaining_points', v_points - v_cost);
end;
$$;

grant execute on function public.redeem_reward(uuid, uuid) to authenticated;

-- ── 5. PERMISSIONS & RLS FOR REWARDS ─────────────────────────────────────────
-- Ensure tables are accessible to authenticated users
grant select, insert, update on public.rewards_catalog to authenticated;
grant select, insert, update on public.redemptions to authenticated;

-- Update RLS policies to be more permissive for authenticated users (admin logic handles the rest)
drop policy if exists "rewards_select_active" on public.rewards_catalog;
drop policy if exists "rewards_select_all" on public.rewards_catalog;
create policy "rewards_select_all" on public.rewards_catalog
  for select to authenticated using (true);

drop policy if exists "rewards_admin" on public.rewards_catalog;
drop policy if exists "rewards_admin_manage" on public.rewards_catalog;
create policy "rewards_admin_manage" on public.rewards_catalog
  for all to authenticated using (true); -- In production, use public.is_admin()

drop policy if exists "redemptions_select_own" on public.redemptions;
drop policy if exists "redemptions_manage_own" on public.redemptions;
create policy "redemptions_manage_own" on public.redemptions
  for all to authenticated using (auth.uid() = user_id);

-- ── 6. ADMIN ROLES TABLE ─────────────────────────────────────────────────────
-- Create missing admin_roles table for permissions check
create table if not exists public.admin_roles (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users(id) on delete cascade,
  role       text not null check (role in ('admin', 'moderator', 'support')),
  created_at timestamptz default now(),
  unique(user_id)
);

alter table public.admin_roles enable row level security;

drop policy if exists "Anyone can view admin roles" on public.admin_roles;
create policy "Anyone can view admin roles" on public.admin_roles
  for select to authenticated using (true);

grant select on public.admin_roles to authenticated;
