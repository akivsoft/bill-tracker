# MyFinance

MyFinance is a local-first personal finance app for manually tracking accounts, transactions, bills, loans, savings, and payday plans. Payment actions are always confirmed by the user. It does not connect to banks, fetch bank activity, or execute payments.

## Features

- Wallets, account balances, transfers, credit-card purchases/payments, transaction history, and reversals.
- Confirmed and expected income, expenses, recurring bills, loan installments, savings goals, and payday allocations.
- Dashboard analytics and filtered reports with PDF, Excel (`.xlsx`), and CSV sharing.
- Local bill, loan, card, payday, and configured savings reminders. Notifications do not make payments.
- Versioned local JSON backup and validated, confirmed replacement restore.
- Optional Supabase email authentication. Financial records stay in local Drift storage; cloud synchronization is not implemented and no records are uploaded.

## Technology

- Flutter 3.44 / Dart `^3.12`, Material 3, Riverpod, and go_router.
- Drift / SQLite schema v7, integer minor-unit money calculations, `fl_chart`.
- Supabase Auth and PostgreSQL schema migrations with owner-scoped Row Level Security (RLS).
- `pdf`, `excel`, `share_plus`, `flutter_local_notifications`, and `timezone`.

## Setup

Install Flutter/Dart, Android Studio and Android SDK, and JDK 17 or newer. From the project directory:

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

The app works without Supabase configuration. To enable email authentication, configure the Supabase redirect URL and provide the project URL and **anon/publishable** key as Dart defines. Never use a service-role key in the app.

```sh
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY --dart-define=AUTH_REDIRECT_URL=com.myfinance.billtracker://login-callback
```

For a Supabase project, install the Supabase CLI, link the project, and apply `supabase/migrations/`. The migrations prepare RLS-protected tables, but a financial-data sync worker/API and complete local-to-remote mapping are not implemented. Signing in does not upload or merge local records.

## Local data and backup

Drift schema v7 stores accounts, transactions, income/expenses, bills/payments, loans/installments, savings, payday schedules/allocations, sync queue metadata, and app preferences. Database migrations preserve existing data. Amounts are stored as integer minor units locally. Expected income and planned allocations are separate from actual cash balances.

Backups are manually created JSON files shared through the platform share sheet. Restore currently accepts pasted backup JSON, validates it, asks before replacing existing data, and performs database writes transactionally with foreign-key checks. Backups are not encrypted by MyFinance; keep shared backup files in a location you control. Cloud backup/synchronization is unavailable.

## Tests and analysis

```sh
flutter analyze
flutter test
```

The suite covers financial calculations and data-source operations, migration preservation, reports and file generation, reminder planning, backup validation/restore, routing, and app widgets. Device-level Android workflows still require manual verification.

## Android release build

The application ID is `com.myfinance.billtracker`; the app label is `MyFinance`; version is defined in `pubspec.yaml`. The verified release manifest resolves to minimum Android SDK 24 and target SDK 36. Notification permission and reboot scheduling are configured in the Android manifest. The app bundle does not use the debug signing key for release builds.

To sign a release, create and protect a private keystore outside source control. Create `android/key.properties` locally with:

```properties
storeFile=release-upload-key.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=YOUR_KEY_ALIAS
keyPassword=YOUR_KEY_PASSWORD
```

Place the keystore in `android/` or provide a path relative to that directory. The Gradle release configuration uses those values when present. `android/key.properties` and Android keystore files are ignored by Git. Preserve a secure backup of the keystore and passwords; losing them can prevent future app updates. Build with:

```sh
flutter build appbundle --release
```

Without local signing properties, Gradle can verify/produce an unsigned release build, but that bundle is **not ready for Play Console upload**. No build or Play Store submission is performed automatically.

## Known limitations and manual checks

- Cloud financial synchronization is disabled. Authentication is separate from local financial storage.
- Reminder scheduling is initiated by the user and currently covers a finite future horizon. Timezone offset is refreshed when scheduling; daylight-saving changes and per-obligation scheduling still need device testing.
- Restore imports pasted JSON instead of selecting a file. Backup files are not encrypted.
- The SQLite database uses the Android app-private sandbox but is not encrypted with SQLCipher, and there is no in-app biometric lock. Use Android device encryption and a strong device lock for local-data protection.
- Before release, verify signed AAB installation/update behavior, notifications/permission and reboot behavior, deep links, backups across app versions, and layouts on small/large Android devices in light/dark themes.
- iOS builds require macOS and Xcode.
