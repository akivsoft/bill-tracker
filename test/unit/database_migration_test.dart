import 'dart:io';

import 'package:bill_tracker/data/local/database/app_database.dart';
import 'package:bill_tracker/features/settings/data/repositories/local_user_preferences_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v1 local records survive the v3 schema migration', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'myfinance-migration-',
    );
    final File file = File(
      '${directory.path}${Platform.pathSeparator}finance.db',
    );
    final _VersionOneDatabase oldDatabase = _VersionOneDatabase(
      NativeDatabase(file),
    );
    try {
      await oldDatabase.customStatement(
        "INSERT INTO financial_accounts "
        "(id, name, account_type, opening_balance_minor_units, created_at, updated_at) "
        "VALUES ('legacy-account', 'Cash', 'cash', 123456, 0, 0)",
      );
      await oldDatabase.customStatement(
        "INSERT INTO transactions "
        "(id, account_id, transaction_type, amount_minor_units, description, "
        "occurred_at, created_at, updated_at) "
        "VALUES ('legacy-income', 'legacy-account', 'income', 50000, 'Salary', 0, 0, 0)",
      );
      await oldDatabase.customStatement(
        "INSERT INTO loans "
        "(id, provider_name, name, principal_minor_units, opened_at, created_at, updated_at) "
        "VALUES ('legacy-loan', 'GCash', 'PayLater', 90000, 0, 0, 0)",
      );
    } finally {
      await oldDatabase.close();
    }

    final AppDatabase upgraded = AppDatabase(NativeDatabase(file));
    try {
      final account = await (upgraded.select(
        upgraded.financialAccounts,
      )..where((row) => row.id.equals('legacy-account'))).getSingle();
      final transaction = await (upgraded.select(
        upgraded.transactions,
      )..where((row) => row.id.equals('legacy-income'))).getSingle();
      final loan = await (upgraded.select(
        upgraded.loans,
      )..where((row) => row.id.equals('legacy-loan'))).getSingle();

      expect(account.currentBalanceMinorUnits, 123456);
      expect(transaction.title, 'Salary');
      expect(transaction.destinationAccountId, 'legacy-account');
      expect(loan.remainingBalanceMinorUnits, 90000);

      final preferences = await LocalUserPreferencesRepository(upgraded).load();
      expect(preferences.onboardingComplete, isFalse);
      expect(preferences.currencyCode, 'PHP');
    } finally {
      await upgraded.close();
      await directory.delete(recursive: true);
    }
  });
}

final class _VersionOneDatabase extends AppDatabase {
  _VersionOneDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) async {
      const List<String> statements = <String>[
        'CREATE TABLE financial_accounts (id TEXT NOT NULL PRIMARY KEY, user_id TEXT, name TEXT NOT NULL, account_type TEXT NOT NULL, opening_balance_minor_units INTEGER NOT NULL, currency_code TEXT NOT NULL DEFAULT \'PHP\', created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, archived_at INTEGER, local_version INTEGER NOT NULL DEFAULT 1, server_version INTEGER, sync_state TEXT NOT NULL DEFAULT \'pending\')',
        'CREATE TABLE transactions (id TEXT NOT NULL PRIMARY KEY, user_id TEXT, account_id TEXT NOT NULL, transaction_type TEXT NOT NULL, amount_minor_units INTEGER NOT NULL, currency_code TEXT NOT NULL DEFAULT \'PHP\', description TEXT, related_record_type TEXT, related_record_id TEXT, reversal_of_id TEXT, occurred_at INTEGER NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER, local_version INTEGER NOT NULL DEFAULT 1, server_version INTEGER, sync_state TEXT NOT NULL DEFAULT \'pending\')',
        'CREATE TABLE bills (id TEXT NOT NULL PRIMARY KEY, user_id TEXT, name TEXT NOT NULL, amount_minor_units INTEGER NOT NULL, currency_code TEXT NOT NULL DEFAULT \'PHP\', due_date INTEGER NOT NULL, recurrence_rule TEXT, status TEXT NOT NULL DEFAULT \'unpaid\', account_id TEXT, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, archived_at INTEGER, local_version INTEGER NOT NULL DEFAULT 1, server_version INTEGER, sync_state TEXT NOT NULL DEFAULT \'pending\')',
        'CREATE TABLE bill_payments (id TEXT NOT NULL PRIMARY KEY, user_id TEXT, bill_id TEXT NOT NULL, account_id TEXT NOT NULL, transaction_id TEXT UNIQUE, amount_minor_units INTEGER NOT NULL, paid_at INTEGER NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, local_version INTEGER NOT NULL DEFAULT 1, server_version INTEGER, sync_state TEXT NOT NULL DEFAULT \'pending\')',
        'CREATE TABLE loans (id TEXT NOT NULL PRIMARY KEY, user_id TEXT, provider_name TEXT NOT NULL, name TEXT NOT NULL, principal_minor_units INTEGER NOT NULL, currency_code TEXT NOT NULL DEFAULT \'PHP\', opened_at INTEGER NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, archived_at INTEGER, local_version INTEGER NOT NULL DEFAULT 1, server_version INTEGER, sync_state TEXT NOT NULL DEFAULT \'pending\')',
        'CREATE TABLE loan_installments (id TEXT NOT NULL PRIMARY KEY, user_id TEXT, loan_id TEXT NOT NULL, installment_number INTEGER NOT NULL, due_date INTEGER NOT NULL, scheduled_minor_units INTEGER NOT NULL, paid_minor_units INTEGER NOT NULL DEFAULT 0, paid_at INTEGER, status TEXT NOT NULL DEFAULT \'unpaid\', created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, local_version INTEGER NOT NULL DEFAULT 1, server_version INTEGER, sync_state TEXT NOT NULL DEFAULT \'pending\')',
        'CREATE TABLE sync_queue (id TEXT NOT NULL PRIMARY KEY, entity_type TEXT NOT NULL, entity_id TEXT NOT NULL, operation TEXT NOT NULL, payload_json TEXT NOT NULL, base_server_version INTEGER, queued_at INTEGER NOT NULL, attempt_count INTEGER NOT NULL DEFAULT 0, next_attempt_at INTEGER, last_error TEXT, UNIQUE (entity_type, entity_id, operation))',
      ];
      for (final String statement in statements) {
        await migrator.database.customStatement(statement);
      }
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
