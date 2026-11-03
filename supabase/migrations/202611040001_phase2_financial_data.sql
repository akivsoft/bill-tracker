-- Phase 2 expands the initial cloud schema to match the local-first ledger.
-- Keep legacy columns in place so existing installations retain their data.

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 80),
  category_type text not null check (category_type in ('income', 'expense', 'bill', 'loan', 'other')),
  is_default boolean not null default false,
  archived_at timestamptz,
  server_version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, category_type, name),
  unique (user_id, id)
);

alter table public.categories enable row level security;
create policy categories_owner_policy on public.categories
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create trigger categories_set_updated_at
  before update on public.categories
  for each row execute function public.set_updated_at();

alter table public.financial_accounts
  add column if not exists provider text,
  add column if not exists current_balance numeric(19, 2) not null default 0,
  add column if not exists credit_limit numeric(19, 2) not null default 0,
  add column if not exists outstanding_credit_balance numeric(19, 2) not null default 0,
  add column if not exists statement_date date,
  add column if not exists payment_due_date date,
  add column if not exists notes text,
  add column if not exists is_active boolean not null default true;

update public.financial_accounts
set current_balance = opening_balance
where current_balance = 0 and opening_balance <> 0;

alter table public.financial_accounts
  drop constraint if exists financial_accounts_account_type_check;
alter table public.financial_accounts
  add constraint financial_accounts_account_type_check
  check (account_type in ('cash', 'bank', 'debit_card', 'credit_card', 'e_wallet', 'gcash', 'maya', 'savings', 'custom', 'other'));

alter table public.transactions
  add column if not exists source_account_id uuid references public.financial_accounts(id) on delete restrict,
  add column if not exists destination_account_id uuid references public.financial_accounts(id) on delete restrict,
  add column if not exists title text not null default '',
  add column if not exists direction text not null default 'none',
  add column if not exists category_id uuid references public.categories(id) on delete set null,
  add column if not exists category text,
  add column if not exists related_bill_id uuid references public.bills(id) on delete restrict,
  add column if not exists related_loan_id uuid references public.loans(id) on delete restrict,
  add column if not exists related_installment_id uuid references public.loan_installments(id) on delete restrict,
  add column if not exists notes text,
  add column if not exists idempotency_key text;

update public.transactions
set title = coalesce(nullif(title, ''), description, 'Transaction'),
    notes = coalesce(notes, description),
    direction = case
      when transaction_type in ('income', 'transfer_in') then 'inflow'
      when transaction_type in ('expense', 'bill_payment', 'loan_payment', 'credit_card_purchase', 'credit_card_payment', 'transfer_out') then 'outflow'
      when transaction_type = 'reversal' then 'reversal'
      when transaction_type = 'account_transfer' then 'transfer'
      else direction
    end,
    source_account_id = case
      when transaction_type in ('expense', 'transfer_out', 'loan_payment', 'bill_payment', 'credit_card_purchase', 'credit_card_payment') then account_id
      else source_account_id
    end,
    destination_account_id = case
      when transaction_type in ('income', 'transfer_in') then account_id
      else destination_account_id
    end,
    related_bill_id = case
      when related_record_type = 'bill' then coalesce(related_bill_id, related_record_id)
      else related_bill_id
    end,
    related_loan_id = case
      when related_record_type = 'loan' then coalesce(related_loan_id, related_record_id)
      else related_loan_id
    end;

alter table public.transactions
  drop constraint if exists transactions_transaction_type_check;
alter table public.transactions
  add constraint transactions_transaction_type_check
  check (transaction_type in (
    'income', 'expense', 'bill_payment', 'loan_payment',
    'credit_card_purchase', 'credit_card_payment', 'account_transfer',
    'savings_contribution', 'balance_adjustment', 'reversal',
    'transfer_in', 'transfer_out', 'adjustment'
  ));
alter table public.transactions
  add constraint transactions_direction_check
  check (direction in ('none', 'inflow', 'outflow', 'transfer', 'reversal'));
create unique index if not exists transactions_idempotency_key_idx
  on public.transactions (idempotency_key) where idempotency_key is not null;
create index if not exists transactions_source_date_idx
  on public.transactions (user_id, source_account_id, occurred_at desc)
  where deleted_at is null;

alter table public.income_records
  alter column received_at drop not null,
  add column if not exists source_name text not null default '',
  add column if not exists expected_date date,
  add column if not exists actual_received_at timestamptz,
  add column if not exists frequency text not null default 'one_time',
  add column if not exists receiving_account_id uuid references public.financial_accounts(id) on delete set null,
  add column if not exists status text not null default 'received',
  add column if not exists transaction_id uuid references public.transactions(id) on delete restrict;
update public.income_records
set source_name = coalesce(nullif(source_name, ''), 'Income'),
    expected_date = coalesce(expected_date, received_at::date),
    actual_received_at = coalesce(actual_received_at, received_at),
    receiving_account_id = coalesce(receiving_account_id, account_id);
alter table public.income_records
  add constraint income_records_status_check
  check (status in ('expected', 'received', 'cancelled', 'reversed'));
create unique index if not exists income_records_transaction_idx
  on public.income_records (transaction_id) where transaction_id is not null;
create index if not exists income_records_expected_date_idx
  on public.income_records (user_id, expected_date, status) where deleted_at is null;

alter table public.expenses
  add column if not exists title text not null default '',
  add column if not exists financial_category_id uuid references public.categories(id) on delete set null,
  add column if not exists recurrence_configuration jsonb,
  add column if not exists attachment_reference text,
  add column if not exists status text not null default 'confirmed',
  add column if not exists transaction_id uuid references public.transactions(id) on delete restrict;
update public.expenses set title = coalesce(nullif(title, ''), notes, 'Expense');
alter table public.expenses
  add constraint expenses_status_check
  check (status in ('planned', 'confirmed', 'reversed', 'cancelled'));
create unique index if not exists expenses_transaction_idx
  on public.expenses (transaction_id) where transaction_id is not null;

alter table public.bills
  add column if not exists financial_category_id uuid references public.categories(id) on delete set null,
  add column if not exists reminder_configuration jsonb,
  add column if not exists automatic_allocation boolean not null default false,
  add column if not exists is_active boolean not null default true,
  add column if not exists notes text;

alter table public.bill_payments
  add column if not exists occurrence_key text not null default '',
  add column if not exists idempotency_key text,
  add column if not exists reversed_at timestamptz;
create unique index if not exists bill_payments_idempotency_key_idx
  on public.bill_payments (idempotency_key) where idempotency_key is not null;
create index if not exists bill_payments_occurrence_idx
  on public.bill_payments (bill_id, occurrence_key);

alter table public.loans
  add column if not exists remaining_balance numeric(19, 2) not null default 0,
  add column if not exists interest_rate_basis_points integer not null default 0,
  add column if not exists total_interest numeric(19, 2) not null default 0,
  add column if not exists end_date date,
  add column if not exists duration_months integer,
  add column if not exists payment_frequency text not null default 'monthly',
  add column if not exists installment_amount numeric(19, 2) not null default 0,
  add column if not exists total_installments integer not null default 0,
  add column if not exists paid_installments integer not null default 0,
  add column if not exists next_due_date date,
  add column if not exists payment_account_id uuid references public.financial_accounts(id) on delete set null,
  add column if not exists status text not null default 'active',
  add column if not exists notes text;
update public.loans set remaining_balance = principal_amount where remaining_balance = 0;
alter table public.loans
  add constraint loans_status_check
  check (status in ('active', 'paid', 'cancelled', 'archived'));

alter table public.loan_installments
  add column if not exists payment_account_id uuid references public.financial_accounts(id) on delete set null,
  add column if not exists transaction_id uuid references public.transactions(id) on delete restrict,
  add column if not exists notes text;

alter table public.loan_payments
  add column if not exists idempotency_key text,
  add column if not exists status text not null default 'confirmed';
alter table public.loan_payments
  add constraint loan_payments_status_check
  check (status in ('confirmed', 'reversed'));
create unique index if not exists loan_payments_idempotency_key_idx
  on public.loan_payments (idempotency_key) where idempotency_key is not null;

alter table public.savings_goals
  add column if not exists current_amount numeric(19, 2) not null default 0,
  add column if not exists contribution_schedule text,
  add column if not exists notes text;

alter table public.savings_contributions
  add column if not exists idempotency_key text;
create unique index if not exists savings_contributions_idempotency_key_idx
  on public.savings_contributions (idempotency_key)
  where idempotency_key is not null;

alter table public.account_transfers
  add column if not exists transaction_id uuid references public.transactions(id) on delete restrict,
  add column if not exists idempotency_key text,
  add column if not exists reversed_at timestamptz;
create unique index if not exists account_transfers_idempotency_key_idx
  on public.account_transfers (idempotency_key)
  where idempotency_key is not null;

alter table public.payday_schedules
  add column if not exists payday_date date,
  add column if not exists actual_income numeric(19, 2) not null default 0,
  add column if not exists status text not null default 'planned',
  add column if not exists notes text;
update public.payday_schedules set payday_date = next_payday where payday_date is null;
alter table public.payday_schedules alter column payday_date set not null;
alter table public.payday_schedules
  add constraint payday_schedules_status_check
  check (status in ('planned', 'received', 'cancelled'));

alter table public.financial_allocations
  add column if not exists expected_income numeric(19, 2) not null default 0,
  add column if not exists actual_income numeric(19, 2) not null default 0,
  add column if not exists allocation_category text not null default 'other',
  add column if not exists related_bill_id uuid references public.bills(id) on delete restrict,
  add column if not exists related_installment_id uuid references public.loan_installments(id) on delete restrict,
  add column if not exists allocation_key text,
  add column if not exists status text not null default 'planned',
  add column if not exists notes text;
update public.financial_allocations
set allocation_key = coalesce(allocation_key, 'legacy:' || id::text);
alter table public.financial_allocations alter column allocation_key set not null;
alter table public.financial_allocations
  add constraint financial_allocations_status_check
  check (status in ('planned', 'allocated', 'cancelled'));
create unique index if not exists financial_allocations_allocation_key_idx
  on public.financial_allocations (user_id, allocation_key);
create index if not exists financial_allocations_payday_category_idx
  on public.financial_allocations (payday_schedule_id, allocation_category);

create index if not exists financial_accounts_user_active_idx
  on public.financial_accounts (user_id, is_active) where archived_at is null;
create index if not exists bills_user_active_due_idx
  on public.bills (user_id, is_active, due_date) where archived_at is null;
create index if not exists loans_provider_status_idx
  on public.loans (provider_id, status) where archived_at is null;
create index if not exists payday_schedules_date_idx
  on public.payday_schedules (user_id, payday_date) where archived_at is null;
create index if not exists categories_user_type_name_idx
  on public.categories (user_id, category_type, name) where archived_at is null;

alter table public.sync_queue
  drop constraint if exists sync_queue_operation_check;
alter table public.sync_queue
  add constraint sync_queue_operation_check
  check (operation in ('insert', 'update', 'upsert', 'delete'));
