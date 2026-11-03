# Changelog

## 1.0.0+1 — Foundation

- Created a new Android/iOS Flutter project for MyFinance.
- Added Material 3 themes and five-item stateful navigation.
- Added placeholder routes for the financial modules.
- Prepared Riverpod, go_router, Supabase, Drift/SQLite, sync contracts, and PostgreSQL migrations.
- Added offline-safe startup, PHP defaults, integer-minor-unit money utilities, and documentation.

## Phase 2 — Core financial data layer

- Upgraded Drift from schema v1 to v2 with a data-preserving migration and financial tables for accounts, transactions, income, expenses, bills, loans/installments/payments, savings, categories, transfers, paydays, allocations, and sync queue records.
- Added domain calculation services, a repository contract and local implementation, and Riverpod repository/data-source providers.
- Added atomic local operations for income/expense confirmation, bill and loan payments, transfers, credit-card activity, savings contributions, balance reconciliation, and transaction reversals.
- Added idempotency and unique constraints to prevent retry-driven duplicate payments and duplicate payday allocations.
- Added a Supabase upgrade migration for the expanded NUMERIC/RLS schema and unit tests for calculations, operations, reversals, and v1 data preservation.

## Phase 3 — Authentication, onboarding, and app navigation

- Added optional Supabase email sign-in, registration, password recovery, session handling, sign-out, and a clear local-only entry path. Financial data is not uploaded or merged when signing in.
- Added three-screen onboarding and a four-step financial setup flow with skip paths and locally persisted progress/preferences.
- Added startup route guards, password callback routes, deep-link configuration, and a persistent five-tab navigation shell.
- Replaced the main dashboard, bills, wallets, and loans placeholders with summaries driven by the local financial repository; added More menu destinations and settings controls.
- Added saved light/dark/system theme mode, profile display name, currency/date/week preferences, and a Drift v3 migration for app preferences.
- Added auth, preferences, startup-routing, migration, and navigation widget tests.
