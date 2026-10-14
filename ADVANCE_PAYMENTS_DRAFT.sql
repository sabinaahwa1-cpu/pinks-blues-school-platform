-- Advance receipts and automatic allocation, version 1.
-- Run only after FINANCE_SETUP.sql. Review and test with fictional records.
CREATE TABLE IF NOT EXISTS public.pbis_fee_advances (
 advance_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 school_id uuid NOT NULL REFERENCES public.schools(school_id),
 student_id uuid NOT NULL REFERENCES public.students(student_id),
 fee_month date NOT NULL,
 amount numeric(12,2) NOT NULL CHECK (amount > 0),
 paid_on date NOT NULL,
 received_by_name text NOT NULL CHECK (length(trim(received_by_name)) > 0),
 received_by_user_id uuid REFERENCES auth.users(id),
 method text NOT NULL CHECK (method IN ('cash','mobile_money','bank_transfer','other')),
 reference text,
 receipt_number bigint GENERATED ALWAYS AS IDENTITY UNIQUE,
 created_at timestamptz NOT NULL DEFAULT now(),
 CHECK (extract(day from fee_month)=1)
);
CREATE TABLE IF NOT EXISTS public.pbis_advance_allocations (
 allocation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 advance_id uuid NOT NULL REFERENCES public.pbis_fee_advances(advance_id),
 bill_id uuid NOT NULL REFERENCES public.pbis_fee_bills(bill_id),
 amount numeric(12,2) NOT NULL CHECK (amount>0),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (advance_id,bill_id)
);
ALTER TABLE public.pbis_fee_advances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pbis_advance_allocations ENABLE ROW LEVEL SECURITY;
CREATE POLICY pbis_advances_read ON public.pbis_fee_advances FOR SELECT TO authenticated USING (
 EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id=auth.uid() AND p.school_id=pbis_fee_advances.school_id AND p.status='active' AND p.role IN ('platform_owner','school_admin','admin'))
);
CREATE POLICY pbis_advances_add ON public.pbis_fee_advances FOR INSERT TO authenticated WITH CHECK (
 EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id=auth.uid() AND p.school_id=pbis_fee_advances.school_id AND p.status='active' AND p.role IN ('platform_owner','school_admin','admin'))
 AND EXISTS (SELECT 1 FROM public.students s WHERE s.student_id=pbis_fee_advances.student_id AND s.school_id=pbis_fee_advances.school_id)
 AND received_by_user_id=auth.uid()
);
CREATE POLICY pbis_allocations_read ON public.pbis_advance_allocations FOR SELECT TO authenticated USING (
 EXISTS (SELECT 1 FROM public.pbis_fee_advances a JOIN public.profiles p ON p.school_id=a.school_id WHERE a.advance_id=pbis_advance_allocations.advance_id AND p.user_id=auth.uid() AND p.status='active' AND p.role IN ('platform_owner','school_admin','admin'))
);
-- Allocation is performed only by the database trigger, not by client writes.
CREATE OR REPLACE FUNCTION public.pbis_allocate_advances(p_student uuid, p_school uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE b record; a record; remaining numeric; available numeric; take_amount numeric;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(p_school::text||':'||p_student::text,0));
 FOR b IN SELECT * FROM public.pbis_fee_bills WHERE student_id=p_student AND school_id=p_school ORDER BY created_at,bill_id LOOP
  remaining := b.amount-b.discount
   - COALESCE((SELECT sum(x.amount) FROM public.pbis_fee_payments x WHERE x.bill_id=b.bill_id),0)
   - COALESCE((SELECT sum(x.amount) FROM public.pbis_advance_allocations x WHERE x.bill_id=b.bill_id),0);
  IF remaining<=0 THEN CONTINUE; END IF;
  FOR a IN SELECT * FROM public.pbis_fee_advances WHERE student_id=p_student AND school_id=p_school ORDER BY paid_on,created_at,advance_id LOOP
   available := a.amount-COALESCE((SELECT sum(x.amount) FROM public.pbis_advance_allocations x WHERE x.advance_id=a.advance_id),0);
   IF available<=0 THEN CONTINUE; END IF;
   take_amount:=least(available,remaining);
   INSERT INTO public.pbis_advance_allocations(advance_id,bill_id,amount) VALUES(a.advance_id,b.bill_id,take_amount)
   ON CONFLICT (advance_id,bill_id) DO UPDATE SET amount=public.pbis_advance_allocations.amount+EXCLUDED.amount;
   remaining:=remaining-take_amount;
   EXIT WHEN remaining<=0;
  END LOOP;
 END LOOP;
END $$;
REVOKE ALL ON FUNCTION public.pbis_allocate_advances(uuid,uuid) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.pbis_advance_insert_trigger() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN PERFORM public.pbis_allocate_advances(NEW.student_id,NEW.school_id); RETURN NEW; END $$;
CREATE OR REPLACE FUNCTION public.pbis_bill_insert_trigger() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN PERFORM public.pbis_allocate_advances(NEW.student_id,NEW.school_id); RETURN NEW; END $$;
DROP TRIGGER IF EXISTS pbis_advance_autocredit ON public.pbis_fee_advances;
CREATE TRIGGER pbis_advance_autocredit AFTER INSERT ON public.pbis_fee_advances FOR EACH ROW EXECUTE FUNCTION public.pbis_advance_insert_trigger();
DROP TRIGGER IF EXISTS pbis_bill_autocredit ON public.pbis_fee_bills;
CREATE TRIGGER pbis_bill_autocredit AFTER INSERT ON public.pbis_fee_bills FOR EACH ROW EXECUTE FUNCTION public.pbis_bill_insert_trigger();
-- NOTE: matching by fee month is not yet enforced in this draft; do not deploy until matching rules are agreed.
