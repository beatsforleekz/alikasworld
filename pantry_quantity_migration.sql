-- Optional, lightweight Pantry quantity tracking.
-- Existing records remain valid and Spending data is not touched.

alter table public.pantry_items
  add column if not exists quantity_count numeric(12,3),
  add column if not exists quantity_unit text,
  add column if not exists size_description text;

alter table public.pantry_items
  drop constraint if exists pantry_items_quantity_count_check;

alter table public.pantry_items
  add constraint pantry_items_quantity_count_check
  check (quantity_count is null or quantity_count > 0);

alter table public.pantry_meal_items
  add column if not exists quantity_used numeric(12,3),
  add column if not exists quantity_unit text;

alter table public.pantry_meal_items
  drop constraint if exists pantry_meal_items_quantity_used_check;

alter table public.pantry_meal_items
  add constraint pantry_meal_items_quantity_used_check
  check (quantity_used is null or quantity_used > 0);
