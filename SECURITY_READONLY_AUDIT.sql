-- Read-only security inventory. Run in Supabase SQL Editor.
-- No changes are made.
SELECT c.relname AS table_name,c.relrowsecurity AS rls_enabled,c.relforcerowsecurity AS rls_forced
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relkind='r' ORDER BY c.relname;
SELECT tablename,policyname,cmd,roles,qual,with_check FROM pg_policies
WHERE schemaname='public' ORDER BY tablename,policyname;
SELECT routine_name,security_type FROM information_schema.routines
WHERE routine_schema='public' ORDER BY routine_name;
