import 'package:bill_tracker/data/local/backup/local_backup_service.dart';
import 'package:bill_tracker/data/local/database/app_database.dart';
import 'package:bill_tracker/data/local/datasources/local_financial_data_source.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_commands.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late LocalFinancialDataSource source;
  late LocalBackupService backups;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    source = LocalFinancialDataSource(database);
    backups = LocalBackupService(database);
  });

  tearDown(() => database.close());

  test('validates a versioned backup and rejects malformed input', () async {
    final String backup = await backups.createBackup();
    expect(backups.validate(backup).recordCount, 0);
    expect(() => backups.validate('{bad json'), throwsFormatException);
    expect(
      () => backups.validate('{"format":"other","version":1,"tables":{}}'),
      throwsFormatException,
    );
  });

  test(
    'restore replaces data transactionally and preserves record identifiers',
    () async {
      final String savedId = await source.createAccount(
        const CreateAccountInput(
          name: 'Saved cash',
          accountType: 'cash',
          openingBalanceMinorUnits: 12000,
        ),
      );
      await database
          .into(database.transactions)
          .insert(
            TransactionsCompanion.insert(
              id: 'linked-transaction',
              accountId: savedId,
              transactionType: 'income',
              title: const Value<String>('Salary'),
              amountMinorUnits: 2500,
              currencyCode: const Value<String>('PHP'),
              occurredAt: DateTime.utc(2026, 10, 3),
              createdAt: DateTime.utc(2026, 10, 3),
              updatedAt: DateTime.utc(2026, 10, 3),
            ),
          );
      final String backup = await backups.createBackup();
      await source.createAccount(
        const CreateAccountInput(
          name: 'Temporary cash',
          accountType: 'cash',
          openingBalanceMinorUnits: 500,
        ),
      );

      final BackupValidation restored = await backups.restoreReplacing(backup);
      await backups.restoreReplacing(backup);
      final accounts = await database.select(database.financialAccounts).get();
      final transactions = await database.select(database.transactions).get();
      expect(restored.recordCount, greaterThan(0));
      expect(accounts, hasLength(1));
      expect(accounts.single.id, savedId);
      expect(accounts.single.currentBalanceMinorUnits, 12000);
      expect(transactions, hasLength(1));
      expect(transactions.single.id, 'linked-transaction');
      expect(transactions.single.accountId, accounts.single.id);
    },
  );

  test('failed restore rolls back and keeps existing records', () async {
    final String existingId = await source.createAccount(
      const CreateAccountInput(
        name: 'Keep this account',
        accountType: 'cash',
        openingBalanceMinorUnits: 4000,
      ),
    );
    final String goodBackup = await backups.createBackup();
    final String corruptBackup = goodBackup.replaceFirst(
      '"name": "Keep this account"',
      '"unknown_secret": "x", "name": "Keep this account"',
    );
    await expectLater(
      backups.restoreReplacing(corruptBackup),
      throwsA(anything),
    );
    final accounts = await database.select(database.financialAccounts).get();
    expect(accounts, hasLength(1));
    expect(accounts.single.id, existingId);
  });
}
