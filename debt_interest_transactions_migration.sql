-- Add interest/fee entries to an existing debt transaction installation.

alter table public.debt_transactions
  drop constraint if exists debt_transactions_transaction_type_check;

alter table public.debt_transactions
  add constraint debt_transactions_transaction_type_check
  check (transaction_type in ('Spend', 'Payment', 'Interest'));

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
           payments_made = greatest(0, coalesce(payments_made, 0) - case when old.transaction_type = 'Payment' then old.amount else 0 end),
           interest_charged = greatest(0, coalesce(interest_charged, 0) - case when old.transaction_type = 'Interest' then old.amount else 0 end)
     where id::text = old.debt_id
       and user_id = old.user_id;
  end if;

  if tg_op in ('INSERT', 'UPDATE') then
    update public.debt_master
       set new_spend = coalesce(new_spend, 0) + case when new.transaction_type = 'Spend' then new.amount else 0 end,
           payments_made = coalesce(payments_made, 0) + case when new.transaction_type = 'Payment' then new.amount else 0 end,
           interest_charged = coalesce(interest_charged, 0) + case when new.transaction_type = 'Interest' then new.amount else 0 end,
           status = case when new.transaction_type in ('Spend', 'Interest') and lower(coalesce(status, '')) = 'cleared' then 'Active' else status end
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
