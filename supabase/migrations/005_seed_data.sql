-- Seed badges
insert into public.badges (name, description, icon_key, badge_type, required_value) values
  ('First Note', 'Upload your first note', 'badge_first', 'upload_count', 1),
  ('Note Creator', 'Upload 10 notes', 'badge_creator', 'upload_count', 10),
  ('Prolific Writer', 'Upload 50 notes', 'badge_prolific', 'upload_count', 50),
  ('Century Club', 'Upload 100 notes', 'badge_century', 'upload_count', 100),
  ('Liked Creator', 'Receive 100 likes', 'badge_liked', 'total_likes', 100),
  ('Viral Notes', 'Receive 1000 likes', 'badge_viral', 'total_likes', 1000),
  ('Week Warrior', '7-day upload streak', 'badge_streak7', 'streak', 7),
  ('Month Master', '30-day upload streak', 'badge_streak30', 'streak', 30),
  ('Verified Creator', 'Verified by admin', 'badge_verified', 'verified', 0);

-- Seed rewards catalog
insert into public.rewards_catalog (name, description, points_cost, reward_type, stock) values
  ('Amazon ₹100 Voucher', 'Redeem for ₹100 Amazon gift card', 1000, 'voucher', 100),
  ('Swiggy ₹150 Coupon', '₹150 off your next Swiggy order', 1500, 'coupon', 50),
  ('NotesNet T-Shirt', 'Official branded merchandise', 3000, 'courier', 30),
  ('Stationery Kit', 'Premium stationery set for creators', 2000, 'courier', 50),
  ('Amazon ₹500 Voucher', 'Redeem for ₹500 Amazon gift card', 4000, 'voucher', 25),
  ('Zomato ₹200 Coupon', '₹200 off your next Zomato order', 2000, 'coupon', 50);

-- Seed feature flags
insert into public.feature_flags (flag_name, is_enabled, description) values
  ('sponsored_notes', true, 'Show sponsored notes in feed'),
  ('creator_verification', true, 'Allow creator verification requests'),
  ('streak_notifications', true, 'Send daily streak reminder notifications'),
  ('weekly_digest', true, 'Send weekly email digest to creators');
