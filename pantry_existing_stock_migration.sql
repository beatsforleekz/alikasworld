-- Allow Pantry entries for food already on hand.
-- Existing purchases and all Spending records remain unchanged.

alter table public.pantry_purchases
  add column if not exists is_existing_stock boolean not null default false;

alter table public.pantry_purchases
  alter column purchase_date drop not null;
