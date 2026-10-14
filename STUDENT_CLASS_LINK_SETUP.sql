-- Run in Supabase SQL Editor before using the class dropdown.
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS pbis_class_id uuid;
ALTER TABLE public.students DROP CONSTRAINT IF EXISTS pbis_students_class_fk;
ALTER TABLE public.students ADD CONSTRAINT pbis_students_class_fk FOREIGN KEY (pbis_class_id) REFERENCES public.pbis_class_directory(class_id);
-- Existing students keep their current data and initially have no class assigned.
