-- Pinks & Blues guardian contacts. Run in Supabase SQL Editor.
CREATE TABLE IF NOT EXISTS public.pbis_guardians (
 guardian_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 school_id uuid NOT NULL REFERENCES public.schools(school_id),
 student_id uuid NOT NULL REFERENCES public.students(student_id),
 full_name text NOT NULL,
 relationship text NOT NULL,
 phone text,
 alternate_phone text,
 email text,
 emergency_contact boolean NOT NULL DEFAULT false,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS pbis_guardians_school_student_idx ON public.pbis_guardians(school_id,student_id);
ALTER TABLE public.pbis_guardians ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pbis_guardians_admin_select ON public.pbis_guardians;
DROP POLICY IF EXISTS pbis_guardians_admin_insert ON public.pbis_guardians;
DROP POLICY IF EXISTS pbis_guardians_admin_update ON public.pbis_guardians;
DROP POLICY IF EXISTS pbis_guardians_admin_delete ON public.pbis_guardians;
CREATE POLICY pbis_guardians_admin_select ON public.pbis_guardians FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id=(SELECT auth.uid()) AND p.school_id=pbis_guardians.school_id AND lower(trim(p.role)) IN ('platform_owner','platform owner','school administrator','administrator')));
CREATE POLICY pbis_guardians_admin_insert ON public.pbis_guardians FOR INSERT TO authenticated
WITH CHECK (
 EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id=(SELECT auth.uid()) AND p.school_id=pbis_guardians.school_id AND lower(trim(p.role)) IN ('platform_owner','platform owner','school administrator','administrator'))
 AND EXISTS (SELECT 1 FROM public.students s WHERE s.student_id=pbis_guardians.student_id AND s.school_id=pbis_guardians.school_id)
);
CREATE POLICY pbis_guardians_admin_update ON public.pbis_guardians FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id=(SELECT auth.uid()) AND p.school_id=pbis_guardians.school_id AND lower(trim(p.role)) IN ('platform_owner','platform owner','school administrator','administrator')))
WITH CHECK (
 EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id=(SELECT auth.uid()) AND p.school_id=pbis_guardians.school_id AND lower(trim(p.role)) IN ('platform_owner','platform owner','school administrator','administrator'))
 AND EXISTS (SELECT 1 FROM public.students s WHERE s.student_id=pbis_guardians.student_id AND s.school_id=pbis_guardians.school_id)
);
CREATE POLICY pbis_guardians_admin_delete ON public.pbis_guardians FOR DELETE TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id=(SELECT auth.uid()) AND p.school_id=pbis_guardians.school_id AND lower(trim(p.role)) IN ('platform_owner','platform owner','school administrator','administrator')));
