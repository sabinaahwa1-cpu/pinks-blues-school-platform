-- FINANCE FINAL VERIFICATION (read-only; does not create transactions)
-- Run after FINANCIAL_CONTROLS_V2.sql. No rows means no findings.
SELECT 'missing_receipt_number' AS issue,p.payment_id::text AS record_id FROM public.pbis_fee_payments p WHERE p.voided_at IS NULL AND p.receipt_number IS NULL
UNION ALL
SELECT 'missing_advance_receipt_number',a.advance_id::text FROM public.pbis_fee_advances a WHERE a.voided_at IS NULL AND a.receipt_number IS NULL
UNION ALL
SELECT 'duplicate_direct_receipt_number',min(p.payment_id::text) FROM public.pbis_fee_payments p GROUP BY p.receipt_number HAVING count(*)>1
UNION ALL
SELECT 'duplicate_advance_receipt_number',min(a.advance_id::text) FROM public.pbis_fee_advances a GROUP BY a.receipt_number HAVING count(*)>1
UNION ALL
SELECT 'incorrect_direct_payment_school',p.payment_id::text FROM public.pbis_fee_payments p JOIN public.pbis_fee_bills b ON b.bill_id=p.bill_id WHERE p.school_id<>b.school_id
UNION ALL
SELECT 'incorrect_advance_student_school',a.advance_id::text FROM public.pbis_fee_advances a JOIN public.students s ON s.student_id=a.student_id WHERE a.school_id<>s.school_id
UNION ALL
SELECT 'credit_on_voided_bill',z.allocation_id::text FROM public.pbis_advance_allocations z JOIN public.pbis_fee_bills b ON b.bill_id=z.bill_id WHERE b.voided_at IS NOT NULL;
