import 'package:bill_tracker/features/transactions/domain/entities/financial_commands.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_values.dart';

/// Local-first operations exposed to feature providers and use cases.
abstract interface class FinancialRepository {
  Stream<List<AccountBalance>> watchAccounts();
  Stream<List<FinancialAccount>> watchFinancialAccounts();
  Stream<List<FinancialTransactionView>> watchTransactions();
  Stream<List<IncomeEntry>> watchIncome();
  Stream<List<ExpenseEntry>> watchExpenses();
  Stream<List<BillEntry>> watchBills();
  Stream<List<LoanEntry>> watchLoans();
  Stream<List<LoanInstallmentEntry>> watchInstallments(String loanId);
  Stream<List<LoanInstallmentEntry>> watchAllInstallments();
  Stream<List<SavingsGoalEntry>> watchSavingsGoals();
  Stream<List<CategoryEntry>> watchCategories({String? categoryType});
  Stream<List<PaydayScheduleEntry>> watchPaydaySchedules();
  Stream<List<AllocationEntry>> watchAllocations(String paydayScheduleId);

  Future<String> createAccount(CreateAccountInput input);
  Future<String> createCategory(CreateCategoryInput input);
  Future<String> createIncome(CreateIncomeInput input);
  Future<String> createExpense(CreateExpenseInput input);
  Future<String> createBill(CreateBillInput input);
  Future<String> createLoan(CreateLoanInput input);
  Future<String> createInstallment(CreateInstallmentInput input);
  Future<String> createSavingsGoal(CreateSavingsGoalInput input);
  Future<String> createPaydaySchedule(CreatePaydayScheduleInput input);
  Future<String> createAllocation(CreateAllocationInput input);

  Future<String> confirmIncome(ConfirmIncomeInput input);
  Future<String> confirmExpense(ConfirmExpenseInput input);
  Future<String> confirmBillPayment(BillPaymentInput input);
  Future<String> confirmLoanPayment(LoanPaymentInput input);
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
