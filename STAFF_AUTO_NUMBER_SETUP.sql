-- Permanent automatic staff numbers for Pinks & Blues.
-- Existing staff records and existing staff numbers are preserved.
CREATE SEQUENCE IF NOT EXISTS public.pbis_staff_number_seq START 1;

CREATE OR REPLACE FUNCTION public.pbis_assign_staff_number()
RETURNS trigger LANGUAGE plpgsql SET search_path = ''
AS $$
BEGIN
  IF NEW.school_id = '1688afd4-9565-4f3e-8cfb-38cce3f464e3'::uuid THEN
    IF TG_OP = 'INSERT' THEN
      NEW.staff_number := 'PBIS-STF-' ||
        lpad(nextval('public.pbis_staff_number_seq')::text, 4, '0');
    ELSIF TG_OP = 'UPDATE' THEN
      NEW.staff_number := OLD.staff_number;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS pbis_auto_staff_number ON public.pbis_staff;
CREATE TRIGGER pbis_auto_staff_number
BEFORE INSERT OR UPDATE ON public.pbis_staff
FOR EACH ROW EXECUTE FUNCTION public.pbis_assign_staff_number();

-- Assign a number to previously saved staff who have none.
-- Existing manually entered staff numbers remain unchanged.
UPDATE public.pbis_staff
SET staff_number = 'PBIS-STF-' ||
  lpad(nextval('public.pbis_staff_number_seq')::text, 4, '0')
WHERE school_id = '1688afd4-9565-4f3e-8cfb-38cce3f464e3'::uuid
  AND (staff_number IS NULL OR btrim(staff_number) = '');
