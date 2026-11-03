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
