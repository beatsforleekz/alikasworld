-- Individual debt activity for AlikasWorld.
-- Existing debt_master cumulative fields remain the balance source used by the app.

create extension if not exists pgcrypto;

create table if not exists public.debt_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  debt_id text not null,
  account_name text not null,
  transaction_type text not null check (transaction_type in ('Spend', 'Payment')),
  amount numeric(12,2) not null check (amount > 0),
  transaction_date date not null default current_date,
  description text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists debt_transactions_user_date_idx
  on public.debt_transactions(user_id, transaction_date desc, created_at desc);
create index if not exists debt_transactions_debt_idx
  on public.debt_transactions(user_id, debt_id, transaction_date desc);

alter table public.debt_transactions enable row level security;

drop policy if exists "Users manage own debt transactions" on public.debt_transactions;
create policy "Users manage own debt transactions" on public.debt_transactions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Keep the existing aggregate columns in sync so every current AlikasWorld
-- calculation continues to use debt_master without double-counting the ledger.
create or replace function public.apply_debt_transaction_to_master()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    update public.debt_master
       set new_spend = greatest(0, coalesce(new_spend, 0) - case when old.transaction_type = 'Spend' then old.amount else 0 end),
           payments_made = greatest(0, coalesce(payments_made, 0) - case when old.transaction_type = 'Payment' then old.amount else 0 end)
     where id::text = old.debt_id
       and user_id = old.user_id;
  end if;

  if tg_op in ('INSERT', 'UPDATE') then
    update public.debt_master
       set new_spend = coalesce(new_spend, 0) + case when new.transaction_type = 'Spend' then new.amount else 0 end,
           payments_made = coalesce(payments_made, 0) + case when new.transaction_type = 'Payment' then new.amount else 0 end,
           status = case when new.transaction_type = 'Spend' and lower(coalesce(status, '')) = 'cleared' then 'Active' else status end
     where id::text = new.debt_id
       and user_id = new.user_id;

    if not found then
      raise exception 'Debt account could not be found for this transaction';
    end if;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists debt_transactions_sync_master on public.debt_transactions;
create trigger debt_transactions_sync_master
after insert or update or delete on public.debt_transactions
for each row execute function public.apply_debt_transaction_to_master();
