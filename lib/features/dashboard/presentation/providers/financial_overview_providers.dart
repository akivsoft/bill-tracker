import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_values.dart';
import 'package:bill_tracker/shared/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final StreamProvider<List<AccountBalance>> accountBalancesProvider =
    StreamProvider<List<AccountBalance>>(
      (Ref ref) => ref.watch(financialRepositoryProvider).watchAccounts(),
    );

final StreamProvider<List<FinancialAccount>> financialAccountsProvider =
    StreamProvider<List<FinancialAccount>>(
      (Ref ref) =>
          ref.watch(financialRepositoryProvider).watchFinancialAccounts(),
    );

final StreamProvider<List<IncomeEntry>> incomeOverviewProvider =
    StreamProvider<List<IncomeEntry>>(
      (Ref ref) => ref.watch(financialRepositoryProvider).watchIncome(),
    );

final StreamProvider<List<ExpenseEntry>> expensesOverviewProvider =
    StreamProvider<List<ExpenseEntry>>(
      (Ref ref) => ref.watch(financialRepositoryProvider).watchExpenses(),
    );

final StreamProvider<List<CategoryEntry>> incomeCategoriesProvider =
    StreamProvider<List<CategoryEntry>>(
      (Ref ref) => ref
          .watch(financialRepositoryProvider)
          .watchCategories(categoryType: 'income'),
    );

final StreamProvider<List<CategoryEntry>> expenseCategoriesProvider =
    StreamProvider<List<CategoryEntry>>(
      (Ref ref) => ref
          .watch(financialRepositoryProvider)
          .watchCategories(categoryType: 'expense'),
    );

final StreamProvider<List<FinancialAccount>> walletManagementAccountsProvider =
    StreamProvider<List<FinancialAccount>>(
      (Ref ref) =>
          ref.watch(financialRepositoryProvider).watchAllFinancialAccounts(),
    );

final accountDetailsProvider = StreamProvider.family<FinancialAccount?, String>(
  (Ref ref, String accountId) =>
      ref.watch(financialRepositoryProvider).watchFinancialAccount(accountId),
);

final accountTransactionsProvider =
    StreamProvider.family<List<FinancialTransactionView>, String>(
      (Ref ref, String accountId) => ref
          .watch(financialRepositoryProvider)
          .watchAccountTransactions(accountId),
    );

final StreamProvider<List<BillEntry>> billsOverviewProvider =
    StreamProvider<List<BillEntry>>(
      (Ref ref) => ref.watch(financialRepositoryProvider).watchBills(),
    );

final StreamProvider<List<LoanEntry>> loansOverviewProvider =
    StreamProvider<List<LoanEntry>>(
      (Ref ref) => ref.watch(financialRepositoryProvider).watchLoans(),
    );

final StreamProvider<List<LoanInstallmentEntry>> installmentsOverviewProvider =
    StreamProvider<List<LoanInstallmentEntry>>(
      (Ref ref) =>
          ref.watch(financialRepositoryProvider).watchAllInstallments(),
    );

final StreamProvider<List<FinancialTransactionView>>
recentTransactionsProvider = StreamProvider<List<FinancialTransactionView>>(
  (Ref ref) => ref.watch(financialRepositoryProvider).watchTransactions(),
);
