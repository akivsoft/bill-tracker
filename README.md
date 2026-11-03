# MyFinance

MyFinance is a Flutter personal finance and bill tracker for Android and iOS. It is designed for manual, offline-first tracking of wallets, transactions, bills, loans, savings, and financial plans. Users confirm each payment; due dates do not change actual balances automatically.

The application does not connect to banks or request banking credentials. Supabase is optional and initializes only when both the project URL and anon key are supplied as Dart defines.

## Technology stack

- Flutter 3.44.0 / Dart 3.12.0 (detected in the current development environment)
- Material 3, responsive Flutter widgets, light and dark themes
- Riverpod runtime, annotations, code generator, and linter
- go_router with a state-preserving five-branch navigation shell
- Drift / SQLite schema v3 for local-first financial records, app preferences, and a transactional sync queue
- Supabase Auth, PostgreSQL, RLS, and Storage-ready schema
- intl, UUIDs, fl_chart, local notifications, image picker, local authentication, PDF/XLSX, and sharing packages

Resolved package versions are recorded in `pubspec.lock`. Freezed annotations are included; the Freezed generator is deferred because its stable analyzer range does not overlap the resolved Riverpod/Drift generators on the installed SDK.

## Prerequisites

- Flutter stable and Dart SDK `^3.12.0`
- Android Studio with Android SDK, command-line tools, and an Android emulator
- Android SDK licenses accepted on the development machine
- JDK 21 through Android Studio for Android builds
- macOS, Xcode, and CocoaPods for iOS builds
- Supabase CLI only when applying migrations to a Supabase project

The current workstation is Windows 11. Android Studio, SDK platforms, and Pixel 6 / Pixel 8 AVD definitions are installed. `flutter doctor` reports unaccepted Android SDK licenses. iOS builds require macOS and Xcode.

## Project setup

From this directory:

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

To regenerate while editing:

```sh
dart run build_runner watch --delete-conflicting-outputs
```

Commit generated Drift and Riverpod files alongside their annotated source files.

## Folder structure

```text
lib/
  app/                 App entry, routing, theme, and environment config
  core/                Shared constants, validation, money, and widgets
  data/                Local Drift database, Supabase boundary, and sync contracts
  features/             Feature-first module boundaries
  shared/               Riverpod providers and shared models/widgets
assets/                 Images, icons, fonts, and illustrations
supabase/migrations/    Versioned PostgreSQL migrations
test/                   Unit and widget tests
integration_test/       Reserved for device-level flows
```

Each feature is organized into `data`, `domain`, and `presentation` folders. Features are scaffolded before full business workflows are implemented.

## Supabase setup

1. Create a Supabase project.
2. Use `.env.example` as a reference; the app does not load `.env` automatically.
3. Supply URL and anon key as Dart defines:

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=AUTH_REDIRECT_URL=com.myfinance.billtracker://login-callback
```

Supabase enables email registration, sign-in, password recovery, and sign-out. Configure the redirect URL in the Supabase project's Auth URL settings as well as the app. Without Supabase credentials, users can continue in local-only mode. Local-only records remain on the device; signing in does not merge or upload them.

4. Install the Supabase CLI, link the project, and apply migrations:

```sh
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

The initial migration creates 23 tables. The Phase 2 migration adds generic financial categories and extends the ledger tables, bringing the cloud schema to 24 tables with indexes, update triggers, and owner-scoped RLS policies. No financial sample data is seeded. Never put a service-role key in a mobile app.

## Environment variables

Without the two Dart defines, the app starts in offline-only mode. The anon key can be used in a client only with RLS enabled. Service-role keys must never ship with the application.

## Database and offline records

Drift schema version 3 includes the financial records listed above, a deduplicating sync queue, and local app preferences for onboarding/setup progress, profile display name, currency, date format, week start, income cadence, language, and theme. Versioned upgrades retain prior records. Financial commands use SQLite transactions and idempotency keys to keep balance changes, history, and queue entries together. Dart calculations use integer minor units; PostgreSQL uses `NUMERIC(19,2)`. Simultaneous local and remote edits are marked for review instead of silently overwriting either copy.

Expected income, planned expenses, bill allocations, and projected money stay separate from actual balances. Bill due dates never deduct money automatically. Credit-card limits are excluded from available cash, purchases increase card debt, and card payments reduce debt without double-counting the purchase as an expense. See [DATABASE.md](DATABASE.md) for the financial invariants and local/cloud schema mapping.

See [DATABASE.md](DATABASE.md) for the table inventory, migration process, and sync rules.

## Run on Android

Review and accept Android SDK terms on the machine, then start an emulator:

```sh
flutter doctor --android-licenses
flutter emulators --launch Pixel_6
flutter run -d emulator-5554
```

You can also launch from Android Studio. If no emulator is available, connect an Android device with USB debugging enabled.

## Tests and analysis

```sh
flutter analyze
flutter test
dart run build_runner build --delete-conflicting-outputs
```

## Android release builds

```sh
flutter build apk --release
flutter build appbundle --release
```

Release signing is not configured. Add a private signing configuration before distribution; do not commit signing credentials.

## iOS build

On macOS with Xcode and CocoaPods installed:

```sh
flutter build ios
```

Set the bundle identifier and signing team in Xcode before device or App Store distribution. iOS builds cannot run from Windows.

## Troubleshooting

- **Android licenses:** run `flutter doctor --android-licenses`, review the terms, then rerun `flutter doctor -v`.
- **Flutter cannot find Git:** ensure the Git for Windows `cmd` directory and `C:\flutter\bin` are on `PATH`, then open a fresh terminal. On the current workstation, the Git directory is `C:\Users\She\scoop\apps\git\current\cmd`.
- **No device shown:** start an AVD in Android Studio or run `flutter emulators --launch Pixel_6`.
- **Supabase is unconfigured:** omit Dart defines for offline mode or provide both defines as shown above.
- **Generated code is missing:** run `dart run build_runner build --delete-conflicting-outputs`.
- **Dependency resolution fails:** keep `pubspec.lock` and use Dart `^3.12.0`; run `flutter pub get` from this directory.
- **iOS tools unavailable:** iOS builds require macOS, Xcode, and CocoaPods.

## Current implementation boundary

The project now includes email authentication and recovery when Supabase is configured, an offline-only option, first-run onboarding and financial setup, persistent five-tab navigation, saved light/dark/system theme preferences, and data-backed dashboard, bills, wallets, and loans summaries. Core financial operations and schema migrations are available locally. Full workflows for income, expenses, transactions, bills, loans, planning, and savings, cloud synchronization, scheduled notifications, reports, and exports remain planned in [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md).
