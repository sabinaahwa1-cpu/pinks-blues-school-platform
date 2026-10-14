-- Apply once in Supabase SQL Editor before recording fee-month payments.
ALTER TABLE public.pbis_fee_payments ADD COLUMN IF NOT EXISTS fee_month date;
