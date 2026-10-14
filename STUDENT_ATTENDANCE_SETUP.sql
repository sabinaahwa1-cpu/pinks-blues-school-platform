-- Pinks & Blues student attendance database
-- Run once in the Supabase SQL Editor. Existing students are preserved.
CREATE TABLE IF NOT EXISTS public.pbis_student_attendance (
  attendance_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(school_id),
  student_id uuid NOT NULL REFERENCES public.students(student_id),
  attendance_date date NOT NULL,
  attendance_status text NOT NULL
    CHECK (attendance_status IN ('present','absent','late','excused')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (school_id, student_id, attendance_date)
);
CREATE INDEX IF NOT EXISTS pbis_student_attendance_school_date_idx
 ON public.pbis_student_attendance(school_id, attendance_date);
ALTER TABLE public.pbis_student_attendance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pbis_student_attendance_read ON public.pbis_student_attendance;
CREATE POLICY pbis_student_attendance_read ON public.pbis_student_attendance
FOR SELECT TO authenticated
USING (EXISTS (
 SELECT 1 FROM public.profiles p
 WHERE p.user_id=(SELECT auth.uid())
 AND p.school_id=pbis_student_attendance.school_id
 AND lower(trim(p.role)) IN ('platform_owner','platform owner','school administrator','administrator')
));

DROP POLICY IF EXISTS pbis_student_attendance_insert ON public.pbis_student_attendance;
CREATE POLICY pbis_student_attendance_insert ON public.pbis_student_attendance
FOR INSERT TO authenticated
WITH CHECK (
 EXISTS (SELECT 1 FROM public.profiles p
 WHERE p.user_id=(SELECT auth.uid())
 AND p.school_id=pbis_student_attendance.school_id
 AND lower(trim(p.role)) IN ('platform_owner','platform owner','school administrator','administrator'))
 AND EXISTS (SELECT 1 FROM public.students s
 WHERE s.student_id=pbis_student_attendance.student_id
 AND s.school_id=pbis_student_attendance.school_id)
);

DROP POLICY IF EXISTS pbis_student_attendance_update ON public.pbis_student_attendance;
CREATE POLICY pbis_student_attendance_update ON public.pbis_student_attendance
FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles p
 WHERE p.user_id=(SELECT auth.uid())
 AND p.school_id=pbis_student_attendance.school_id
 AND lower(trim(p.role)) IN ('platform_owner','platform owner','school administrator','administrator')))
WITH CHECK (
 EXISTS (SELECT 1 FROM public.profiles p
 WHERE p.user_id=(SELECT auth.uid())
 AND p.school_id=pbis_student_attendance.school_id
 AND lower(trim(p.role)) IN ('platform_owner','platform owner','school administrator','administrator'))
 AND EXISTS (SELECT 1 FROM public.students s
 WHERE s.student_id=pbis_student_attendance.student_id
 AND s.school_id=pbis_student_attendance.school_id)
);
