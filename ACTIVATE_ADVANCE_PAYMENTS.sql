-- Pinks & Blues advance-payment activation. Run once in Supabase SQL Editor.
-- Credits are matched ONLY to bills for the same student, school and fee month.
BEGIN;
ALTER TABLE public.pbis_fee_bills ADD COLUMN IF NOT EXISTS fee_month date;
CREATE TABLE IF NOT EXISTS public.pbis_fee_advances (
 advance_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 school_id uuid NOT NULL REFERENCES public.schools(school_id),
 student_id uuid NOT NULL REFERENCES public.students(student_id),
 fee_month date NOT NULL CHECK (extract(day from fee_month)=1),
 amount numeric(12,2) NOT NULL CHECK(amount>0),
 paid_on date NOT NULL,
 received_by_name text NOT NULL CHECK(length(trim(received_by_name))>0),
 received_by_user_id uuid NOT NULL REFERENCES auth.users(id),
 method text NOT NULL CHECK(method IN ('cash','mobile_money','bank_transfer','other')),
 reference text,
 receipt_number bigint GENERATED ALWAYS AS IDENTITY UNIQUE,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.pbis_advance_allocations (
 allocation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 advance_id uuid NOT NULL REFERENCES public.pbis_fee_advances(advance_id),
 bill_id uuid NOT NULL REFERENCES public.pbis_fee_bills(bill_id),
 amount numeric(12,2) NOT NULL CHECK(amount>0),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(advance_id,bill_id)
);
ALTER TABLE public.pbis_fee_advances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pbis_advance_allocations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pbis_advances_read ON public.pbis_fee_advances;
CREATE POLICY pbis_advances_read ON public.pbis_fee_advances FOR SELECT TO authenticated USING (
 EXISTS(SELECT 1 FROM public.profiles p WHERE p.user_id=auth.uid() AND p.school_id=pbis_fee_advances.school_id AND p.status='active' AND p.role IN ('platform_owner','school_admin','admin'))
);
DROP POLICY IF EXISTS pbis_advances_add ON public.pbis_fee_advances;
CREATE POLICY pbis_advances_add ON public.pbis_fee_advances FOR INSERT TO authenticated WITH CHECK (
 received_by_user_id=auth.uid()
 AND EXISTS(SELECT 1 FROM public.profiles p WHERE p.user_id=auth.uid() AND p.school_id=pbis_fee_advances.school_id AND p.status='active' AND p.role IN ('platform_owner','school_admin','admin'))
 AND EXISTS(SELECT 1 FROM public.students s WHERE s.student_id=pbis_fee_advances.student_id AND s.school_id=pbis_fee_advances.school_id)
);
DROP POLICY IF EXISTS pbis_allocations_read ON public.pbis_advance_allocations;
CREATE POLICY pbis_allocations_read ON public.pbis_advance_allocations FOR SELECT TO authenticated USING (
 EXISTS(SELECT 1 FROM public.pbis_fee_advances a JOIN public.profiles p ON p.school_id=a.school_id WHERE a.advance_id=pbis_advance_allocations.advance_id AND p.user_id=auth.uid() AND p.status='active' AND p.role IN ('platform_owner','school_admin','admin'))
);
CREATE OR REPLACE FUNCTION public.pbis_apply_monthly_credit(p_student uuid,p_school uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE b record; a record; remaining numeric; available numeric; portion numeric;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(p_school::text||p_student::text,0));
 FOR b IN SELECT * FROM public.pbis_fee_bills WHERE school_id=p_school AND student_id=p_student AND fee_month IS NOT NULL ORDER BY created_at,bill_id LOOP
  remaining:=b.amount-b.discount
   -COALESCE((SELECT sum(p.amount) FROM public.pbis_fee_payments p WHERE p.bill_id=b.bill_id),0)
   -COALESCE((SELECT sum(z.amount) FROM public.pbis_advance_allocations z WHERE z.bill_id=b.bill_id),0);
  IF remaining<=0 THEN CONTINUE; END IF;
  FOR a IN SELECT * FROM public.pbis_fee_advances WHERE school_id=p_school AND student_id=p_student AND fee_month=b.fee_month ORDER BY paid_on,created_at,advance_id LOOP
   available:=a.amount-COALESCE((SELECT sum(z.amount) FROM public.pbis_advance_allocations z WHERE z.advance_id=a.advance_id),0);
   IF available<=0 THEN CONTINUE; END IF;
   portion:=least(remaining,available);
   INSERT INTO public.pbis_advance_allocations(advance_id,bill_id,amount)
    VALUES(a.advance_id,b.bill_id,portion)
    ON CONFLICT(advance_id,bill_id) DO UPDATE SET amount=public.pbis_advance_allocations.amount+EXCLUDED.amount;
   remaining:=remaining-portion;
   EXIT WHEN remaining<=0;
  END LOOP;
 END LOOP;
END $$;
REVOKE ALL ON FUNCTION public.pbis_apply_monthly_credit(uuid,uuid) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.pbis_credit_on_advance() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN PERFORM public.pbis_apply_monthly_credit(NEW.student_id,NEW.school_id); RETURN NEW; END $$;
CREATE OR REPLACE FUNCTION public.pbis_credit_on_bill() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN PERFORM public.pbis_apply_monthly_credit(NEW.student_id,NEW.school_id); RETURN NEW; END $$;
DROP TRIGGER IF EXISTS pbis_credit_after_advance ON public.pbis_fee_advances;
CREATE TRIGGER pbis_credit_after_advance AFTER INSERT ON public.pbis_fee_advances FOR EACH ROW EXECUTE FUNCTION public.pbis_credit_on_advance();
DROP TRIGGER IF EXISTS pbis_credit_after_bill ON public.pbis_fee_bills;
CREATE TRIGGER pbis_credit_after_bill AFTER INSERT ON public.pbis_fee_bills FOR EACH ROW EXECUTE FUNCTION public.pbis_credit_on_bill();
COMMIT;
