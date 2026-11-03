# Database design

## Local SQLite with Drift

Drift schema version 3 is the local source of truth and remains available without Supabase or network access. Monetary values are stored as integer minor units (centavos for PHP). Tables include:

1. `financial_accounts` — account/provider/type, live balance, credit limit, outstanding card balance, statement and due dates, active/archive state.
2. `transactions` — immutable income, expense, bill/loan payment, credit-card activity, transfers, savings contributions, balance adjustments, and reversals.
3. `income_sources` and `income_records` — expected and received income with the receiving account and linked transaction.
4. `categories` and `expenses` — user-defined income/expense/bill/loan categories and planned or confirmed expenses.
5. `bills` and `bill_payments` — recurrence/reminder settings and per-occurrence partial payment history.
6. `loan_providers`, `loans`, `loan_installments`, and `loan_payments` — multiple loans per provider, individual installment schedules, partial payments, and payment history.
7. `savings_goals` and `savings_contributions` — goal totals and linked contribution history.
8. `account_transfers` — transfer metadata linked to one ledger transaction; transfer fees are recorded as a separate expense transaction.
9. `payday_schedules` and `financial_allocations` — expected/actual income and forecast allocations. A unique allocation key prevents allocating the same obligation twice for a payday.
10. `sync_queue` — coalesced upserts, retry count, and conflict metadata for future synchronization.
11. `app_preferences` — the single local app-preferences record for onboarding/setup progress and display preferences. It contains no authentication credentials.

Primary keys are UUID strings. Relationships use foreign keys, and indexes cover account/date, due date, provider/status, installment number, payment idempotency, and allocation uniqueness. Financial history is not hard-deleted: transactions are reversed, and records that can be retired use `archived_at` or `deleted_at`.

### Migrations

Schema version 2 adds the financial tables and rebuilds version 1 tables through Drift `TableMigration`. It preserves existing rows and carries opening account balances into the current balance, loan principals into remaining balances, and old transaction descriptions into titles. Schema version 3 adds `app_preferences` without changing existing financial rows. `test/unit/database_migration_test.dart` verifies the earlier upgrade and preferences defaults.

Any local schema edit must increment `AppDatabase.schemaVersion`, add an upgrade step, regenerate `app_database.g.dart`, and add a migration test where existing data could be affected.

## Financial integrity rules

- Available money sums active cash, deposit, debit, and e-wallet balances in the selected currency. Credit-card limits and unused credit are excluded.
- Available credit is `credit limit - outstanding balance`.
- Expected income and planned allocations never change actual account balances.
- Creating or reaching the due date of a bill does not deduct money. Confirmed bill payments do.
- Income, expense, bill payment, loan payment, transfer, credit-card purchase/payment, savings contribution, reconciliation, and reversal operations update linked rows in one SQLite transaction.
- Retried commands must reuse the same idempotency key. Unique indexes and entity state prevent duplicate deductions.
- A transfer changes both account balances but is neither income nor expense. Any fee is a separate expense.
- A credit-card purchase increases outstanding credit and is recorded as an expense. A card payment reduces the selected cash account and card outstanding balance without creating a second expense.
- Reversals add a new transaction and preserve the original. Reversing a loan payment also restores the loan and installment amounts.
- Projection is calculated separately: actual available money + expected income - upcoming obligations - planned expenses.

## Supabase PostgreSQL

Apply migrations in order with `supabase db push` after linking a project:

```sh
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

`202611030001_initial_schema.sql` creates the original 23 user-owned tables. `202611040001_phase2_financial_data.sql` adds a generic `categories` table and extends the financial tables, for 24 cloud tables. The cloud uses UUID primary keys, PostgreSQL `NUMERIC(19,2)` for amounts, timestamps, indexes, foreign keys, owner-scoped RLS, and an `updated_at` trigger. The upgrade retains legacy columns and data.

Local monetary values are integer minor units while cloud values are decimal `NUMERIC`. Queue payloads serialize amounts as exact decimal strings for the future Supabase adapter. Cloud writes and the network sync worker are not enabled. Supabase Auth is optional and independent of local financial data.

`seed.sql` is intentionally empty. Never seed real user finances or put a service-role key in the mobile app. Supabase remains optional; missing URL/key means local-only operation.

## Synchronization boundary

Local writes enqueue a record payload in the same SQLite transaction as the financial change. The existing sync contracts compare server versions and surface concurrent edits for review. This phase does not implement the network worker, retry scheduling, storage uploads, or a version-checked PostgreSQL RPC. Do not enable cloud writes until those pieces and private storage policies are in place.
