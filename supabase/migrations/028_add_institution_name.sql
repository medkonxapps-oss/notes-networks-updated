-- Migration 028: Add institution_name to users table
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS institution_name varchar(150);
