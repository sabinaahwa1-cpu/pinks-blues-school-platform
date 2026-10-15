-- FINANCIAL CONTROLS V2. Run in Supabase SQL Editor after backing up.
-- All corrections are audited. Receipt rows are retained.
BEGIN;
ALTER TABLE public.pbis_fee_bills ADD COLUMN IF NOT EXISTS voided_at timestamptz;
ALTER TABLE public.pbis_fee_payments ADD COLUMN IF NOT EXISTS voided_at timestamptz;
ALTER TABLE public.pbis_fee_advances ADD COLUMN IF NOT EXISTS voided_at timestamptz;
CREATE TABLE IF NOT EXISTS public.pbis_finance_corrections (
 correction_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 school_id uuid NOT NULL,
 record_type text NOT NULL CHECK(record_type IN ('bill','payment','advance')),
 record_id uuid NOT NULL,
 action text NOT NULL,
 reason text NOT NULL CHECK(length(trim(reason))>=8),
 before_record jsonb NOT NULL,
 after_record jsonb,
 corrected_by uuid NOT NULL,
 corrected_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.pbis_finance_corrections ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pbis_corrections_read ON public.pbis_finance_corrections;
CREATE POLICY pbis_corrections_read ON public.pbis_finance_corrections FOR SELECT TO authenticated USING (
 EXISTS(SELECT 1 FROM public.profiles p WHERE p.user_id=auth.uid() AND p.school_id=pbis_finance_corrections.school_id AND p.status='active' AND p.role IN ('platform_owner','school_admin','admin'))
);
-- Readonly audit ledger: no client INSERT/UPDATE/DELETE policies.
CREATE OR REPLACE FUNCTION public.pbis_correct_bill(p_bill uuid,p_action text,p_month date,p_reason text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE b public.pbis_fee_bills%ROWTYPE; before_state jsonb;
BEGIN
 SELECT * INTO b FROM public.pbis_fee_bills WHERE bill_id=p_bill FOR UPDATE;
 IF NOT FOUND OR b.voided_at IS NOT NULL THEN RAISE EXCEPTION 'Bill unavailable'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.profiles p WHERE p.user_id=auth.uid() AND p.school_id=b.school_id AND p.status='active' AND p.role IN ('platform_owner','school_admin')) THEN RAISE EXCEPTION 'Management authorization required'; END IF;
 IF length(trim(coalesce(p_reason,'')))<8 THEN RAISE EXCEPTION 'Provide a correction reason of at least eight characters'; END IF;
 IF EXISTS(SELECT 1 FROM public.pbis_fee_payments x WHERE x.bill_id=b.bill_id AND x.voided_at IS NULL) OR EXISTS(SELECT 1 FROM public.pbis_advance_allocations x WHERE x.bill_id=b.bill_id) THEN RAISE EXCEPTION 'Bill has payments or allocations; do not modify it. Escalate for manual reconciliation.'; END IF;
 before_state:=to_jsonb(b);
 IF p_action='void' THEN
  UPDATE public.pbis_fee_bills SET voided_at=now() WHERE bill_id=p_bill;
 ELSIF p_action='change_month' THEN
  IF p_month IS NULL OR extract(day FROM p_month)<>1 THEN RAISE EXCEPTION 'Choose a valid fee month'; END IF;
  IF EXISTS(SELECT 1 FROM public.pbis_fee_bills x WHERE x.school_id=b.school_id AND x.student_id=b.student_id AND x.bill_id<>b.bill_id AND x.voided_at IS NULL AND x.academic_year=b.academic_year AND x.term=b.term AND x.fee_month=p_month AND x.description=b.description) THEN RAISE EXCEPTION 'A bill already exists for that month'; END IF;
  UPDATE public.pbis_fee_bills SET fee_month=p_month WHERE bill_id=p_bill;
  PERFORM public.pbis_apply_monthly_credit(b.student_id,b.school_id);
 ELSE RAISE EXCEPTION 'Unsupported correction'; END IF;
 INSERT INTO public.pbis_finance_corrections(school_id,record_type,record_id,action,reason,before_record,after_record,corrected_by)
 VALUES(b.school_id,'bill',p_bill,p_action,p_reason,before_state,(SELECT to_jsonb(x) FROM public.pbis_fee_bills x WHERE x.bill_id=p_bill),auth.uid());
END $$;
REVOKE ALL ON FUNCTION public.pbis_correct_bill(uuid,text,date,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.pbis_correct_bill(uuid,text,date,text) TO authenticated;
-- Server-side overpayment check (serializes payments for a given bill).
CREATE OR REPLACE FUNCTION public.pbis_guard_payment() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE b public.pbis_fee_bills%ROWTYPE; outstanding numeric;
BEGIN
 SELECT * INTO b FROM public.pbis_fee_bills WHERE bill_id=NEW.bill_id FOR UPDATE;
 IF NOT FOUND OR b.voided_at IS NOT NULL OR NEW.school_id<>b.school_id THEN RAISE EXCEPTION 'Invalid bill'; END IF;
 IF NEW.received_by_user_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Recorder identity mismatch'; END IF;
 IF b.fee_month IS NOT NULL AND NEW.fee_month IS DISTINCT FROM b.fee_month THEN RAISE EXCEPTION 'Payment fee month must match bill'; END IF;
 outstanding:=b.amount-b.discount
 -COALESCE((SELECT sum(x.amount) FROM public.pbis_fee_payments x WHERE x.bill_id=b.bill_id AND x.voided_at IS NULL),0)
 -COALESCE((SELECT sum(z.amount) FROM public.pbis_advance_allocations z WHERE z.bill_id=b.bill_id),0);
 IF NEW.amount>outstanding THEN RAISE EXCEPTION 'Payment exceeds remaining bill balance'; END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS pbis_guard_payment_insert ON public.pbis_fee_payments;
CREATE TRIGGER pbis_guard_payment_insert BEFORE INSERT ON public.pbis_fee_payments FOR EACH ROW EXECUTE FUNCTION public.pbis_guard_payment();
CREATE OR REPLACE FUNCTION public.pbis_guard_advance() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF NEW.received_by_user_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Recorder identity mismatch'; END IF;
 IF NEW.fee_month IS NULL OR extract(day FROM NEW.fee_month)<>1 THEN RAISE EXCEPTION 'Valid fee month required'; END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS pbis_guard_advance_insert ON public.pbis_fee_advances;
CREATE TRIGGER pbis_guard_advance_insert BEFORE INSERT ON public.pbis_fee_advances FOR EACH ROW EXECUTE FUNCTION public.pbis_guard_advance();
-- Harden credit allocator to ignore voided bills/advances, and voided direct payments.
CREATE OR REPLACE FUNCTION public.pbis_apply_monthly_credit(p_student uuid,p_school uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE b record; a record; remaining numeric; available numeric; portion numeric;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(p_school::text||p_student::text,0));
 FOR b IN SELECT * FROM public.pbis_fee_bills WHERE school_id=p_school AND student_id=p_student AND fee_month IS NOT NULL AND voided_at IS NULL ORDER BY created_at,bill_id LOOP
  remaining:=b.amount-b.discount
   -COALESCE((SELECT sum(p.amount) FROM public.pbis_fee_payments p WHERE p.bill_id=b.bill_id AND p.voided_at IS NULL),0)
   -COALESCE((SELECT sum(z.amount) FROM public.pbis_advance_allocations z WHERE z.bill_id=b.bill_id),0);
  IF remaining<=0 THEN CONTINUE; END IF;
  FOR a IN SELECT * FROM public.pbis_fee_advances WHERE school_id=p_school AND student_id=p_student AND fee_month=b.fee_month AND voided_at IS NULL ORDER BY paid_on,created_at,advance_id LOOP
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
COMMIT;
