import 'package:bill_tracker/data/local/datasources/local_financial_data_source.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_commands.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_values.dart';
import 'package:bill_tracker/features/transactions/domain/repositories/financial_repository.dart';

final class LocalFinancialRepository implements FinancialRepository {
  const LocalFinancialRepository(this._localDataSource);

  final LocalFinancialDataSource _localDataSource;

  @override
  Stream<List<AccountBalance>> watchAccounts() =>
      _localDataSource.watchAccounts();

  @override
  Stream<List<FinancialAccount>> watchFinancialAccounts() =>
      _localDataSource.watchFinancialAccounts();

  @override
  Stream<List<FinancialAccount>> watchAllFinancialAccounts() =>
      _localDataSource.watchAllFinancialAccounts();

  @override
  Stream<FinancialAccount?> watchFinancialAccount(String accountId) =>
      _localDataSource.watchFinancialAccount(accountId);

  @override
  Stream<List<FinancialTransactionView>> watchTransactions() =>
      _localDataSource.watchTransactions();

  @override
  Stream<List<FinancialTransactionView>> watchRecentTransactions({int limit = 5}) =>
      _localDataSource.watchRecentTransactions(limit: limit);

  @override
  Stream<List<FinancialTransactionView>> watchTransactionsInRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
    required String currencyCode,
  }) => _localDataSource.watchTransactionsInRange(
    startInclusive: startInclusive,
    endExclusive: endExclusive,
    currencyCode: currencyCode,
  );

  @override
  Stream<List<FinancialTransactionView>> watchAccountTransactions(
    String accountId,
  ) => _localDataSource.watchAccountTransactions(accountId);

  @override
  Stream<List<IncomeEntry>> watchIncome() => _localDataSource.watchIncome();

  @override
  Stream<List<ExpenseEntry>> watchExpenses() =>
      _localDataSource.watchExpenses();

  @override
  Stream<List<BillEntry>> watchBills() => _localDataSource.watchBills();

  @override
  Stream<List<BillPaymentEntry>> watchBillPayments() =>
      _localDataSource.watchBillPayments();

  @override
  Stream<List<LoanEntry>> watchLoans() => _localDataSource.watchLoans();

  @override
  Stream<List<LoanInstallmentEntry>> watchInstallments(String loanId) =>
      _localDataSource.watchInstallments(loanId);

  @override
  Stream<List<LoanInstallmentEntry>> watchAllInstallments() =>
      _localDataSource.watchAllInstallments();

  @override
  Stream<List<LoanPaymentEntry>> watchLoanPayments() =>
      _localDataSource.watchLoanPayments();

  @override
  Stream<List<SavingsGoalEntry>> watchSavingsGoals() =>
      _localDataSource.watchSavingsGoals();

  @override
  Stream<List<CategoryEntry>> watchCategories({String? categoryType}) =>
      _localDataSource.watchCategories(categoryType: categoryType);

  @override
  Stream<List<PaydayScheduleEntry>> watchPaydaySchedules() =>
      _localDataSource.watchPaydaySchedules();

  @override
  Stream<List<AllocationEntry>> watchAllocations(String paydayScheduleId) =>
      _localDataSource.watchAllocations(paydayScheduleId);

  @override
  Future<String> createAccount(CreateAccountInput input) =>
      _localDataSource.createAccount(input);

  @override
  Future<void> updateAccount(UpdateAccountInput input) =>
      _localDataSource.updateAccount(input);

  @override
  Future<void> setAccountActive(String accountId, bool isActive) =>
      _localDataSource.setAccountActive(accountId, isActive);

  @override
  Future<void> archiveAccount(String accountId) =>
      _localDataSource.archiveAccount(accountId);

  @override
  Future<void> restoreAccount(String accountId) =>
      _localDataSource.restoreAccount(accountId);

  @override
  Future<void> deleteAccount(String accountId) =>
      _localDataSource.deleteAccount(accountId);

  @override
  Future<String> createCategory(CreateCategoryInput input) =>
      _localDataSource.createCategory(input);

  @override
  Future<String> createIncome(CreateIncomeInput input) =>
      _localDataSource.createIncome(input);

  @override
  Future<void> updateIncome(UpdateIncomeInput input) =>
      _localDataSource.updateIncome(input);

  @override
  Future<void> cancelIncome(String incomeId) =>
      _localDataSource.cancelIncome(incomeId);

  @override
  Future<String> createExpense(CreateExpenseInput input) =>
      _localDataSource.createExpense(input);

  @override
  Future<void> updateExpense(UpdateExpenseInput input) =>
      _localDataSource.updateExpense(input);

  @override
  Future<void> cancelExpense(String expenseId) =>
      _localDataSource.cancelExpense(expenseId);

  @override
  Future<String> createBill(CreateBillInput input) =>
      _localDataSource.createBill(input);

  @override
  Future<void> updateBill(UpdateBillInput input) =>
      _localDataSource.updateBill(input);

  @override
  Future<void> setBillActive(String billId, bool isActive) =>
      _localDataSource.setBillActive(billId, isActive);

  @override
  Future<void> archiveBill(String billId) =>
      _localDataSource.archiveBill(billId);

  @override
  Future<void> deleteBill(String billId) => _localDataSource.deleteBill(billId);

  @override
  Future<void> skipBillOccurrence(SkipBillOccurrenceInput input) =>
      _localDataSource.skipBillOccurrence(input);

  @override
  Future<String> createLoan(CreateLoanInput input) =>
      _localDataSource.createLoan(input);

  @override
  Future<void> updateLoan(UpdateLoanInput input) =>
      _localDataSource.updateLoan(input);

  @override
  Future<void> setLoanStatus(String loanId, String status) =>
      _localDataSource.setLoanStatus(loanId, status);

  @override
  Future<void> archiveLoan(String loanId) =>
      _localDataSource.archiveLoan(loanId);

  @override
  Future<void> reopenLoan(String loanId) => _localDataSource.reopenLoan(loanId);

  @override
  Future<void> deleteLoan(String loanId) => _localDataSource.deleteLoan(loanId);

  @override
  Future<String> createInstallment(CreateInstallmentInput input) =>
      _localDataSource.createInstallment(input);

  @override
  Future<void> updateInstallment(UpdateInstallmentInput input) =>
      _localDataSource.updateInstallment(input);

  @override
  Future<void> deleteInstallment(String installmentId) =>
      _localDataSource.deleteInstallment(installmentId);

  @override
  Future<void> reverseUnaccountedLoanPayment(String paymentId) =>
      _localDataSource.reverseUnaccountedLoanPayment(paymentId);

  @override
  Future<String> createSavingsGoal(CreateSavingsGoalInput input) =>
      _localDataSource.createSavingsGoal(input);

  @override
  Future<String> createPaydaySchedule(CreatePaydayScheduleInput input) =>
      _localDataSource.createPaydaySchedule(input);

  @override
  Future<void> updatePaydaySchedule(UpdatePaydayScheduleInput input) =>
      _localDataSource.updatePaydaySchedule(input);

  @override
  Future<void> setPaydayScheduleActive(String scheduleId, bool isActive) =>
      _localDataSource.setPaydayScheduleActive(scheduleId, isActive);

  @override
  Future<void> linkPaydayReceipt(String scheduleId, String incomeRecordId) =>
      _localDataSource.linkPaydayReceipt(scheduleId, incomeRecordId);

  @override
  Future<void> deletePaydaySchedule(String scheduleId) =>
      _localDataSource.deletePaydaySchedule(scheduleId);

  @override
  Future<String> createAllocation(CreateAllocationInput input) =>
      _localDataSource.createAllocation(input);

  @override
  Future<void> updateAllocation(UpdateAllocationInput input) =>
      _localDataSource.updateAllocation(input);

  @override
  Future<void> deleteAllocation(String allocationId) =>
      _localDataSource.deleteAllocation(allocationId);

  @override
  Future<String> confirmIncome(ConfirmIncomeInput input) =>
      _localDataSource.confirmIncome(input);

  @override
  Future<String> confirmExpense(ConfirmExpenseInput input) =>
      _localDataSource.confirmExpense(input);

  @override
  Future<String> recordIncome(RecordIncomeInput input) =>
      _localDataSource.recordIncome(input);

  @override
  Future<String> recordExpense(RecordExpenseInput input) =>
      _localDataSource.recordExpense(input);

  @override
  Future<String> confirmBillPayment(BillPaymentInput input) =>
      _localDataSource.confirmBillPayment(input);

  @override
  Future<String> confirmLoanPayment(LoanPaymentInput input) =>
      _localDataSource.confirmLoanPayment(input);

  @override
  Future<String> recordLoanDisbursement(LoanDisbursementInput input) =>
      _localDataSource.recordLoanDisbursement(input);

  @override
  Future<void> adjustLoanBalance(AdjustLoanBalanceInput input) =>
      _localDataSource.adjustLoanBalance(input);

  @override
  Future<String> transfer(TransferInput input) =>
      _localDataSource.transfer(input);

  @override
  Future<String> recordCreditCardPurchase(CreditPurchaseInput input) =>
      _localDataSource.recordCreditCardPurchase(input);

  @override
  Future<String> recordCreditCardPayment(CreditPaymentInput input) =>
      _localDataSource.recordCreditCardPayment(input);

  @override
  Future<String?> reconcileAccount(ReconcileAccountInput input) =>
      _localDataSource.reconcileAccount(input);

  @override
  Future<String> contributeToSavings(SavingsContributionInput input) =>
      _localDataSource.contributeToSavings(input);

  @override
  Future<String> reverseTransaction({
    required String transactionId,
    required DateTime reversedAt,
    required String idempotencyKey,
    String? notes,
  }) => _localDataSource.reverseTransaction(
    transactionId: transactionId,
    reversedAt: reversedAt,
    idempotencyKey: idempotencyKey,
    notes: notes,
  );
}
