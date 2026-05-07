-- Migration 048: Note Collections (Bundles)
-- Allows users (especially creators/teachers) to group notes into public bundles.

-- 1. Create note_collections table
CREATE TABLE IF NOT EXISTS public.note_collections (
    id          uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title       text NOT NULL,
    description text,
    thumbnail_url text,
    thumbnail_key text, -- New column for robust storage paths
    is_public   boolean NOT NULL DEFAULT true,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

-- 2. Create note_collection_items table (junction table)
CREATE TABLE IF NOT EXISTS public.note_collection_items (
    id            uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    collection_id uuid NOT NULL REFERENCES public.note_collections(id) ON DELETE CASCADE,
    note_id       uuid NOT NULL REFERENCES public.notes(id) ON DELETE CASCADE,
    sort_order    integer NOT NULL DEFAULT 0,
    created_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE(collection_id, note_id)
);

-- 3. Enable RLS
ALTER TABLE public.note_collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.note_collection_items ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies for note_collections
DROP POLICY IF EXISTS "Public collections are viewable by everyone" ON public.note_collections;
CREATE POLICY "Public collections are viewable by everyone"
    ON public.note_collections FOR SELECT
    USING (is_public = true OR auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can manage their own collections" ON public.note_collections;
CREATE POLICY "Users can manage their own collections"
    ON public.note_collections FOR ALL
    USING (auth.uid() = user_id);

-- 5. RLS Policies for note_collection_items
DROP POLICY IF EXISTS "Items of public collections are viewable by everyone" ON public.note_collection_items;
CREATE POLICY "Items of public collections are viewable by everyone"
    ON public.note_collection_items FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.note_collections 
            WHERE id = collection_id 
            AND (is_public = true OR auth.uid() = user_id)
        )
    );

DROP POLICY IF EXISTS "Users can manage items in their own collections" ON public.note_collection_items;
CREATE POLICY "Users can manage items in their own collections"
    ON public.note_collection_items FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.note_collections 
            WHERE id = collection_id AND auth.uid() = user_id
        )
    );

-- 6. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_note_collections_user_id ON public.note_collections(user_id);
CREATE INDEX IF NOT EXISTS idx_note_collection_items_collection_id ON public.note_collection_items(collection_id);

-- 7. Trigger for updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_collection_update ON public.note_collections;
CREATE TRIGGER on_collection_update
    BEFORE UPDATE ON public.note_collections
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- 8. View for collections with stats
-- Dropping first to avoid conflicts with column changes
DROP VIEW IF EXISTS public.note_collections_with_stats;
CREATE OR REPLACE VIEW public.note_collections_with_stats AS
SELECT 
    c.*,
    u.full_name as author_name,
    u.username as author_username,
    u.avatar_url as author_avatar_url,
    (SELECT count(*) FROM public.note_collection_items ci WHERE ci.collection_id = c.id) as items_count
FROM public.note_collections c
JOIN public.users u ON c.user_id = u.id;

-- 9. Grants
GRANT SELECT ON public.note_collections_with_stats TO authenticated;
GRANT ALL ON public.note_collections TO authenticated;
GRANT ALL ON public.note_collection_items TO authenticated;
