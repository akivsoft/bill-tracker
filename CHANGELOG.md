# Changelog

## Phase 11 — Integration, security, and Android release review

- Fixed immediate income and expense transactions to insert the linked ledger transaction before records that reference it, keeping writes atomic and idempotent. Added regression coverage for account balances, transaction links, and duplicate retries.
- Removed verbose Supabase exception/stack logging, removed unused biometric and connectivity plugins (and their Android permissions), and made notification lock-screen content generic.
- Replaced the default Flutter launcher mark with a MyFinance wallet icon. Added local-only release keystore configuration; release builds no longer use the debug signing key. Keystore properties and binaries are excluded from Git.
- Verified RLS owner policies in the checked-in Supabase migrations and reviewed environment configuration for privileged keys. Financial cloud sync remains unavailable and no financial data is uploaded.
- `flutter analyze` reports no issues; all 87 tests pass. `flutter build appbundle --release` succeeds and outputs an unsigned AAB. It is not Play Console upload-ready until signed using a privately managed upload key. Real-device and store signing checks remain manual.

## Phase 10 — Reports, reminders, local backup, and sync readiness

- Replaced the Reports placeholder with date, account, category, and transaction-type filters; confirmed income/expense/net summaries; category spending and account ledger history; and shareable PDF, Excel, and CSV exports with report filters and generation time.
- Added on-device bill, loan installment, credit card, payday, and configured savings reminders with category settings, lead time, preferred time, permission requests, duplicate keys, local reminder history, read state, and Android reboot rescheduling. Reminders only notify; they never record payments.
- Added versioned local JSON backup and validation, explicit replace confirmation, transactional restore with foreign-key checks, original IDs and links, and backup of reminder preferences. Invalid restore rows roll the database transaction back.
- Cloud sync remains disabled: current Supabase integration authenticates users, while there is no configured secure financial sync RPC/API or complete remote schema mapping. Local records remain on device and nothing is uploaded.
- Added unit coverage for report filters and formats, reminder planning/deduplication, and backup validation, replacement, rollback, and relationship preservation.

## Phase 9 — Dashboard and financial analytics

- Replaced the initial dashboard summary with selectable day, week, month, quarter, year, and custom-period analytics, including confirmed income, expenses, net cash flow, prior-period comparisons, trends, and expense category breakdowns.
- Added account balance, outstanding loan and card debt, savings progress, planned payday allocations, upcoming obligations, and next payday summaries with links into their management screens. Forecast values remain separate from confirmed cash flow.
- Added bounded recent activity and date/currency-filtered transaction streams for dashboard performance; dashboard refresh invalidates the relevant financial providers.
- Added analytics calculation coverage for comparisons, categorization, excluded transaction types, currency separation, reversals, and empty data.

## Phase 8 — Payday planner and financial calendar

- Added recurring payday schedule management for daily, weekly, biweekly, twice-monthly, monthly, quarterly, yearly, and irregular income. Schedules can be edited, paused/resumed, archived, and linked to existing received income without creating a duplicate transaction.
- Added period-specific planned allocations with obligation links, priorities, editing/removal, duplicate checks, fulfillment tracking, unallocated forecasts, and insufficient-funds warnings. Plans do not change wallet balances.
- Expanded the calendar to monthly, weekly, daily, and agenda views with projected income/paydays, bill occurrences, loan installments, credit-card due dates, and savings targets. Events open their existing feature modules.
- Drift schema v7 adds recurring schedule/account/currency/receipt metadata and allocation periods, due dates, savings links, priorities, and fulfillment amounts.
- Added payday recurrence and allocation calculation tests; updated migration coverage and planning/database documentation.

## Phase 7 — Loan management and installment tracking

- Replaced the Loans summary placeholder with loan creation/editing, provider suggestions/custom provider names, separate loans under each provider, generated weekly/biweekly/monthly/quarterly/custom-day schedules, and manual installment add/edit/remove flows.
- Added loan detail views with schedule filters, paid progress, due status, payment history, provider summaries, outstanding/repaid totals, and active/paid/cancelled/archived filters.
- Added repayment confirmation with backdated dates, partial amounts, account deduction or record-only mode, idempotency, and reversal confirmation. Account-backed repayment updates wallet, transaction, installment, and loan rows atomically; record-only repayment changes no wallet data.
- Added loan cancel/archive/reopen controls, protected deletion where payment history exists, and loan status calculation with overdue precedence.
- Added explicit lender balance adjustment with an audit note; settling a loan does not fabricate a wallet payment or change the account balance.
- Drift schema v5 makes loan payment account references nullable and v6 stores total repayment obligations separately from principal and interest. Existing schema was regenerated; migration coverage checks the nullable column and total-repayment backfill.
- Added an explicit loan-funds-received action that credits a wallet through a separate confirmed transaction without counting it as income or changing the loan obligation.
- Added coverage for multiple loans per provider, partial and full payments, record-only repayment/reversal, schedule dates, statuses, and migration behavior.

## Phase 6 — Bills and recurring payments

- Added a searchable Bills workspace with default and custom categories, create/edit/duplicate/deactivate/archive/remove actions, occurrence status filters, and daily/weekly/monthly/custom date ranges.
- Added recurrence projection for one-time, daily, weekly, biweekly, monthly, quarterly, semiannual, annual, and custom-day schedules, including month-end and leap-year handling without materializing duplicate bills.
- Added explicit payment confirmation with editable amount/date/account, partial payments, idempotency, transaction-linked history, reversal support, and skipped-period markers. Only confirmed payments affect account balances.
- Added a separate bill allocation forecast and bill occurrences to the calendar. Allocation and skipped periods do not move money.
- Reused the existing schema; provider, reference, and reminder preferences are stored in the bill reminder configuration JSON. Archived bills retain payment history, and bills with history cannot be hard-deleted.
- Added recurrence, allocation, payment, reversal, duplicate submission, skip, and archive-preservation unit coverage.

## Phase 5 — Income and expense management

- Replaced the Income and Expenses placeholders with searchable, filterable record lists and add/edit/detail/cancel flows.
- Added explicit income receipt and expense payment confirmation using selected wallet accounts; planned records remain balance-neutral and credit-card expenses update liabilities only when confirmed.
- Added income categories, recurring templates, default/custom expense categories, local receipt image attachments, and reversal actions for received income and recorded expenses.
- Connected the dashboard to received/expected income, recorded expenses, remaining cash flow, period selectors, and category spending totals.
- Added cash-flow and transaction tests and corrected the v1-to-v4 account migration to preserve new wallet columns.

## Phase 4 — Wallet and account management

- Added reusable account creation and editing flows for cash, deposit accounts, e-wallets, debit cards, credit cards, and custom accounts, including linked debit cards that do not double-count balances.
- Added wallet totals, account grouping/filtering/sorting, account detail summaries, transaction search and filters, and actual-transaction balance history.
- Added manually confirmed income, expenses, transfers with fees, balance reconciliation, credit-card purchases/payments, account activation/archive/restore, and protected deletion through the existing atomic local repository.
- Added focused wallet calculation tests for credit utilization edge cases and transaction-derived history/reversals.

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
