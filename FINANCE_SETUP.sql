-- FINANCE SETUP V1: Run once in Supabase SQL Editor
CREATE TABLE IF NOT EXISTS public.pbis_fee_bills (
 bill_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 school_id uuid NOT NULL REFERENCES public.schools(school_id),
 student_id uuid NOT NULL REFERENCES public.students(student_id),
 academic_year text NOT NULL,
 term text NOT NULL,
 description text NOT NULL DEFAULT 'School fees',
 amount numeric(12,2) NOT NULL CHECK (amount >= 0),
 discount numeric(12,2) NOT NULL DEFAULT 0 CHECK (discount >= 0),
 created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT pbis_fee_bills_discount_valid CHECK(discount <= amount)
);
CREATE TABLE IF NOT EXISTS public.pbis_fee_payments (
 payment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 school_id uuid NOT NULL REFERENCES public.schools(school_id),
 bill_id uuid NOT NULL REFERENCES public.pbis_fee_bills(bill_id),
 amount numeric(12,2) NOT NULL CHECK(amount > 0),
 method text NOT NULL CHECK(method IN ('cash','mobile_money','bank_transfer','other')),
 reference text,
 paid_on date NOT NULL DEFAULT current_date,
 receipt_number bigint GENERATED ALWAYS AS IDENTITY UNIQUE,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS pbis_fee_bills_school_student_idx ON public.pbis_fee_bills(school_id,student_id);
CREATE INDEX IF NOT EXISTS pbis_fee_payments_school_bill_idx ON public.pbis_fee_payments(school_id,bill_id);
ALTER TABLE public.pbis_fee_bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pbis_fee_payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pbis_bills_select ON public.pbis_fee_bills;
CREATE POLICY pbis_bills_select ON public.pbis_fee_bills FOR SELECT TO authenticated USING (
 EXISTS(SELECT 1 FROM public.profiles p WHERE p.user_id=(SELECT auth.uid()) AND p.school_id=school_id AND p.status='active' AND p.role IN ('platform_owner','school_admin','admin'))
);
DROP POLICY IF EXISTS pbis_bills_insert ON public.pbis_fee_bills;
CREATE POLICY pbis_bills_insert ON public.pbis_fee_bills FOR INSERT TO authenticated WITH CHECK (
 EXISTS(SELECT 1 FROM public.profiles p WHERE p.user_id=(SELECT auth.uid()) AND p.school_id=school_id AND p.status='active' AND p.role IN ('platform_owner','school_admin','admin'))
 AND EXISTS(SELECT 1 FROM public.students s WHERE s.student_id=pbis_fee_bills.student_id AND s.school_id=pbis_fee_bills.school_id)
);
DROP POLICY IF EXISTS pbis_payments_select ON public.pbis_fee_payments;
CREATE POLICY pbis_payments_select ON public.pbis_fee_payments FOR SELECT TO authenticated USING (
 EXISTS(SELECT 1 FROM public.profiles p WHERE p.user_id=(SELECT auth.uid()) AND p.school_id=school_id AND p.status='active' AND p.role IN ('platform_owner','school_admin','admin'))
);
DROP POLICY IF EXISTS pbis_payments_insert ON public.pbis_fee_payments;
CREATE POLICY pbis_payments_insert ON public.pbis_fee_payments FOR INSERT TO authenticated WITH CHECK (
 EXISTS(SELECT 1 FROM public.profiles p WHERE p.user_id=(SELECT auth.uid()) AND p.school_id=school_id AND p.status='active' AND p.role IN ('platform_owner','school_admin','admin'))
 AND EXISTS(SELECT 1 FROM public.pbis_fee_bills b WHERE b.bill_id=pbis_fee_payments.bill_id AND b.school_id=pbis_fee_payments.school_id)
);
-- Financial entries intentionally immutable: corrections require an audited adjustment workflow.
