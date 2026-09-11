-- Allow manual corrections to Pantry's calculated remaining quantity.
-- The adjustment works alongside meal usage and does not affect Spending.

alter table public.pantry_items
  add column if not exists quantity_adjustment numeric(12,3) not null default 0;
