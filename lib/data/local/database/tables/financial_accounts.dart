import 'package:drift/drift.dart';

@DataClassName('FinancialAccountRecord')
@TableIndex(
  name: 'financial_accounts_user_active_idx',
  columns: <Symbol>{#userId, #isActive},
)
class FinancialAccounts extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get provider => text().nullable()();
  TextColumn get accountType => text().withLength(min: 1, max: 32)();

  // Kept for existing installations; current balance is the live ledger value.
  IntColumn get openingBalanceMinorUnits => integer()();
  IntColumn get currentBalanceMinorUnits =>
      integer().withDefault(const Constant(0))();
  IntColumn get creditLimitMinorUnits =>
      integer().withDefault(const Constant(0))();
  IntColumn get outstandingCreditMinorUnits =>
      integer().withDefault(const Constant(0))();
  IntColumn get openingOutstandingCreditMinorUnits =>
      integer().withDefault(const Constant(0))();
  IntColumn get statementBalanceMinorUnits =>
      integer().withDefault(const Constant(0))();
  IntColumn get minimumPaymentMinorUnits =>
      integer().withDefault(const Constant(0))();
  TextColumn get currencyCode => text().withDefault(const Constant('PHP'))();
  DateTimeColumn get statementDate => dateTime().nullable()();
  DateTimeColumn get paymentDueDate => dateTime().nullable()();
  TextColumn get accountNumberSuffix => text().nullable()();
  TextColumn get linkedAccountId => text().nullable()();
  TextColumn get customTypeName => text().nullable()();
  TextColumn get iconKey => text().nullable()();
  IntColumn get colorArgb => integer().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get allowNegativeBalance =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  IntColumn get localVersion => integer().withDefault(const Constant(1))();
  IntColumn get serverVersion => integer().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => <Column>{id};
}
