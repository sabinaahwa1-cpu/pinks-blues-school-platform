-- Class directory for Pinks and Blues International School.
-- Safe to run again. Does not change existing student records.
CREATE TABLE IF NOT EXISTS public.pbis_class_directory (
 class_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 school_id uuid NOT NULL REFERENCES public.schools(school_id),
 class_name text NOT NULL,
 sort_order integer NOT NULL,
 UNIQUE(school_id,class_name)
);
ALTER TABLE public.pbis_class_directory ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pbis_class_directory_read ON public.pbis_class_directory;
CREATE POLICY pbis_class_directory_read ON public.pbis_class_directory
FOR SELECT TO authenticated USING (
 EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id=(SELECT auth.uid())
 AND p.school_id=pbis_class_directory.school_id
 AND lower(trim(p.role)) IN ('platform_owner','platform owner','school administrator','administrator'))
);
INSERT INTO public.pbis_class_directory(school_id,class_name,sort_order)
SELECT '1688afd4-9565-4f3e-8cfb-38cce3f464e3'::uuid,v.name,v.position
FROM (VALUES
 ('Crèche',1),('Nursery 1',2),('Nursery 2',3),('KG 1',4),('KG 2',5),
 ('Basic 1',6),('Basic 2',7),('Basic 3',8),('Basic 4',9),('Basic 5',10),
 ('Basic 6',11),('JHS 1',12),('JHS 2',13),('JHS 3',14)
) AS v(name,position)
ON CONFLICT (school_id,class_name) DO NOTHING;
