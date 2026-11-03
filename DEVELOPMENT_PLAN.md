# Development plan

## Current status

- **Phase 1 — Project foundation:** complete. Flutter project, dependencies, Material 3, Riverpod, go_router, safe Supabase startup, initial migration, navigation shell, and placeholder routes are in place.
- **Phase 2 — Core financial data layer:** complete for the local-first data foundation. Drift v2 covers the core financial entities; the v1 upgrade preserves existing records; domain calculations and atomic repository operations cover confirmations, transfers, card activity, loan installments, savings, reconciliation, and reversals. Supabase schema v2 is prepared with RLS and NUMERIC amounts. Full synchronization is not enabled.
- **Phase 3 — Authentication, onboarding, and navigation:** complete. Added local-only entry, optional Supabase email authentication/recovery, guarded onboarding/setup routes, persisted user preferences, five-tab stateful navigation, theme selection, and repository-backed summary screens for the dashboard, bills, wallets, and loans.
- **Phase 3 local schema:** Drift v3 adds persistent app preferences through a versioned migration.
- **Phase 4 — Wallet and account management:** implemented with account creation/editing, linked debit-card handling, active/archive lifecycle, account summaries and filters, manual income/expenses, transfers, reconciliation, credit-card purchases/payments, transaction history, reversals, and transaction-derived balance history. Wallet calculations use integer minor units and the existing Drift repository.
- **Phase 5 — Income and expense management:** implemented expected/planned record creation, editing, cancellation, manual confirmation, recurring templates, category/account/date/amount filters, receipt image attachments, income/expense summaries, reversal actions, and dashboard cash-flow/category totals. Planned items do not update balances until confirmed.
- **Cloud sync and full financial workflows:** not implemented. Supabase currently handles authentication only; financial records stay local and are never merged or uploaded automatically.

## Next development phases

1. **Bills and loan workflows** — schedules, occurrence tracking, partial/early payments, explicit confirmation, and reversals.
2. **Planning and savings workflows** — payday schedules, forecast allocations, calendar, and savings goals/contributions.
3. **Offline synchronization** — decimal-safe serialization, version-checked PostgreSQL RPC, retry/backoff, ownership validation, and conflict review.
4. **Notifications, reports, and release quality** — scheduled reminders, charts, exports, accessibility, responsive/device checks, integration tests, and signing.

## Implementation rules

- Keep screens dependent on repository providers, not Drift queries.
- Reuse integer minor-unit calculation services for all displayed and saved amounts.
- Add a Drift migration and preservation test for every local schema revision.
- Require idempotency keys for operations that may be retried.
- Keep forecasts separate from actual balances and never infer a payment from a due date.
- Enable cloud writes only after the sync adapter and version-checked server operation exist.
