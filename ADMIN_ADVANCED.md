# 🚀 Admin Panel — Advanced Upgrades

## New Features Added

### 1. 🏠 Dashboard — Complete Overhaul
- **Real-time live counters** — Supabase realtime channels show +users and +notes as they happen (animated live badge)
- **Growth indicators** — Each KPI card shows % change vs yesterday
- **8 KPI cards** — Users, Notes, Views, Likes, Pending Notes, Open Reports, Redemptions, Pending Verify
- **Clickable KPIs** — Clicking a card navigates to the relevant screen
- **Activity Feed** — Shows latest 8 platform notifications live
- **Top Creators grid** — 6 creators in card layout with rank colors
- **Recent Notes table** — Sortable with author, subject, views, status columns
- **Date header** shows full date in header

### 2. 📈 Analytics — 4-Tab Advanced Insights
- **Growth Tab** — Line chart for new users + notes over selected period, summary cards with peak day
- **Content Tab** — Bar chart for views & likes by day  
- **Subjects Tab** — Pie chart + ranked bar list of top 10 subjects
- **Retention Tab** — Platform health: 7-day active users %, avg streak, views per note, engagement breakdown
- **Period selector** — 7D / 30D / 90D toggle

### 3. 🔍 Audit Log — New Screen
- **Full paginated audit trail** — Infinite scroll with 50 items per page
- **Filter by action type** — approve_note, reject_note, suspend_user, verify_creator, etc.
- **Search** — Filter by admin username, target ID, action, details
- **Click for details** — Dialog shows full metadata, IP, exact timestamp
- **Copy target ID** — Click ID to copy to clipboard
- **Color-coded actions** — Green for positive, red for destructive, blue for informational

### 4. 🎫 Support Tickets — Master-Detail Layout
- **Split view** — Ticket list on left, full detail on right
- **Status filters** — Open, In Progress, Resolved, All (chip filters)
- **Reply box** — Type reply and send, or Send & Resolve in one click
- **Previous reply shown** — Existing admin_reply displayed in conversation bubble style
- **Category & Priority tags** — Displayed inline
- **Reopen resolved tickets** — Button changes based on status

### 5. 🔐 Security
- **Admin role verification on login** — If user has no admin_role row, they are signed out immediately
- **Granular permissions** — `AdminRole` model with `can(permission)` method
- **Super admin** gets all permissions automatically
- **Audit logging** — All moderation actions (approve, reject, suspend) are logged to `admin_audit_log`

### 6. 🌙 Dark Theme
- Admin panel now respects system dark/light mode preference

---

## Database Changes (run migration 019)
`supabase/migrations/019_admin_advanced.sql`

- Creates `admin_audit_log` table with RLS (readable by admins only, writable only via `log_admin_action()` function)
- Updates `admin_kpi_stats` view with `pending_teachers`, `active_users_7d`, `avg_streak`, `notes_with_views`, `verified_creators`
- Adds `permissions` JSONB column to `admin_roles`
- Adds `admin_reply`, `priority`, `category`, `resolved_at` to `support_tickets`
- Creates `log_admin_action()` helper function (SECURITY DEFINER)

## How to Apply
1. Run `supabase/migrations/019_admin_advanced.sql` on your Supabase project
2. Run `supabase/migrations/018_security_and_fixes.sql` if not already done
3. Replace `packages/admin` folder
4. Build admin web: `flutter build web` from `packages/admin`
