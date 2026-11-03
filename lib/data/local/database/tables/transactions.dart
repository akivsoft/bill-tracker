import 'package:bill_tracker/data/local/database/tables/bills.dart';
import 'package:bill_tracker/data/local/database/tables/categories.dart';
import 'package:bill_tracker/data/local/database/tables/financial_accounts.dart';
import 'package:bill_tracker/data/local/database/tables/loans.dart';
import 'package:drift/drift.dart';

@DataClassName('TransactionRecord')
@TableIndex(
  name: 'transactions_account_date_idx',
  columns: <Symbol>{#accountId, #occurredAt},
)
@TableIndex(
  name: 'transactions_source_date_idx',
  columns: <Symbol>{#sourceAccountId, #occurredAt},
)
@TableIndex(
  name: 'transactions_idempotency_idx',
  columns: <Symbol>{#idempotencyKey},
  unique: true,
)
@TableIndex(
  name: 'transactions_reversal_idx',
  columns: <Symbol>{#reversalOfId},
  unique: true,
)
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  // Legacy account reference is retained so version 1 rows remain readable.
  TextColumn get accountId => text().references(FinancialAccounts, #id)();
  @ReferenceName('sourceTransactions')
  TextColumn get sourceAccountId =>
      text().nullable().references(FinancialAccounts, #id)();
  @ReferenceName('destinationTransactions')
  TextColumn get destinationAccountId =>
      text().nullable().references(FinancialAccounts, #id)();
  TextColumn get transactionType => text().withLength(min: 1, max: 32)();
  TextColumn get direction => text().withDefault(const Constant('none'))();
  TextColumn get title => text().withDefault(const Constant(''))();
  IntColumn get amountMinorUnits => integer()();
  TextColumn get currencyCode => text().withDefault(const Constant('PHP'))();
  TextColumn get description => text().nullable()();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get category => text().nullable()();
  TextColumn get relatedRecordType => text().nullable()();
  TextColumn get relatedRecordId => text().nullable()();
  TextColumn get relatedBillId => text().nullable().references(Bills, #id)();
  TextColumn get relatedLoanId => text().nullable().references(Loans, #id)();
  // This optional backlink avoids a SQLite FK cycle with installment payments.
  TextColumn get relatedInstallmentId => text().nullable()();
  TextColumn get reversalOfId =>
      text().nullable().references(Transactions, #id)();
  TextColumn get idempotencyKey => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get localVersion => integer().withDefault(const Constant(1))();
  IntColumn get serverVersion => integer().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => <Column>{id};
}
