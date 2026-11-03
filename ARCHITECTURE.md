# Architecture

## Application boundaries

- `app/` owns startup, environment configuration, Material 3 themes, and the go_router navigation shell.
- `features/` holds dashboard, wallets, income, expenses, bills, loans, planner/calendar, savings, transactions, reports, notifications, authentication, and settings.
- `data/local/` contains Drift schema v7, migrations, repositories/data sources, and local backup/restore.
- `data/remote/` contains the optional Supabase client and sync contracts. There is no financial record sync transport.
- Riverpod providers connect screens to repository operations and streams; feature screens do not issue Drift queries directly, except the explicit backup/restore service boundary.

## Financial writes

```text
Screen / provider
       │ typed command
       ▼
FinancialRepository
       │
       ▼
LocalFinancialDataSource ── Drift transaction
       ├── validate balances, currencies, and references
       ├── append transaction/payment and update related records
       ├── update balances using integer minor units
       └── enqueue local sync metadata for a future adapter
```

Account balances, transaction rows, payment records, reversals, and queue updates are committed atomically. Retryable writes use idempotency keys. Transfers are not income or expense; card purchases count as spending while card payments only reduce liability; expected income and planned allocations do not affect actual balances. Reversals append history and restore affected values.

## Authentication, privacy, and offline behavior

Without `SUPABASE_URL` and `SUPABASE_ANON_KEY`, startup remains local-only. When configured, Supabase Auth manages the session; authentication does not upload or merge financial data. Client configuration must only use the anon/publishable key. The migrations apply owner-scoped RLS policies to cloud tables. A service-role key must never ship in the application.

Local reminders use platform notifications and store preferences/history on device. Notification text is generic to avoid exposing bill, lender, account, or goal names on a locked screen. Local backup is a versioned JSON snapshot of Drift tables plus reminder preferences. Restore validates the backup, confirms replacement, and uses a database transaction with foreign-key validation. Backup files themselves are not encrypted.

## Reports and analytics

Dashboard and reports use confirmed ledger transactions, filtering out transfers, reversals, card payments, and other non-expense flows from income/spending totals as appropriate. Reports add category/type/account filters and share PDF, XLSX, and CSV. Report and dashboard totals use the same transaction types and integer minor units. Export files contain financial data selected by the user and do not include authentication credentials.

## Cloud data and sync boundary

PostgreSQL migrations prepare NUMERIC amounts, indexes, update triggers, and RLS. Local Drift has a deduplicating pending queue and the codebase includes a version conflict resolver, but no authenticated financial sync worker, remote RPC implementation, retry loop, or complete schema mapper exists. Therefore cloud synchronization and cloud backup remain disabled. Local changes are retained without a network connection.

## Android release

The Android namespace/application ID is `com.myfinance.billtracker`. Release signing is loaded only from ignored local `android/key.properties`; without it, release builds do not fall back to the debug key. Android notification receivers restore scheduled notifications after boot. Play Console readiness still requires a privately managed upload key and real-device/manual release checks.
