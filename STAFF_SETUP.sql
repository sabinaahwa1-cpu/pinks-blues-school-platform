-- Pinks & Blues staff management database
CREATE TABLE IF NOT EXISTS public.pbis_staff (
 staff_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 school_id uuid NOT NULL REFERENCES public.schools(school_id),
 staff_number text,
 full_name text NOT NULL,
 position text NOT NULL,
 assigned_class_id uuid REFERENCES public.pbis_class_directory(class_id),
 phone text,
 email text,
 employment_status text NOT NULL DEFAULT 'active'
   CHECK (employment_status IN ('active','on_leave','inactive','resigned')),
 date_joined date,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (school_id,staff_number)
);
CREATE INDEX IF NOT EXISTS pbis_staff_school_idx ON public.pbis_staff(school_id);
ALTER TABLE public.pbis_staff ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pbis_staff_read_admin ON public.pbis_staff;
DROP POLICY IF EXISTS pbis_staff_insert_admin ON public.pbis_staff;
DROP POLICY IF EXISTS pbis_staff_update_admin ON public.pbis_staff;
CREATE POLICY pbis_staff_read_admin ON public.pbis_staff FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id=(SELECT auth.uid()) AND p.school_id=pbis_staff.school_id AND lower(trim(p.role)) IN ('platform_owner','platform owner','school administrator','administrator')));
CREATE POLICY pbis_staff_insert_admin ON public.pbis_staff FOR INSERT TO authenticated
WITH CHECK (
 EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id=(SELECT auth.uid()) AND p.school_id=pbis_staff.school_id AND lower(trim(p.role)) IN ('platform_owner','platform owner','school administrator','administrator'))
 AND (assigned_class_id IS NULL OR EXISTS (SELECT 1 FROM public.pbis_class_directory c WHERE c.class_id=assigned_class_id AND c.school_id=pbis_staff.school_id))
);
CREATE POLICY pbis_staff_update_admin ON public.pbis_staff FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id=(SELECT auth.uid()) AND p.school_id=pbis_staff.school_id AND lower(trim(p.role)) IN ('platform_owner','platform owner','school administrator','administrator')))
WITH CHECK (
 EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id=(SELECT auth.uid()) AND p.school_id=pbis_staff.school_id AND lower(trim(p.role)) IN ('platform_owner','platform owner','school administrator','administrator'))
 AND (assigned_class_id IS NULL OR EXISTS (SELECT 1 FROM public.pbis_class_directory c WHERE c.class_id=assigned_class_id AND c.school_id=pbis_staff.school_id))
);
