-- MyFinance initial schema. All amounts are decimal-safe NUMERIC values.
-- Apply with `supabase db push` after linking a project.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  locale text not null default 'en_PH',
  currency_code char(3) not null default 'PHP',
  theme_mode text not null default 'system' check (theme_mode in ('system', 'light', 'dark')),
  biometric_lock_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.financial_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 80),
  account_type text not null check (account_type in ('cash', 'bank', 'debit_card', 'credit_card', 'e_wallet', 'savings', 'other')),
  opening_balance numeric(19, 2) not null default 0,
  currency_code char(3) not null default 'PHP',
  archived_at timestamptz,
  server_version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, id)
);

create table public.income_sources (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 100),
  frequency text not null default 'irregular',
  expected_amount numeric(19, 2) check (expected_amount is null or expected_amount >= 0),
  next_payday date,
  archived_at timestamptz,
  server_version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, id)
);

create table public.income_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  income_source_id uuid references public.income_sources(id) on delete set null,
  account_id uuid references public.financial_accounts(id) on delete set null,
  amount numeric(19, 2) not null check (amount > 0),
  currency_code char(3) not null default 'PHP',
  received_at timestamptz not null,
  notes text,
  deleted_at timestamptz,
  server_version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.expense_categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 60),
  icon_key text,
  archived_at timestamptz,
  server_version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, name),
  unique (user_id, id)
);

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category_id uuid references public.expense_categories(id) on delete set null,
  account_id uuid references public.financial_accounts(id) on delete set null,
  amount numeric(19, 2) not null check (amount > 0),
  currency_code char(3) not null default 'PHP',
  spent_at timestamptz not null,
  notes text,
  attachment_id uuid,
  deleted_at timestamptz,
  server_version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.bill_categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 60),
  icon_key text,
  archived_at timestamptz,
  server_version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, name),
  unique (user_id, id)
);

create table public.bills (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category_id uuid references public.bill_categories(id) on delete set null,
  account_id uuid references public.financial_accounts(id) on delete set null,
  name text not null check (length(trim(name)) between 1 and 100),
  amount numeric(19, 2) not null check (amount > 0),
  currency_code char(3) not null default 'PHP',
  due_date date not null,
  recurrence_rule text,
  status text not null default 'unpaid' check (status in ('unpaid', 'partial', 'paid', 'cancelled')),
  archived_at timestamptz,
  server_version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, id)
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  account_id uuid not null references public.financial_accounts(id) on delete restrict,
  transaction_type text not null check (transaction_type in ('income', 'expense', 'transfer_in', 'transfer_out', 'adjustment', 'reversal')),
  amount numeric(19, 2) not null check (amount > 0),
  currency_code char(3) not null default 'PHP',
  occurred_at timestamptz not null,
  description text,
  related_record_type text,
  related_record_id uuid,
  reversal_of_id uuid references public.transactions(id) on delete restrict,
  deleted_at timestamptz,
  server_version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, id)
);

create unique index transactions_one_reversal_idx
  on public.transactions (reversal_of_id) where reversal_of_id is not null;

create table public.bill_payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  bill_id uuid not null references public.bills(id) on delete restrict,
  account_id uuid not null references public.financial_accounts(id) on delete restrict,
  transaction_id uuid unique references public.transactions(id) on delete restrict,
  amount numeric(19, 2) not null check (amount > 0),
  paid_at timestamptz not null,
  notes text,
  server_version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.loan_providers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 100),
  archived_at timestamptz,
  server_version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, name),
  unique (user_id, id)
);

create table public.loans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider_id uuid references public.loan_providers(id) on delete set null,
  name text not null check (length(trim(name)) between 1 and 100),
  principal_amount numeric(19, 2) not null check (principal_amount > 0),
  currency_code char(3) not null default 'PHP',
  interest_rate_percent numeric(8, 4) check (interest_rate_percent is null or interest_rate_percent >= 0),
  opened_at date not null,
  archived_at timestamptz,
  server_version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, id)
);

create table public.loan_installments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  loan_id uuid not null references public.loans(id) on delete restrict,
  installment_number integer not null check (installment_number > 0),
  due_date date not null,
  principal_component numeric(19, 2) not null default 0 check (principal_component >= 0),
  interest_component numeric(19, 2) not null default 0 check (interest_component >= 0),
  scheduled_amount numeric(19, 2) not null check (scheduled_amount > 0),
  paid_amount numeric(19, 2) not null default 0 check (paid_amount >= 0),
  status text not null default 'unpaid' check (status in ('unpaid', 'partial', 'paid', 'cancelled')),
  paid_at timestamptz,
  server_version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (loan_id, installment_number)
);

create table public.loan_payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  loan_id uuid not null references public.loans(id) on delete restrict,
  installment_id uuid references public.loan_installments(id) on delete set null,
  account_id uuid not null references public.financial_accounts(id) on delete restrict,
  transaction_id uuid unique references public.transactions(id) on delete restrict,
  amount numeric(19, 2) not null check (amount > 0),
  paid_at timestamptz not null,
  notes text,
  server_version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.savings_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 100),
  target_amount numeric(19, 2) not null check (target_amount > 0),
  currency_code char(3) not null default 'PHP',
  target_date date,
  status text not null default 'active' check (status in ('active', 'completed', 'archived')),
  server_version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, id)
);

create table public.savings_contributions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  goal_id uuid not null references public.savings_goals(id) on delete restrict,
  account_id uuid references public.financial_accounts(id) on delete set null,
  transaction_id uuid unique references public.transactions(id) on delete restrict,
  amount numeric(19, 2) not null check (amount > 0),
  contributed_at timestamptz not null,
  server_version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.account_transfers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  from_account_id uuid not null references public.financial_accounts(id) on delete restrict,
  to_account_id uuid not null references public.financial_accounts(id) on delete restrict,
  amount numeric(19, 2) not null check (amount > 0),
  fee_amount numeric(19, 2) not null default 0 check (fee_amount >= 0),
  currency_code char(3) not null default 'PHP',
  transfer_out_transaction_id uuid unique references public.transactions(id) on delete restrict,
  transfer_in_transaction_id uuid unique references public.transactions(id) on delete restrict,
  transferred_at timestamptz not null,
  server_version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (from_account_id <> to_account_id)
);

create table public.payday_schedules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 100),
  frequency text not null,
  next_payday date not null,
  expected_amount numeric(19, 2) check (expected_amount is null or expected_amount >= 0),
  currency_code char(3) not null default 'PHP',
  archived_at timestamptz,
  server_version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, id)
);

create table public.financial_allocations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  payday_schedule_id uuid references public.payday_schedules(id) on delete set null,
  allocation_type text not null,
  target_record_id uuid,
  amount numeric(19, 2) not null check (amount >= 0),
  currency_code char(3) not null default 'PHP',
  sort_order integer not null default 0,
  server_version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  record_type text not null,
  record_id uuid,
  title text not null,
  scheduled_at timestamptz not null,
  delivered_at timestamptz,
  read_at timestamptz,
  cancelled_at timestamptz,
  server_version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.attachments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  owner_type text not null,
  owner_id uuid not null,
  storage_path text not null,
  mime_type text not null,
  byte_length bigint check (byte_length is null or byte_length >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, storage_path)
);

create table public.sync_queue (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  entity_type text not null,
  entity_id uuid not null,
  operation text not null check (operation in ('insert', 'update', 'delete')),
  payload jsonb not null,
  base_server_version bigint,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  next_attempt_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, entity_type, entity_id, operation)
);

create index financial_accounts_user_idx on public.financial_accounts(user_id) where archived_at is null;
create index income_records_user_date_idx on public.income_records(user_id, received_at desc) where deleted_at is null;
create index expenses_user_date_idx on public.expenses(user_id, spent_at desc) where deleted_at is null;
create index bills_user_due_date_idx on public.bills(user_id, due_date) where archived_at is null;
create index transactions_user_account_date_idx on public.transactions(user_id, account_id, occurred_at desc) where deleted_at is null;
create index loan_installments_user_due_date_idx on public.loan_installments(user_id, due_date);
create index savings_contributions_user_goal_date_idx on public.savings_contributions(user_id, goal_id, contributed_at desc);
create index notifications_user_schedule_idx on public.notifications(user_id, scheduled_at) where cancelled_at is null;
create index sync_queue_user_created_idx on public.sync_queue(user_id, created_at);

do $$
declare
  table_name text;
  user_tables text[] := array[
    'profiles', 'user_settings', 'financial_accounts', 'income_sources',
    'income_records', 'expense_categories', 'expenses', 'bill_categories',
    'bills', 'transactions', 'bill_payments', 'loan_providers', 'loans',
    'loan_installments', 'loan_payments', 'savings_goals',
    'savings_contributions', 'account_transfers', 'payday_schedules',
    'financial_allocations', 'notifications', 'attachments', 'sync_queue'
  ];
begin
  foreach table_name in array user_tables loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format(
      'create policy %I on public.%I for all using (user_id = auth.uid()) with check (user_id = auth.uid())',
      table_name || '_owner_policy', table_name
    );
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.set_updated_at()',
      table_name || '_set_updated_at', table_name
    );
  end loop;
end;
$$;

-- A new auth user receives a profile and PHP defaults without any sample finances.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (user_id) values (new.id) on conflict (user_id) do nothing;
  insert into public.user_settings (user_id) values (new.id) on conflict (user_id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
