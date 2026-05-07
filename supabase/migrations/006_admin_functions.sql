-- ── RPC: admin_add_points ────────────────────────────────────────────────────────
create or replace function public.admin_add_points(user_id uuid, amount integer)
returns void as $$
begin
  -- Insert into ledger
  insert into public.points_ledger (user_id, event_type, points, reference_id)
  values (user_id, 'admin_grant', amount, auth.uid());

  -- Update user total
  update public.users
  set total_points = total_points + amount,
      updated_at = now()
  where id = user_id;
end;
$$ language plpgsql security definer;
