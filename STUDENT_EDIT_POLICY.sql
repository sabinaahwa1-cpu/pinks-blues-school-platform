-- Pinks & Blues: allow authorized school administrators to edit students.
-- This does not change any existing student data.
DROP POLICY IF EXISTS "pb_students_update_school_admin" ON public.students;
CREATE POLICY "pb_students_update_school_admin"
ON public.students FOR UPDATE TO authenticated
USING (
 EXISTS (
  SELECT 1 FROM public.profiles p
  WHERE p.user_id = (SELECT auth.uid())
    AND p.school_id = students.school_id
    AND lower(trim(p.role)) IN
      ('platform_owner','platform owner','school administrator','administrator')
 )
)
WITH CHECK (
 EXISTS (
  SELECT 1 FROM public.profiles p
  WHERE p.user_id = (SELECT auth.uid())
    AND p.school_id = students.school_id
    AND lower(trim(p.role)) IN
      ('platform_owner','platform owner','school administrator','administrator')
 )
);
