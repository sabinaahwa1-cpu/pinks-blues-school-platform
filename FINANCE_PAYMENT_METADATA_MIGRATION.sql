-- Pinks and Blues finance payment metadata migration (run in Supabase SQL Editor).
-- Existing payments remain intact; new entries can record payment date and receiver.
ALTER TABLE public.pbis_fee_payments
  ADD COLUMN IF NOT EXISTS received_by_name text,
  ADD COLUMN IF NOT EXISTS received_by_user_id uuid REFERENCES auth.users(id);
COMMENT ON COLUMN public.pbis_fee_payments.received_by_name IS 'Name of the staff member who physically received the payment.';
COMMENT ON COLUMN public.pbis_fee_payments.received_by_user_id IS 'Authenticated user who recorded the payment; distinct from the physical receiver.';
-- Do not grant UPDATE/DELETE on payments. Audited corrections require a separate controlled workflow.
