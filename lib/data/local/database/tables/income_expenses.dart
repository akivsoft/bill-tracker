import 'package:bill_tracker/data/local/database/tables/categories.dart';
import 'package:bill_tracker/data/local/database/tables/financial_accounts.dart';
import 'package:bill_tracker/data/local/database/tables/transactions.dart';
import 'package:drift/drift.dart';

@DataClassName('IncomeSourceRecord')
@TableIndex(
  name: 'income_sources_user_name_idx',
  columns: <Symbol>{#userId, #name},
)
class IncomeSources extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get sourceType => text().withDefault(const Constant('other'))();
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

@DataClassName('IncomeRecord')
@TableIndex(
  name: 'income_records_expected_idx',
  columns: <Symbol>{#expectedDate, #status},
)
class IncomeRecords extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get sourceId => text().nullable().references(IncomeSources, #id)();
  TextColumn get source => text().withLength(min: 1, max: 100)();
  IntColumn get amountMinorUnits => integer()();
  TextColumn get currencyCode => text().withDefault(const Constant('PHP'))();
  DateTimeColumn get expectedDate => dateTime()();
  DateTimeColumn get actualReceivedAt => dateTime().nullable()();
  TextColumn get frequency => text().withDefault(const Constant('one_time'))();
  TextColumn get receivingAccountId =>
      text().nullable().references(FinancialAccounts, #id)();
  TextColumn get status => text().withDefault(const Constant('expected'))();
  TextColumn get transactionId =>
      text().nullable().unique().references(Transactions, #id)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get localVersion => integer().withDefault(const Constant(1))();
  IntColumn get serverVersion => integer().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

@DataClassName('ExpenseRecord')
@TableIndex(
  name: 'expenses_user_date_idx',
  columns: <Symbol>{#userId, #occurredAt},
)
class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  IntColumn get amountMinorUnits => integer()();
  TextColumn get currencyCode => text().withDefault(const Constant('PHP'))();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get paymentAccountId =>
      text().nullable().references(FinancialAccounts, #id)();
  TextColumn get description => text().nullable()();
  TextColumn get attachmentReference => text().nullable()();
  TextColumn get recurrenceConfiguration => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('planned'))();
  TextColumn get transactionId =>
      text().nullable().unique().references(Transactions, #id)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get localVersion => integer().withDefault(const Constant(1))();
  IntColumn get serverVersion => integer().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => <Column>{id};
}
