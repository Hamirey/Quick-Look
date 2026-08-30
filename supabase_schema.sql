-- ==============================================================================
-- SUPABASE BACKEND SCHEMA FOR TIKTOK-STYLE VIRAL NEWS APP
-- ==============================================================================
-- Tables: viral_tweets, app_comments, content_reports, blocked_users
-- Features: RLS Policies, Constraints, Indexes & Helper Triggers
-- ==============================================================================

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ------------------------------------------------------------------------------
-- 1. TABLE: viral_tweets
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.viral_tweets (
    tweet_id TEXT PRIMARY KEY,
    author TEXT NOT NULL,
    caption TEXT,
    media_url TEXT,
    x_url TEXT,
    category TEXT NOT NULL CHECK (category IN ('Afrobeats', 'Nollywood', 'Tech', 'Politics')),
    app_likes INT NOT NULL DEFAULT 0,
    app_dislikes INT NOT NULL DEFAULT 0,
    app_comments_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Indexes for fast feed ordering and category filtering
CREATE INDEX IF NOT EXISTS idx_viral_tweets_category ON public.viral_tweets(category);
CREATE INDEX IF NOT EXISTS idx_viral_tweets_created_at ON public.viral_tweets(created_at DESC);

-- ------------------------------------------------------------------------------
-- 2. TABLE: app_comments
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tweet_id TEXT NOT NULL REFERENCES public.viral_tweets(tweet_id) ON DELETE CASCADE,
    user_id UUID DEFAULT auth.uid(),
    author_name TEXT NOT NULL DEFAULT 'Anonymous',
    comment_text TEXT NOT NULL CHECK (char_length(trim(comment_text)) > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Index for comment lookups by tweet
CREATE INDEX IF NOT EXISTS idx_app_comments_tweet_id ON public.app_comments(tweet_id);
CREATE INDEX IF NOT EXISTS idx_app_comments_created_at ON public.app_comments(created_at ASC);

-- ------------------------------------------------------------------------------
-- 3. TABLE: content_reports
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.content_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tweet_id TEXT REFERENCES public.viral_tweets(tweet_id) ON DELETE CASCADE,
    comment_id UUID REFERENCES public.app_comments(id) ON DELETE CASCADE,
    reporter_id UUID DEFAULT auth.uid(),
    reason TEXT NOT NULL,
    details TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'dismissed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_content_reports_tweet_id ON public.content_reports(tweet_id);
CREATE INDEX IF NOT EXISTS idx_content_reports_status ON public.content_reports(status);

-- ------------------------------------------------------------------------------
-- 4. TABLE: blocked_users
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.blocked_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL DEFAULT auth.uid(),
    blocked_user_id UUID,
    blocked_handle TEXT,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT check_blocked_target CHECK (blocked_user_id IS NOT NULL OR blocked_handle IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_blocked_users_user_id ON public.blocked_users(user_id);

-- ------------------------------------------------------------------------------
-- 5. TRIGGER: Auto-Update app_comments_count on viral_tweets
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_comment_count_change()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE public.viral_tweets
        SET app_comments_count = app_comments_count + 1
        WHERE tweet_id = NEW.tweet_id;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE public.viral_tweets
        SET app_comments_count = GREATEST(0, app_comments_count - 1)
        WHERE tweet_id = OLD.tweet_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_comment_count_change ON public.app_comments;
CREATE TRIGGER trigger_comment_count_change
AFTER INSERT OR DELETE ON public.app_comments
FOR EACH ROW
EXECUTE FUNCTION public.handle_comment_count_change();

-- ------------------------------------------------------------------------------
-- 6. ROW LEVEL SECURITY (RLS) POLICIES
-- ------------------------------------------------------------------------------

-- Enable RLS across all tables
ALTER TABLE public.viral_tweets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------------------------
-- RLS: viral_tweets
-- ------------------------------------------------------------------------------
-- Public read access (anon and authenticated users can view viral tweets)
CREATE POLICY "Allow public read access on viral_tweets"
ON public.viral_tweets
FOR SELECT
TO anon, authenticated
USING (true);

-- ------------------------------------------------------------------------------
-- RLS: app_comments
-- ------------------------------------------------------------------------------
-- Public read access to comments
CREATE POLICY "Allow public read access on app_comments"
ON public.app_comments
FOR SELECT
TO anon, authenticated
USING (true);

-- Allow insertion to authenticated users and anonymous sessions
CREATE POLICY "Allow comment insertion for authenticated and anon users"
ON public.app_comments
FOR INSERT
TO anon, authenticated
WITH CHECK (
    char_length(trim(comment_text)) > 0
);

-- Users can delete their own comments if authenticated
CREATE POLICY "Allow users to delete their own comments"
ON public.app_comments
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- ------------------------------------------------------------------------------
-- RLS: content_reports
-- ------------------------------------------------------------------------------
-- Allow insertion of reports for authenticated and anon users
CREATE POLICY "Allow report insertion for authenticated and anon users"
ON public.content_reports
FOR INSERT
TO anon, authenticated
WITH CHECK (
    char_length(trim(reason)) > 0
);

-- Reports can only be viewed by authenticated admins/service role
-- (Standard users cannot read reports)
CREATE POLICY "Allow users to view only their own submitted reports"
ON public.content_reports
FOR SELECT
TO authenticated
USING (auth.uid() = reporter_id);

-- ------------------------------------------------------------------------------
-- RLS: blocked_users
-- ------------------------------------------------------------------------------
-- Users can view only their own blocklist
CREATE POLICY "Allow users to read their own blocked list"
ON public.blocked_users
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Allow authenticated and anon sessions to insert blocks
CREATE POLICY "Allow block insertion for authenticated and anon users"
ON public.blocked_users
FOR INSERT
TO anon, authenticated
WITH CHECK (
    (auth.uid() IS NOT NULL AND user_id = auth.uid()) OR (auth.role() = 'anon')
);

-- Allow users to unblock / delete their own blocks
CREATE POLICY "Allow users to delete their own blocked entries"
ON public.blocked_users
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);
