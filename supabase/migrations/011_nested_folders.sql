-- ══════════════════════════════════════════════════════════════════════════════
-- Migration 011: Add nested folder support (parent_folder_id)
-- ══════════════════════════════════════════════════════════════════════════════

-- Add parent_folder_id column (self-referencing FK, nullable = root folder)
alter table public.folders
  add column if not exists parent_folder_id uuid references public.folders(id) on delete cascade;

-- Index for fast child lookup
create index if not exists idx_folders_parent on public.folders(parent_folder_id);

-- Grant (already granted in 008 but ensure it covers new column)
grant select, insert, update, delete on public.folders to authenticated;
