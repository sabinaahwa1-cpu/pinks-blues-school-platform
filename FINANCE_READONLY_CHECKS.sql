-- Read-only finance verification checks. Run after FINANCIAL_CONTROLS_V2.sql.
-- Each row is a finding to review; zero rows means no finding in that check.
SELECT 'overpaid_bill' AS check_name, b.bill_id::text AS record_id,
 (b.amount-b.discount-COALESCE((SELECT sum(p.amount) FROM public.pbis_fee_payments p WHERE p.bill_id=b.bill_id AND p.voided_at IS NULL),0)-COALESCE((SELECT sum(a.amount) FROM public.pbis_advance_allocations a WHERE a.bill_id=b.bill_id),0))::text AS details
FROM public.pbis_fee_bills b WHERE b.voided_at IS NULL
AND b.amount-b.discount-COALESCE((SELECT sum(p.amount) FROM public.pbis_fee_payments p WHERE p.bill_id=b.bill_id AND p.voided_at IS NULL),0)-COALESCE((SELECT sum(a.amount) FROM public.pbis_advance_allocations a WHERE a.bill_id=b.bill_id),0)<0
UNION ALL
SELECT 'invalid_month_allocation',a.allocation_id::text,'advance and bill fee months differ'
FROM public.pbis_advance_allocations a
JOIN public.pbis_fee_advances v ON v.advance_id=a.advance_id
JOIN public.pbis_fee_bills b ON b.bill_id=a.bill_id
WHERE v.fee_month IS DISTINCT FROM b.fee_month OR v.student_id<>b.student_id OR v.school_id<>b.school_id
UNION ALL
SELECT 'overallocated_advance',v.advance_id::text,'allocations exceed advance'
FROM public.pbis_fee_advances v
WHERE (SELECT COALESCE(sum(a.amount),0) FROM public.pbis_advance_allocations a WHERE a.advance_id=v.advance_id)>v.amount
UNION ALL
SELECT 'payment_month_mismatch',p.payment_id::text,'payment month differs from billed month'
FROM public.pbis_fee_payments p JOIN public.pbis_fee_bills b ON b.bill_id=p.bill_id
WHERE p.voided_at IS NULL AND b.fee_month IS NOT NULL AND p.fee_month IS DISTINCT FROM b.fee_month
UNION ALL
SELECT 'duplicate_monthly_bill',min(b.bill_id::text),'same student, term, month and description billed multiple times'
FROM public.pbis_fee_bills b WHERE b.voided_at IS NULL AND b.fee_month IS NOT NULL
GROUP BY b.school_id,b.student_id,b.academic_year,b.term,b.fee_month,b.description HAVING count(*)>1;
