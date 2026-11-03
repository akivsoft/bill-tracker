# Architecture

## Layers

- **App:** Material 3 themes, centralized go_router configuration, five stateful navigation branches, and compile-time environment config.
- **Core:** reusable widgets, validators, and `Money`, which parses and formats integer minor units without using floating-point arithmetic for calculations.
- **Domain:** transaction financial values, command inputs, repository contract, and `FinancialCalculator` rules.
- **Data/local:** Drift schema version 3, `LocalFinancialDataSource`, and SQLite transactions that persist ledger changes and their sync queue entries atomically. A local preferences repository persists onboarding/setup state and presentation preferences.
- **Data/repositories:** `LocalFinancialRepository` implements the domain contract and keeps database queries out of screens.
- **Data/remote:** optional Supabase client and version-checked write contract. No banking API is used.
- **Data/sync:** retry metadata and conflict resolution that requires review when local and remote copies both changed.
- **Features:** separate presentation boundaries for authentication, dashboard, wallets, income, expenses, transactions, bills, loans, planner, calendar, savings, reports, notifications, and settings.

## Authentication and startup

The router watches persisted onboarding/setup progress and authentication state. First launch goes through onboarding and financial setup; later launches resume at the appropriate screen. An unavailable Supabase configuration offers local-only mode. Supabase Auth supports email sign-in, registration, password recovery, and sign-out. Authentication does not synchronize, upload, or merge local financial records.

User preferences use the local Drift database so theme mode, display name, currency, date format, first day of week, income cadence, language, and setup progress survive restarts. These are application settings, not credentials. Supabase sessions remain managed by `supabase_flutter`.

## Navigation and summaries

The five primary destinations live in a stateful router shell so each tab retains its navigation state. Dashboard, bills, wallet, and loan overview widgets read the existing repository-backed Riverpod providers. The remaining modules and secondary More destinations are clearly presented as planned screens until their workflows are implemented.

Riverpod provides the database, local data source, and repository. Feature providers can depend on the repository interface; they do not need to know whether a record came from SQLite or a future cloud source.

## Financial operation flow

```text
Feature provider
      │ domain command
      ▼
FinancialRepository
      │
      ▼
LocalFinancialDataSource ── SQLite transaction
      ├── validate ownership, currency, and available funds
      ├── update account / bill / loan / installment / goal
      ├── append immutable transaction or reversal
      └── enqueue records for future sync
```

`FinancialCalculator` contains the reusable integer-only calculations. The Drift source applies them and persists every related change inside one transaction. If a write fails, Drift rolls back the balance changes, history rows, and queue entries together.

## Financial invariants

1. Local balances and amounts use integer minor units; PostgreSQL stores amounts as `NUMERIC(19,2)`.
2. Actual available money excludes credit-card accounts and expected income.
3. A due date or automatic allocation never changes an actual balance.
4. Only confirmed income, expense, bill, loan, savings, transfer, and credit-card operations affect the corresponding actual balances.
5. Transfer principal is neither income nor expense. A transfer fee is an explicit expense.
6. A credit-card payment transfers money from a cash/deposit account to card debt; it is not a second expense.
7. Completed financial transactions are preserved. Reversals append a new transaction and restore the affected balances.
8. Callers reuse idempotency keys when retrying an operation. The database also constrains transaction reversals, payment keys, and allocation keys.
9. Expected values and projected balances stay separate from actual account balances.
10. Same-currency and sufficient-balance checks happen before applying a cash outflow.

## Supabase and offline startup

Supabase initializes only when `SUPABASE_URL` and `SUPABASE_ANON_KEY` Dart defines are supplied. Otherwise the app starts offline. The database migration prepares PostgreSQL NUMERIC columns and RLS for owner-scoped rows. A full version-checked sync worker and amount serializer remain future work; the current local queue does not send cloud writes.

## Code generation

Drift, Riverpod, and JSON generation use `build_runner`. Freezed annotations are available, while its generator remains deferred because of analyzer compatibility in the resolved package graph.
