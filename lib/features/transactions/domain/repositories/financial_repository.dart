import 'package:bill_tracker/features/transactions/domain/entities/financial_commands.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_values.dart';

/// Local-first operations exposed to feature providers and use cases.
abstract interface class FinancialRepository {
  Stream<List<AccountBalance>> watchAccounts();
  Stream<List<FinancialAccount>> watchFinancialAccounts();
  Stream<List<FinancialAccount>> watchAllFinancialAccounts();
  Stream<FinancialAccount?> watchFinancialAccount(String accountId);
  Stream<List<FinancialTransactionView>> watchTransactions();
  Stream<List<FinancialTransactionView>> watchRecentTransactions({int limit = 5});
  Stream<List<FinancialTransactionView>> watchTransactionsInRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
    required String currencyCode,
  });
  Stream<List<FinancialTransactionView>> watchAccountTransactions(
    String accountId,
  );
  Stream<List<IncomeEntry>> watchIncome();
  Stream<List<ExpenseEntry>> watchExpenses();
  Stream<List<BillEntry>> watchBills();
  Stream<List<BillPaymentEntry>> watchBillPayments();
  Stream<List<LoanEntry>> watchLoans();
  Stream<List<LoanInstallmentEntry>> watchInstallments(String loanId);
  Stream<List<LoanInstallmentEntry>> watchAllInstallments();
  Stream<List<LoanPaymentEntry>> watchLoanPayments();
  Stream<List<SavingsGoalEntry>> watchSavingsGoals();
  Stream<List<CategoryEntry>> watchCategories({String? categoryType});
  Stream<List<PaydayScheduleEntry>> watchPaydaySchedules();
  Stream<List<AllocationEntry>> watchAllocations(String paydayScheduleId);

  Future<String> createAccount(CreateAccountInput input);
  Future<void> updateAccount(UpdateAccountInput input);
  Future<void> setAccountActive(String accountId, bool isActive);
  Future<void> archiveAccount(String accountId);
  Future<void> restoreAccount(String accountId);
  Future<void> deleteAccount(String accountId);
  Future<String> createCategory(CreateCategoryInput input);
  Future<String> createIncome(CreateIncomeInput input);
  Future<void> updateIncome(UpdateIncomeInput input);
  Future<void> cancelIncome(String incomeId);
  Future<String> createExpense(CreateExpenseInput input);
  Future<void> updateExpense(UpdateExpenseInput input);
  Future<void> cancelExpense(String expenseId);
  Future<String> createBill(CreateBillInput input);
  Future<void> updateBill(UpdateBillInput input);
  Future<void> setBillActive(String billId, bool isActive);
  Future<void> archiveBill(String billId);
  Future<void> deleteBill(String billId);
  Future<void> skipBillOccurrence(SkipBillOccurrenceInput input);
  Future<String> createLoan(CreateLoanInput input);
  Future<void> updateLoan(UpdateLoanInput input);
  Future<void> setLoanStatus(String loanId, String status);
  Future<void> archiveLoan(String loanId);
  Future<void> reopenLoan(String loanId);
  Future<void> deleteLoan(String loanId);
  Future<String> createInstallment(CreateInstallmentInput input);
  Future<void> updateInstallment(UpdateInstallmentInput input);
  Future<void> deleteInstallment(String installmentId);
  Future<void> reverseUnaccountedLoanPayment(String paymentId);
  Future<String> createSavingsGoal(CreateSavingsGoalInput input);
  Future<String> createPaydaySchedule(CreatePaydayScheduleInput input);
  Future<void> updatePaydaySchedule(UpdatePaydayScheduleInput input);
  Future<void> setPaydayScheduleActive(String scheduleId, bool isActive);
  Future<void> linkPaydayReceipt(String scheduleId, String incomeRecordId);
  Future<void> deletePaydaySchedule(String scheduleId);
  Future<String> createAllocation(CreateAllocationInput input);
  Future<void> updateAllocation(UpdateAllocationInput input);
  Future<void> deleteAllocation(String allocationId);

  Future<String> confirmIncome(ConfirmIncomeInput input);
  Future<String> confirmExpense(ConfirmExpenseInput input);
  Future<String> recordIncome(RecordIncomeInput input);
  Future<String> recordExpense(RecordExpenseInput input);
  Future<String> confirmBillPayment(BillPaymentInput input);
  Future<String> confirmLoanPayment(LoanPaymentInput input);
  Future<String> recordLoanDisbursement(LoanDisbursementInput input);
  Future<void> adjustLoanBalance(AdjustLoanBalanceInput input);
  Future<String> transfer(TransferInput input);
  Future<String> recordCreditCardPurchase(CreditPurchaseInput input);
  Future<String> recordCreditCardPayment(CreditPaymentInput input);
  Future<String?> reconcileAccount(ReconcileAccountInput input);
  Future<String> contributeToSavings(SavingsContributionInput input);
  Future<String> reverseTransaction({
    required String transactionId,
    required DateTime reversedAt,
    required String idempotencyKey,
    String? notes,
  });
}
