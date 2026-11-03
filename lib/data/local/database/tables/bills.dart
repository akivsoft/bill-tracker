import 'package:bill_tracker/data/local/database/tables/categories.dart';
import 'package:bill_tracker/data/local/database/tables/financial_accounts.dart';
import 'package:bill_tracker/data/local/database/tables/transactions.dart';
import 'package:drift/drift.dart';

@DataClassName('BillRecord')
@TableIndex(name: 'bills_due_date_idx', columns: <Symbol>{#dueDate})
@TableIndex(
  name: 'bills_user_active_due_idx',
  columns: <Symbol>{#userId, #isActive, #dueDate},
)
class Bills extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  IntColumn get amountMinorUnits => integer()();
  TextColumn get currencyCode => text().withDefault(const Constant('PHP'))();
  DateTimeColumn get dueDate => dateTime()();
  TextColumn get recurrenceRule => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('unpaid'))();
  TextColumn get accountId =>
      text().nullable().references(FinancialAccounts, #id)();
  TextColumn get reminderConfiguration => text().nullable()();
  BoolColumn get automaticAllocation =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  IntColumn get localVersion => integer().withDefault(const Constant(1))();
  IntColumn get serverVersion => integer().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

@DataClassName('BillPaymentRecord')
@TableIndex(name: 'bill_payments_bill_idx', columns: <Symbol>{#billId})
@TableIndex(
  name: 'bill_payments_occurrence_idx',
  columns: <Symbol>{#billId, #occurrenceKey},
)
@TableIndex(
  name: 'bill_payments_idempotency_idx',
  columns: <Symbol>{#idempotencyKey},
  unique: true,
)
class BillPayments extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get billId => text().references(Bills, #id)();
  TextColumn get accountId => text().references(FinancialAccounts, #id)();
  TextColumn get transactionId =>
      text().nullable().unique().references(Transactions, #id)();
  TextColumn get occurrenceKey => text().withDefault(const Constant(''))();
  TextColumn get idempotencyKey => text().nullable()();
  IntColumn get amountMinorUnits => integer()();
  DateTimeColumn get paidAt => dateTime()();
  DateTimeColumn get reversedAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get localVersion => integer().withDefault(const Constant(1))();
  IntColumn get serverVersion => integer().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => <Column>{id};
}
