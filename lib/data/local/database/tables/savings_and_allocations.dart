import 'package:bill_tracker/data/local/database/tables/bills.dart';
import 'package:bill_tracker/data/local/database/tables/financial_accounts.dart';
import 'package:bill_tracker/data/local/database/tables/income_expenses.dart';
import 'package:bill_tracker/data/local/database/tables/loans.dart';
import 'package:bill_tracker/data/local/database/tables/transactions.dart';
import 'package:drift/drift.dart';

@DataClassName('SavingsGoalRecord')
@TableIndex(
  name: 'savings_goals_user_status_idx',
  columns: <Symbol>{#userId, #status},
)
class SavingsGoals extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get targetAmountMinorUnits => integer()();
  IntColumn get currentAmountMinorUnits =>
      integer().withDefault(const Constant(0))();
  TextColumn get currencyCode => text().withDefault(const Constant('PHP'))();
  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get contributionSchedule => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
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

@DataClassName('SavingsContributionRecord')
@TableIndex(
  name: 'savings_contributions_goal_date_idx',
  columns: <Symbol>{#goalId, #contributedAt},
)
class SavingsContributions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get goalId => text().references(SavingsGoals, #id)();
  TextColumn get accountId =>
      text().nullable().references(FinancialAccounts, #id)();
  TextColumn get transactionId =>
      text().nullable().unique().references(Transactions, #id)();
  IntColumn get amountMinorUnits => integer()();
  DateTimeColumn get contributedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get localVersion => integer().withDefault(const Constant(1))();
  IntColumn get serverVersion => integer().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

@DataClassName('AccountTransferRecord')
@TableIndex(
  name: 'account_transfers_idempotency_idx',
  columns: <Symbol>{#idempotencyKey},
  unique: true,
)
class AccountTransfers extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  @ReferenceName('outgoingTransfers')
  TextColumn get fromAccountId => text().references(FinancialAccounts, #id)();
  @ReferenceName('incomingTransfers')
  TextColumn get toAccountId => text().references(FinancialAccounts, #id)();
  TextColumn get transactionId =>
      text().nullable().unique().references(Transactions, #id)();
  TextColumn get idempotencyKey => text().nullable()();
  IntColumn get amountMinorUnits => integer()();
  IntColumn get feeMinorUnits => integer().withDefault(const Constant(0))();
  TextColumn get currencyCode => text().withDefault(const Constant('PHP'))();
  DateTimeColumn get transferredAt => dateTime()();
  DateTimeColumn get reversedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get localVersion => integer().withDefault(const Constant(1))();
  IntColumn get serverVersion => integer().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

@DataClassName('PaydayScheduleRecord')
@TableIndex(name: 'payday_schedules_date_idx', columns: <Symbol>{#paydayDate})
class PaydaySchedules extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  DateTimeColumn get paydayDate => dateTime()();
  TextColumn get frequency => text().withDefault(const Constant('one_time'))();
  IntColumn get expectedIncomeMinorUnits =>
      integer().withDefault(const Constant(0))();
  IntColumn get actualIncomeMinorUnits =>
      integer().withDefault(const Constant(0))();
  TextColumn get currencyCode => text().withDefault(const Constant('PHP'))();
  TextColumn get receivingAccountId =>
      text().nullable().references(FinancialAccounts, #id)();
  TextColumn get incomeRecordId =>
      text().nullable().references(IncomeRecords, #id)();
  DateTimeColumn get actualReceivedAt => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get status => text().withDefault(const Constant('planned'))();
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

@DataClassName('FinancialAllocationRecord')
@TableIndex(
  name: 'financial_allocations_payday_idx',
  columns: <Symbol>{#paydayScheduleId, #allocationCategory},
)
class FinancialAllocations extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get paydayScheduleId => text().references(PaydaySchedules, #id)();
  DateTimeColumn get periodDate => dateTime().nullable()();
  IntColumn get expectedIncomeMinorUnits =>
      integer().withDefault(const Constant(0))();
  IntColumn get actualIncomeMinorUnits =>
      integer().withDefault(const Constant(0))();
  IntColumn get allocatedAmountMinorUnits => integer()();
  TextColumn get allocationCategory => text().withLength(min: 1, max: 32)();
  TextColumn get relatedBillId => text().nullable().references(Bills, #id)();
  DateTimeColumn get relatedDueDate => dateTime().nullable()();
  TextColumn get relatedInstallmentId =>
      text().nullable().references(LoanInstallments, #id)();
  TextColumn get relatedSavingsGoalId =>
      text().nullable().references(SavingsGoals, #id)();
  IntColumn get priority => integer().withDefault(const Constant(3))();
  IntColumn get fulfilledAmountMinorUnits =>
      integer().withDefault(const Constant(0))();
  TextColumn get allocationKey => text().unique()();
  TextColumn get status => text().withDefault(const Constant('planned'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get localVersion => integer().withDefault(const Constant(1))();
  IntColumn get serverVersion => integer().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => <Column>{id};
}
