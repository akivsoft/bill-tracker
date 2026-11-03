import 'package:bill_tracker/data/local/database/app_database.dart';
import 'package:bill_tracker/data/local/database/tables/financial_accounts.dart';
import 'package:bill_tracker/data/sync/sync_queue.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class LocalDataSource {
  LocalDataSource(this._database);

  final AppDatabase _database;
  static const Uuid _uuid = Uuid();

  Stream<List<FinancialAccountRecord>> watchAccounts() => (_database.select(
    _database.financialAccounts,
  )..where((FinancialAccounts row) => row.archivedAt.isNull())).watch();

  Future<void> saveAccount({
    required String name,
    required String accountType,
    required int openingBalanceMinorUnits,
    String? id,
    String? userId,
    String currencyCode = 'PHP',
  }) async {
    if (name.trim().isEmpty) throw ArgumentError.value(name, 'name');
    if (openingBalanceMinorUnits < 0) {
      throw ArgumentError.value(
        openingBalanceMinorUnits,
        'openingBalanceMinorUnits',
      );
    }

    final DateTime now = DateTime.now().toUtc();
    final String recordId = id ?? _uuid.v4();
    await _database.transaction(() async {
      final FinancialAccountRecord? existing = id == null
          ? null
          : await (_database.select(_database.financialAccounts)
                  ..where((FinancialAccounts row) => row.id.equals(recordId)))
                .getSingleOrNull();
      final int persistedBalance;
      if (existing == null) {
        persistedBalance = openingBalanceMinorUnits;
        await _database
            .into(_database.financialAccounts)
            .insert(
              FinancialAccountsCompanion.insert(
                id: recordId,
                userId: Value<String?>(userId),
                name: name.trim(),
                accountType: accountType,
                openingBalanceMinorUnits: openingBalanceMinorUnits,
                currentBalanceMinorUnits: Value<int>(openingBalanceMinorUnits),
                currencyCode: Value<String>(currencyCode),
                createdAt: now,
                updatedAt: now,
              ),
            );
      } else {
        persistedBalance = existing.currentBalanceMinorUnits;
        await (_database.update(
          _database.financialAccounts,
        )..where((FinancialAccounts row) => row.id.equals(recordId))).write(
          FinancialAccountsCompanion(
            name: Value<String>(name.trim()),
            accountType: Value<String>(accountType),
            currencyCode: Value<String>(currencyCode),
            updatedAt: Value<DateTime>(now),
            localVersion: Value<int>(existing.localVersion + 1),
          ),
        );
      }

      final Map<String, Object?> payload = <String, Object?>{
        'id': recordId,
        'user_id': userId,
        'name': name.trim(),
        'account_type': accountType,
        'opening_balance_minor_units': openingBalanceMinorUnits,
        'current_balance_minor_units': persistedBalance,
        'currency_code': currencyCode,
        'updated_at': now.toIso8601String(),
      };

      await SyncQueueStore(_database).enqueue(
        entityType: 'financial_accounts',
        entityId: recordId,
        operation: 'upsert',
        payload: payload,
      );
    });
  }
}
