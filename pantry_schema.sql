-- Lightweight Pantry / Food Value tables for AlikasWorld.
-- variable_spending remains the financial source of truth and is not modified here.

create extension if not exists pgcrypto;

create table if not exists public.pantry_purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  spending_transaction_id text,
  merchant text,
  purchase_date date not null default current_date,
  created_at timestamptz not null default now(),
  unique (id, user_id)
);

create table if not exists public.pantry_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  purchase_id uuid not null,
  name text not null check (length(trim(name)) > 0),
  price numeric(12,2) check (price is null or price >= 0),
  quantity_description text,
  category text,
  status text not null default 'Unused' check (status in ('Unused', 'Open', 'Finished', 'Wasted')),
  notes text,
  waste_fraction numeric(6,5) check (waste_fraction is null or (waste_fraction >= 0 and waste_fraction <= 1)),
  waste_value numeric(12,2) check (waste_value is null or waste_value >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (purchase_id, user_id) references public.pantry_purchases(id, user_id) on delete cascade,
  unique (id, user_id)
);

create table if not exists public.pantry_meals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  meal_date date not null default current_date,
  portions integer not null check (portions > 0),
  notes text,
  created_at timestamptz not null default now(),
  unique (id, user_id)
);

create table if not exists public.pantry_meal_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  meal_id uuid not null,
  pantry_item_id uuid not null,
  created_at timestamptz not null default now(),
  unique (meal_id, pantry_item_id),
  foreign key (meal_id, user_id) references public.pantry_meals(id, user_id) on delete cascade,
  foreign key (pantry_item_id, user_id) references public.pantry_items(id, user_id) on delete cascade
);

create index if not exists pantry_purchases_user_date_idx on public.pantry_purchases(user_id, purchase_date desc);
create index if not exists pantry_purchases_spend_idx on public.pantry_purchases(user_id, spending_transaction_id);
create index if not exists pantry_items_purchase_idx on public.pantry_items(purchase_id);
create index if not exists pantry_items_user_status_idx on public.pantry_items(user_id, status);
create index if not exists pantry_meals_user_date_idx on public.pantry_meals(user_id, meal_date desc);
create index if not exists pantry_meal_items_meal_idx on public.pantry_meal_items(meal_id);
create index if not exists pantry_meal_items_item_idx on public.pantry_meal_items(pantry_item_id);

alter table public.pantry_purchases enable row level security;
alter table public.pantry_items enable row level security;
alter table public.pantry_meals enable row level security;
alter table public.pantry_meal_items enable row level security;

drop policy if exists "Users manage own pantry purchases" on public.pantry_purchases;
create policy "Users manage own pantry purchases" on public.pantry_purchases
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users manage own pantry items" on public.pantry_items;
create policy "Users manage own pantry items" on public.pantry_items
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users manage own pantry meals" on public.pantry_meals;
create policy "Users manage own pantry meals" on public.pantry_meals
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users manage own pantry meal links" on public.pantry_meal_items;
create policy "Users manage own pantry meal links" on public.pantry_meal_items
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
