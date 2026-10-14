-- Fix for older staff records missing automatic IDs.
-- Existing nonempty staff numbers stay unchanged.
CREATE OR REPLACE FUNCTION public.pbis_assign_staff_number()
RETURNS trigger LANGUAGE plpgsql SET search_path = ''
AS $$
BEGIN
  IF NEW.school_id = '1688afd4-9565-4f3e-8cfb-38cce3f464e3'::uuid THEN
    IF TG_OP = 'INSERT' THEN
      NEW.staff_number := 'PBIS-STF-' ||
        lpad(nextval('public.pbis_staff_number_seq')::text, 4, '0');
    ELSIF TG_OP = 'UPDATE' THEN
      IF OLD.staff_number IS NULL OR btrim(OLD.staff_number) = '' THEN
        NEW.staff_number := 'PBIS-STF-' ||
          lpad(nextval('public.pbis_staff_number_seq')::text, 4, '0');
      ELSE
        NEW.staff_number := OLD.staff_number;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- Trigger already exists; this refreshes records without an ID.
UPDATE public.pbis_staff
SET staff_number = NULL
WHERE school_id = '1688afd4-9565-4f3e-8cfb-38cce3f464e3'::uuid
AND (staff_number IS NULL OR btrim(staff_number) = '');

SELECT staff_number, full_name
FROM public.pbis_staff
WHERE school_id = '1688afd4-9565-4f3e-8cfb-38cce3f464e3'::uuid
ORDER BY created_at DESC;
