# Supabase security setup — Pinks & Blues International School

The website now requires a sign-in and checks the signed-in user's profile. Before the profile check and Students module can work, apply the database policies below.

## Apply once
1. Open the Supabase project for Pinks & Blues International School.
2. Open **SQL Editor** and create a new query.
3. Copy the SQL below, run it, and confirm it completes successfully.
4. Return to the deployed school website and refresh. Sign in with the existing owner email.

This policy set keeps Row Level Security enabled. It allows users to read only their own profile, read their assigned school record, and access student rows only when their profile has an administrator role and the same school_id.

```sql
alter table public.profiles enable row level security;
alter table public.schools enable row level security;
alter table public.students enable row level security;

drop policy if exists "pb_profile_read_own" on public.profiles;
create policy "pb_profile_read_own"
on public.profiles for select to authenticated
using (user_id = (select auth.uid()));

drop policy if exists "pb_school_read_assigned" on public.schools;
create policy "pb_school_read_assigned"
on public.schools for select to authenticated
using (
  id in (
    select p.school_id
    from public.profiles p
    where p.user_id = (select auth.uid())
      and p.school_id is not null
  )
);

drop policy if exists "pb_students_read_school_admin" on public.students;
create policy "pb_students_read_school_admin"
on public.students for select to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.user_id = (select auth.uid())
      and p.school_id = students.school_id
      and lower(trim(p.role)) in ('platform owner','school administrator','administrator')
  )
);

drop policy if exists "pb_students_insert_school_admin" on public.students;
create policy "pb_students_insert_school_admin"
on public.students for insert to authenticated
with check (
  exists (
    select 1 from public.profiles p
    where p.user_id = (select auth.uid())
      and p.school_id = students.school_id
      and lower(trim(p.role)) in ('platform owner','school administrator','administrator')
  )
);

drop policy if exists "pb_students_update_school_admin" on public.students;
create policy "pb_students_update_school_admin"
on public.students for update to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.user_id = (select auth.uid())
      and p.school_id = students.school_id
      and lower(trim(p.role)) in ('platform owner','school administrator','administrator')
  )
)
with check (
  exists (
    select 1 from public.profiles p
    where p.user_id = (select auth.uid())
      and p.school_id = students.school_id
      and lower(trim(p.role)) in ('platform owner','school administrator','administrator')
  )
);

drop policy if exists "pb_students_delete_school_admin" on public.students;
create policy "pb_students_delete_school_admin"
on public.students for delete to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.user_id = (select auth.uid())
      and p.school_id = students.school_id
      and lower(trim(p.role)) in ('platform owner','school administrator','administrator')
  )
);
```

**Important:** This is the first security step for profiles, schools and students only. Other modules are still demo/local and must not be used for real school records yet. If Supabase reports that the `schools.id` column does not exist, stop and report the exact error rather than changing schema guesses.
