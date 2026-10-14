-- Pinks & Blues staff attendance. Safe to rerun.
CREATE TABLE IF NOT EXISTS public.pbis_staff_attendance (
 attendance_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 school_id uuid NOT NULL REFERENCES public.schools(school_id),
 staff_id uuid NOT NULL REFERENCES public.pbis_staff(staff_id),
 attendance_date date NOT NULL DEFAULT CURRENT_DATE,
 attendance_status text NOT NULL CHECK (attendance_status IN ('present','absent','late','on_leave')),
 notes text,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (school_id,staff_id,attendance_date)
);
CREATE INDEX IF NOT EXISTS pbis_staff_attendance_date_idx
ON public.pbis_staff_attendance(school_id,attendance_date);
ALTER TABLE public.pbis_staff_attendance ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pbis_attendance_select_admin ON public.pbis_staff_attendance;
DROP POLICY IF EXISTS pbis_attendance_insert_admin ON public.pbis_staff_attendance;
DROP POLICY IF EXISTS pbis_attendance_update_admin ON public.pbis_staff_attendance;
CREATE POLICY pbis_attendance_select_admin ON public.pbis_staff_attendance
FOR SELECT TO authenticated USING (
 EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id=(SELECT auth.uid())
 AND p.school_id=pbis_staff_attendance.school_id
 AND lower(trim(p.role)) IN ('platform_owner','platform owner','school administrator','administrator'))
);
CREATE POLICY pbis_attendance_insert_admin ON public.pbis_staff_attendance
FOR INSERT TO authenticated WITH CHECK (
 EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id=(SELECT auth.uid())
 AND p.school_id=pbis_staff_attendance.school_id
 AND lower(trim(p.role)) IN ('platform_owner','platform owner','school administrator','administrator'))
 AND EXISTS (SELECT 1 FROM public.pbis_staff s WHERE s.staff_id=pbis_staff_attendance.staff_id
 AND s.school_id=pbis_staff_attendance.school_id)
);
CREATE POLICY pbis_attendance_update_admin ON public.pbis_staff_attendance
FOR UPDATE TO authenticated USING (
 EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id=(SELECT auth.uid())
 AND p.school_id=pbis_staff_attendance.school_id
 AND lower(trim(p.role)) IN ('platform_owner','platform owner','school administrator','administrator'))
)
WITH CHECK (
 EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id=(SELECT auth.uid())
 AND p.school_id=pbis_staff_attendance.school_id
 AND lower(trim(p.role)) IN ('platform_owner','platform owner','school administrator','administrator'))
 AND EXISTS (SELECT 1 FROM public.pbis_staff s WHERE s.staff_id=pbis_staff_attendance.staff_id
 AND s.school_id=pbis_staff_attendance.school_id)
);
