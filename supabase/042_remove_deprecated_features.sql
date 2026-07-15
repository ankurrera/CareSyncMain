-- ============================================================================
-- Migration 042: Remove decommissioned features
-- ============================================================================
-- Drops all database objects belonging to features that have been removed
-- from the CareSync client:
--
--   1. End-to-End Messaging / Chat
--        - tables: messages, chat_rooms  (011_messaging_schema.sql)
--        - message columns is_read / attachment_url  (030_update_messages_schema.sql)
--        - RLS policies, indexes  (011, 030)  [dropped implicitly with the tables]
--        - realtime publication membership  (029_enable_realtime_chat.sql) [implicit]
--        - RPC find_profile_by_email  (028_fix_chat_profile_lookup.sql)
--        - chat_attachments storage policies  (030)
--          (the bucket itself must be deleted via the Storage API / dashboard —
--           SQL cannot delete storage.* rows; see note in the body)
--
--   2. Profile Switching / Family accounts
--        - table family_account_links + RPC send_family_request
--          (created out-of-band in the live database; never tracked in the
--           repo migrations, so there is no CREATE to revert here)
--
--   3. Wearable "Patient Status" data
--        - wearable columns / constraint / index on the SHARED `vitals` table
--          (026_wearable_migration.sql). The `vitals` table itself is core
--          manual-vitals storage and is KEPT — only wearable objects are dropped.
--
-- This script is idempotent and safe to run whether or not the objects still
-- exist. It is wrapped in a single transaction: either everything is removed
-- or nothing is.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. MESSAGING / CHAT
-- ============================================================================
-- Dropping the tables with CASCADE also removes their RLS policies, indexes,
-- foreign keys, and their membership in the supabase_realtime publication.
-- `messages` is dropped first because it references `chat_rooms`.
DROP TABLE IF EXISTS public.messages CASCADE;
DROP TABLE IF EXISTS public.chat_rooms CASCADE;

-- Chat profile-lookup RPC (028). Drop every overload by name for robustness.
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT oid::regprocedure AS sig
        FROM pg_proc
        WHERE proname = 'find_profile_by_email'
          AND pronamespace = 'public'::regnamespace
    LOOP
        EXECUTE 'DROP FUNCTION ' || r.sig;
    END LOOP;
END $$;

-- Chat attachment storage policies (030). These are DDL drops and are allowed.
DROP POLICY IF EXISTS "Allow authenticated users to upload chat attachments" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to view chat attachments" ON storage.objects;

-- NOTE: The `chat_attachments` bucket and its objects are intentionally NOT
-- deleted here. Supabase blocks direct DELETE on the storage.* tables via the
-- storage.protect_delete() trigger ("Direct deletion from storage tables is not
-- allowed. Use the Storage API instead."). Remove the bucket separately using
-- the Supabase Dashboard (Storage -> chat_attachments -> Delete bucket) or the
-- Storage API — that also deletes the objects it holds.

-- ============================================================================
-- 2. PROFILE SWITCHING / FAMILY ACCOUNTS
-- (Not defined in any repo migration — these live only in the running DB.)
-- ============================================================================
-- Drop every overload of the family-request RPC by name (signature unknown).
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT oid::regprocedure AS sig
        FROM pg_proc
        WHERE proname = 'send_family_request'
          AND pronamespace = 'public'::regnamespace
    LOOP
        EXECUTE 'DROP FUNCTION ' || r.sig;
    END LOOP;
END $$;

-- Table + its RLS policies / indexes (CASCADE handles dependents).
DROP TABLE IF EXISTS public.family_account_links CASCADE;

-- ============================================================================
-- 3. WEARABLE "PATIENT STATUS" DATA  (columns on the shared `vitals` table)
-- ============================================================================
-- Index and constraint added for wearable de-duplication (026).
DROP INDEX IF EXISTS public.idx_vitals_duplicate_hash;
ALTER TABLE public.vitals DROP CONSTRAINT IF EXISTS unique_vital_reading;

-- Wearable metadata columns (026). `vitals` keeps its core manual-log columns.
ALTER TABLE public.vitals
    DROP COLUMN IF EXISTS source,
    DROP COLUMN IF EXISTS platform,
    DROP COLUMN IF EXISTS device_name,
    DROP COLUMN IF EXISTS device_id,
    DROP COLUMN IF EXISTS synced_at,
    DROP COLUMN IF EXISTS confidence,
    DROP COLUMN IF EXISTS duplicate_hash;

COMMIT;
