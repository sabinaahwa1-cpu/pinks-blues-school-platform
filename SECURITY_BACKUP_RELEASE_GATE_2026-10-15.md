# Security, backups and access-permission release gate — 15 October 2026

## Release decision: NOT APPROVED FOR REAL STUDENT OR FINANCIAL DATA

This is a verification checklist, not a certificate. The website JavaScript parsed successfully in the code inspection. Database checks and changes were blocked this session by the Supabase connector returning **"You do not have permission to perform this action"**. No database changes or backup restoration were performed in this session.

## Access control — must pass
- [ ] Owner can access authorized school operations only.
- [ ] Admin can access only the assigned school and explicitly delegated modules.
- [ ] Teacher can access only assigned pupils/classes, not fees or management settings.
- [ ] Other staff have minimum permissions.
- [ ] Anonymous users cannot read, insert, modify or delete any personal/financial data.
- [ ] Users from another school cannot read/write records, including by changing IDs in requests.
- [ ] Disabled staff and revoked sessions cannot access data.
- [ ] Staff ID/username sign-in, invitation, password recovery, and rate-limiting tested with real test accounts.
- [ ] Audit SECURITY DEFINER functions and their EXECUTE grants, all public RLS policies and table privileges.

## Backup and restoration — must pass
- [ ] Verify actual Supabase project backup availability and retention under the project's plan.
- [ ] Take a current database backup using an authorized admin process.
- [ ] Restore to an isolated non-production project and verify row counts, relational integrity and receipts.
- [ ] Verify storage files and authentication/user recovery strategy separately; database-only backup is insufficient.
- [ ] Document recovery owner, recovery time target and restore procedure.
- [ ] Confirm backups are not accessible to staff, public users or unauthorized third parties.

## Financial integrity — must pass
- [ ] Test bill creation, advance allocation, payment, void/reversal, receipts, arrears and correction audit trail.
- [ ] Test duplicate submission, concurrent payments, overpayment and cross-school record access.
- [ ] Verify ledger balances after restore.

## Release requirements
No real pupil, family, staff or financial data should be entered until the above checks pass and the proprietor explicitly authorizes go-live. Do not represent syntax checks or a working login page as a penetration test or verified backup.
