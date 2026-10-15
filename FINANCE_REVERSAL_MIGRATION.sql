-- FINANCE REVERSALS V1: run in Supabase SQL Editor after FINANCIAL_CONTROLS_V2.sql
-- Reverse direct payments only. Advance allocations require separate reconciliation.
BEGIN;
CREATE OR REPLACE FUNCTION public.pbis_reverse_direct_payment(p_payment uuid,p_reason text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE x public.pbis_fee_payments%ROWTYPE; b public.pbis_fee_bills%ROWTYPE;
BEGIN
 SELECT * INTO x FROM public.pbis_fee_payments WHERE payment_id=p_payment FOR UPDATE;
 IF NOT FOUND OR x.voided_at IS NOT NULL THEN RAISE EXCEPTION 'Payment missing or already reversed'; END IF;
 SELECT * INTO b FROM public.pbis_fee_bills WHERE bill_id=x.bill_id FOR UPDATE;
 IF b.bill_id IS NULL OR b.voided_at IS NOT NULL OR b.school_id<>x.school_id THEN RAISE EXCEPTION 'Bill unavailable'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.profiles p WHERE p.user_id=auth.uid() AND p.school_id=x.school_id AND p.status='active' AND p.role IN ('platform_owner','school_admin')) THEN RAISE EXCEPTION 'Management authorization required'; END IF;
 IF length(trim(coalesce(p_reason,'')))<12 THEN RAISE EXCEPTION 'Explain the reversal in at least 12 characters'; END IF;
 UPDATE public.pbis_fee_payments SET voided_at=now() WHERE payment_id=x.payment_id;
 INSERT INTO public.pbis_finance_corrections(school_id,record_type,record_id,action,reason,before_record,after_record,corrected_by)
 VALUES(x.school_id,'payment',x.payment_id,'reverse',trim(p_reason),to_jsonb(x),
 (SELECT to_jsonb(z) FROM public.pbis_fee_payments z WHERE z.payment_id=x.payment_id),auth.uid());
 -- Reapply previously unallocated advance credits against the newly reopened bill balance.
 PERFORM public.pbis_apply_monthly_credit(b.student_id,b.school_id);
END $$;
REVOKE ALL ON FUNCTION public.pbis_reverse_direct_payment(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.pbis_reverse_direct_payment(uuid,text) TO authenticated;
COMMIT;
