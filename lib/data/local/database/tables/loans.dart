import 'package:bill_tracker/data/local/database/tables/financial_accounts.dart';
import 'package:bill_tracker/data/local/database/tables/transactions.dart';
import 'package:drift/drift.dart';

@DataClassName('LoanProviderRecord')
@TableIndex(
  name: 'loan_providers_user_name_idx',
  columns: <Symbol>{#userId, #name},
  unique: true,
)
class LoanProviders extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  IntColumn get localVersion => integer().withDefault(const Constant(1))();
  IntColumn get serverVersion => integer().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

@DataClassName('LoanRecord')
@TableIndex(
  name: 'loans_provider_status_idx',
  columns: <Symbol>{#providerId, #status},
)
class Loans extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get providerName => text().withLength(min: 1, max: 100)();
  TextColumn get providerId =>
      text().nullable().references(LoanProviders, #id)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get principalMinorUnits => integer()();
  IntColumn get remainingBalanceMinorUnits =>
      integer().withDefault(const Constant(0))();
  IntColumn get interestRateBasisPoints =>
      integer().withDefault(const Constant(0))();
  IntColumn get totalInterestMinorUnits =>
      integer().withDefault(const Constant(0))();
  IntColumn get totalRepaymentMinorUnits =>
      integer().withDefault(const Constant(0))();
  TextColumn get currencyCode => text().withDefault(const Constant('PHP'))();
  DateTimeColumn get openedAt => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  IntColumn get durationMonths => integer().nullable()();
  TextColumn get paymentFrequency =>
      text().withDefault(const Constant('monthly'))();
  IntColumn get installmentAmountMinorUnits =>
      integer().withDefault(const Constant(0))();
  IntColumn get totalInstallments => integer().withDefault(const Constant(0))();
  IntColumn get paidInstallments => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextDueDate => dateTime().nullable()();
  TextColumn get paymentAccountId =>
      text().nullable().references(FinancialAccounts, #id)();
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

@DataClassName('LoanInstallmentRecord')
@TableIndex(name: 'loan_installments_due_idx', columns: <Symbol>{#dueDate})
@TableIndex(
  name: 'loan_installments_loan_number_idx',
  columns: <Symbol>{#loanId, #installmentNumber},
  unique: true,
)
class LoanInstallments extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get loanId => text().references(Loans, #id)();
  IntColumn get installmentNumber => integer()();
  DateTimeColumn get dueDate => dateTime()();
  IntColumn get scheduledMinorUnits => integer()();
  IntColumn get paidMinorUnits => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('unpaid'))();
  DateTimeColumn get paidAt => dateTime().nullable()();
  TextColumn get paymentAccountId =>
      text().nullable().references(FinancialAccounts, #id)();
  TextColumn get transactionId =>
      text().nullable().references(Transactions, #id)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get localVersion => integer().withDefault(const Constant(1))();
  IntColumn get serverVersion => integer().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

@DataClassName('LoanPaymentRecord')
@TableIndex(
  name: 'loan_payments_idempotency_idx',
  columns: <Symbol>{#idempotencyKey},
  unique: true,
)
class LoanPayments extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get loanId => text().references(Loans, #id)();
  TextColumn get installmentId =>
      text().nullable().references(LoanInstallments, #id)();
  TextColumn get accountId =>
      text().nullable().references(FinancialAccounts, #id)();
  TextColumn get transactionId =>
      text().nullable().unique().references(Transactions, #id)();
  TextColumn get idempotencyKey => text().nullable()();
  IntColumn get amountMinorUnits => integer()();
  DateTimeColumn get paidAt => dateTime()();
  TextColumn get status => text().withDefault(const Constant('confirmed'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get localVersion => integer().withDefault(const Constant(1))();
  IntColumn get serverVersion => integer().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => <Column>{id};
}
