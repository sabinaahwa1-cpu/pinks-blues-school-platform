# Security and role-permission verification — 15 October 2026

Supabase project: lpxelgjrihgwqflzqkpa

## Verified through connected Supabase
- Confirmed one active platform_owner profile; no staff login profiles yet.
- Read all elevated SECURITY DEFINER functions.
- Fixed cross-school finance RLS policies for bill/payment SELECT and INSERT.
- Revoked anonymous finance table access and direct authenticated UPDATE/DELETE on finance ledger.
- Enabled management-only same-school profile directory read.
- Simulated a signed-in unregistered UUID with SET LOCAL ROLE authenticated and JWT claims inside a rolled-back transaction. Profiles, students, bills, payments, and finance audit queries all returned 0 rows.
- Deployed payment guard update to use the same per-student advisory lock as the advance-credit allocator and reject non-positive amounts.
- No real financial records were modified during these checks.

## Still required
- Simulate approved platform owner, teacher, school_admin, and cross-school user policies; only the owner profile currently exists. Use rollback-only test transactions and no actual passwords.
- Audit ALL public table policy expressions and SECURITY DEFINER grants, not just finance.
- Create secure staff invitation / account provisioning through Supabase Auth (never store passwords in GitHub or frontend).
- Check function invocation behavior as an authenticated account; a successful SQL migration is not an end-to-end test.
- Verify current deployed site, including attendance, account directory, and payment reversal.
- Finish browser-local modules and add database-backed access policies and audit logs.

## Security note
Do not publish or enter real pupil or financial data until the remaining authorization and end-to-end tests pass.
