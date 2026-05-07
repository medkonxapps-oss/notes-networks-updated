# NotesNet

> *Where your notes go viral.*

A social learning platform for students — upload, share, and discover high-quality study notes.

## Architecture

| Layer | Tech |
|-------|------|
| Mobile App | Flutter (Android + iOS) |
| Admin Panel | Flutter Web |
| Backend Database | Supabase (PostgreSQL + RLS) |
| File Storage | Supabase Storage (private buckets) |
| Auth | Supabase Auth (email + Google OAuth) |
| Worker Server | Node.js + BullMQ + Redis on Hostinger VPS |
| Job Queue | BullMQ (Redis-backed) |
| Push Notifications | Firebase Cloud Messaging |
| Email | SendGrid |

## Packages

```
notesnet/
├── packages/
│   ├── app/           # Flutter mobile app (Android + iOS)
│   ├── admin/         # Flutter Web admin panel
│   ├── shared/        # Shared models + Supabase services
│   └── design_system/ # UI components + design tokens
├── backend/           # Node.js VPS worker server
└── supabase/          # SQL migrations + Edge Functions
```

## Quick Start

### Prerequisites
- Flutter SDK 3.22+
- Dart 3.4+
- Node.js 20 LTS
- Supabase CLI
- Melos CLI

### 1. Clone & Bootstrap
```bash
git clone https://github.com/yourorg/notesnet.git
cd notesnet
dart pub global activate melos
melos bootstrap
```

### 2. Setup Supabase
```bash
# Create a new project at supabase.com
# Then run migrations:
cd supabase
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

### 3. Configure environment
```bash
cp packages/app/.env.example packages/app/.env
# Fill in SUPABASE_URL and SUPABASE_ANON_KEY
```

### 4. Run mobile app
```bash
melos run:app
```

### 5. Run admin panel
```bash
melos run:admin
```

### 6. Start VPS backend locally
```bash
cd backend
cp .env.example .env   # fill in all keys
npm install
npm run dev
```

## Database Setup

Run migrations in order:
```bash
supabase db push  # runs all files in supabase/migrations/ in order
```

Migrations:
1. `001_initial_schema.sql` — All tables
2. `002_rls_policies.sql` — Row Level Security
3. `003_functions_triggers.sql` — Triggers & functions
4. `004_indexes.sql` — Performance indexes
5. `005_seed_data.sql` — Badges & rewards catalog

## Storage Buckets

Create these in Supabase Storage (all **private**):
- `notes-files` — Original uploaded PDFs/images
- `note-pages` — Processed page images (JPG)
- `thumbnails` — Note thumbnail images (800×450 JPG)
- `avatars` — User profile pictures

## VPS Deployment

```bash
# On Hostinger VPS (Ubuntu 22.04)
curl -fsSL https://get.docker.com | sh
git clone https://github.com/yourorg/notesnet.git /opt/notesnet
cd /opt/notesnet/backend
cp .env.example .env  # fill production values
docker compose up -d --build

# SSL
apt install nginx certbot python3-certbot-nginx -y
certbot --nginx -d api.notesnet.app
```

## Key Features

- **Social feed** — For You (by feed_score) + Following tabs
- **Note cards** — Thumbnail, like/save with optimistic updates, report
- **Upload flow** — PDF or multi-image, tags, folder, visibility
- **Creator profiles** — Stats, followers, notes grid, folders
- **Leaderboard** — Weekly/Monthly/All-time with podium
- **Rewards** — Points system, catalog, redemption
- **Offline** — Saved notes cached locally via flutter_cache_manager
- **RLS** — Database-level security on every table
- **Admin panel** — Dashboard, moderation, user management, analytics

## Points System

| Event | Points |
|-------|--------|
| Upload a note | +50 |
| First ever upload | +100 bonus |
| Receive a like | +5 |
| Receive a save | +10 |
| Daily streak bonus | +25 |
| Get verified | +200 |

## License
Confidential — NotesNet © 2025
