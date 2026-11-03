import 'package:bill_tracker/app/config/app_config.dart';
import 'package:bill_tracker/data/local/database/tables/app_preferences.dart';
import 'package:bill_tracker/data/local/database/tables/bills.dart';
import 'package:bill_tracker/data/local/database/tables/categories.dart';
import 'package:bill_tracker/data/local/database/tables/financial_accounts.dart';
import 'package:bill_tracker/data/local/database/tables/income_expenses.dart';
import 'package:bill_tracker/data/local/database/tables/loans.dart';
import 'package:bill_tracker/data/local/database/tables/savings_and_allocations.dart';
import 'package:bill_tracker/data/local/database/tables/sync_queue.dart';
import 'package:bill_tracker/data/local/database/tables/transactions.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: <Type>[
    AppPreferencesTable,
    Categories,
    FinancialAccounts,
    Bills,
    LoanProviders,
    Loans,
    Transactions,
    LoanInstallments,
    BillPayments,
    IncomeSources,
    IncomeRecords,
    Expenses,
    LoanPayments,
    SavingsGoals,
    SavingsContributions,
    AccountTransfers,
    PaydaySchedules,
    FinancialAllocations,
    SyncQueue,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: AppConfig.databaseName));

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) async => migrator.createAll(),
    onUpgrade: (Migrator migrator, int from, int to) async {
      if (from < 2) await _upgradeToVersion2(migrator);
      if (from < 3) await migrator.createTable(appPreferencesTable);
      if (from < 4 && from >= 2) {
        await migrator.addColumn(
          financialAccounts,
          financialAccounts.statementBalanceMinorUnits,
        );
        await migrator.addColumn(
          financialAccounts,
          financialAccounts.minimumPaymentMinorUnits,
        );
        await migrator.addColumn(
          financialAccounts,
          financialAccounts.openingOutstandingCreditMinorUnits,
        );
        await migrator.addColumn(
          financialAccounts,
          financialAccounts.accountNumberSuffix,
        );
        await migrator.addColumn(
          financialAccounts,
          financialAccounts.linkedAccountId,
        );
        await migrator.addColumn(
          financialAccounts,
          financialAccounts.customTypeName,
        );
        await migrator.addColumn(financialAccounts, financialAccounts.iconKey);
        await migrator.addColumn(
          financialAccounts,
          financialAccounts.colorArgb,
        );
        await migrator.addColumn(
          financialAccounts,
          financialAccounts.allowNegativeBalance,
        );
      }
      if (from < 4) {
        await customStatement(
          'UPDATE financial_accounts '
          'SET opening_outstanding_credit_minor_units = outstanding_credit_minor_units '
          "WHERE account_type = 'credit_card'",
        );
      }
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _upgradeToVersion2(Migrator migrator) async {
    // Create principal lookup/parent tables before adding references to them.
    await migrator.createTable(categories);
    await migrator.createTable(incomeSources);
    await migrator.createTable(loanProviders);
    await migrator.createTable(savingsGoals);
    await migrator.createTable(paydaySchedules);

    // Rebuild v1 tables instead of dropping them, preserving data while adding
    // constraints and columns that SQLite cannot alter in place.
    await migrator.alterTable(
      TableMigration(
        financialAccounts,
        newColumns: <GeneratedColumn>[
          financialAccounts.provider,
          financialAccounts.currentBalanceMinorUnits,
          financialAccounts.creditLimitMinorUnits,
          financialAccounts.outstandingCreditMinorUnits,
          financialAccounts.statementDate,
          financialAccounts.paymentDueDate,
          financialAccounts.notes,
          financialAccounts.isActive,
          financialAccounts.openingOutstandingCreditMinorUnits,
          financialAccounts.statementBalanceMinorUnits,
          financialAccounts.minimumPaymentMinorUnits,
          financialAccounts.accountNumberSuffix,
          financialAccounts.linkedAccountId,
          financialAccounts.customTypeName,
          financialAccounts.iconKey,
          financialAccounts.colorArgb,
          financialAccounts.allowNegativeBalance,
        ],
        columnTransformer: <GeneratedColumn, Expression>{
          financialAccounts.currentBalanceMinorUnits:
              financialAccounts.openingBalanceMinorUnits,
        },
      ),
    );
    await migrator.alterTable(
      TableMigration(
        bills,
        newColumns: <GeneratedColumn>[
          bills.categoryId,
          bills.reminderConfiguration,
          bills.automaticAllocation,
          bills.isActive,
          bills.notes,
        ],
      ),
    );
    await migrator.alterTable(
      TableMigration(
        loans,
        newColumns: <GeneratedColumn>[
          loans.providerId,
          loans.remainingBalanceMinorUnits,
          loans.interestRateBasisPoints,
          loans.totalInterestMinorUnits,
          loans.endDate,
          loans.durationMonths,
          loans.paymentFrequency,
          loans.installmentAmountMinorUnits,
          loans.totalInstallments,
          loans.paidInstallments,
          loans.nextDueDate,
          loans.paymentAccountId,
          loans.status,
          loans.notes,
        ],
        columnTransformer: <GeneratedColumn, Expression>{
          loans.remainingBalanceMinorUnits: loans.principalMinorUnits,
        },
      ),
    );
    await migrator.alterTable(
      TableMigration(
        transactions,
        newColumns: <GeneratedColumn>[
          transactions.sourceAccountId,
          transactions.destinationAccountId,
          transactions.direction,
          transactions.title,
          transactions.categoryId,
          transactions.category,
          transactions.relatedBillId,
          transactions.relatedLoanId,
          transactions.relatedInstallmentId,
          transactions.idempotencyKey,
          transactions.notes,
        ],
      ),
    );
    await migrator.alterTable(
      TableMigration(
        loanInstallments,
        newColumns: <GeneratedColumn>[
          loanInstallments.paymentAccountId,
          loanInstallments.transactionId,
          loanInstallments.notes,
        ],
      ),
    );
    await migrator.alterTable(
      TableMigration(
        billPayments,
        newColumns: <GeneratedColumn>[
          billPayments.occurrenceKey,
          billPayments.idempotencyKey,
          billPayments.reversedAt,
          billPayments.notes,
        ],
      ),
    );

    await migrator.createTable(incomeRecords);
    await migrator.createTable(expenses);
    await migrator.createTable(loanPayments);
    await migrator.createTable(savingsContributions);
    await migrator.createTable(accountTransfers);
    await migrator.createTable(financialAllocations);

    // Preserve v1 account balances and transaction descriptions as the new fields.
    await customStatement(
      "UPDATE transactions SET title = COALESCE(description, '')",
    );
    await customStatement(
      "UPDATE transactions SET source_account_id = account_id "
      "WHERE transaction_type IN ('expense', 'bill_payment', 'loan_payment', "
      "'credit_card_purchase', 'account_transfer')",
    );
    await customStatement(
      "UPDATE transactions SET destination_account_id = account_id "
      "WHERE transaction_type = 'income'",
    );
    await customStatement(
      'UPDATE loans SET remaining_balance_minor_units = principal_minor_units',
    );
    await _ensureIndexes();
  }

  Future<void> _ensureIndexes() async {
    const List<String> statements = <String>[
      'CREATE INDEX IF NOT EXISTS financial_accounts_user_active_idx '
          'ON financial_accounts (user_id, is_active)',
      'CREATE UNIQUE INDEX IF NOT EXISTS categories_user_type_name_idx '
          'ON categories (user_id, category_type, name)',
      'CREATE INDEX IF NOT EXISTS income_sources_user_name_idx '
          'ON income_sources (user_id, name)',
      'CREATE INDEX IF NOT EXISTS income_records_expected_idx '
          'ON income_records (expected_date, status)',
      'CREATE INDEX IF NOT EXISTS expenses_user_date_idx '
          'ON expenses (user_id, occurred_at)',
      'CREATE INDEX IF NOT EXISTS transactions_source_date_idx '
          'ON transactions (source_account_id, occurred_at)',
      'CREATE UNIQUE INDEX IF NOT EXISTS transactions_idempotency_idx '
          'ON transactions (idempotency_key)',
      'CREATE UNIQUE INDEX IF NOT EXISTS transactions_reversal_idx '
          'ON transactions (reversal_of_id)',
      'CREATE INDEX IF NOT EXISTS bills_user_active_due_idx '
          'ON bills (user_id, is_active, due_date)',
      'CREATE INDEX IF NOT EXISTS bill_payments_occurrence_idx '
          'ON bill_payments (bill_id, occurrence_key)',
      'CREATE UNIQUE INDEX IF NOT EXISTS bill_payments_idempotency_idx '
          'ON bill_payments (idempotency_key)',
      'CREATE INDEX IF NOT EXISTS loans_provider_status_idx '
          'ON loans (provider_id, status)',
      'CREATE UNIQUE INDEX IF NOT EXISTS loan_installments_loan_number_idx '
          'ON loan_installments (loan_id, installment_number)',
      'CREATE UNIQUE INDEX IF NOT EXISTS loan_payments_idempotency_idx '
          'ON loan_payments (idempotency_key)',
      'CREATE INDEX IF NOT EXISTS savings_goals_user_status_idx '
          'ON savings_goals (user_id, status)',
      'CREATE INDEX IF NOT EXISTS savings_contributions_goal_date_idx '
          'ON savings_contributions (goal_id, contributed_at)',
      'CREATE UNIQUE INDEX IF NOT EXISTS account_transfers_idempotency_idx '
          'ON account_transfers (idempotency_key)',
      'CREATE INDEX IF NOT EXISTS payday_schedules_date_idx '
          'ON payday_schedules (payday_date)',
      'CREATE INDEX IF NOT EXISTS financial_allocations_payday_idx '
          'ON financial_allocations (payday_schedule_id, allocation_category)',
    ];
    for (final String statement in statements) {
      await customStatement(statement);
    }
  }
}
