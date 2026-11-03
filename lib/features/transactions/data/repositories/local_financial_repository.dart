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
  Stream<List<LoanEntry>> watchLoans() => _localDataSource.watchLoans();

  @override
  Stream<List<LoanInstallmentEntry>> watchInstallments(String loanId) =>
      _localDataSource.watchInstallments(loanId);

  @override
  Stream<List<LoanInstallmentEntry>> watchAllInstallments() =>
      _localDataSource.watchAllInstallments();

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
  Future<String> createLoan(CreateLoanInput input) =>
      _localDataSource.createLoan(input);

  @override
  Future<String> createInstallment(CreateInstallmentInput input) =>
      _localDataSource.createInstallment(input);

  @override
  Future<String> createSavingsGoal(CreateSavingsGoalInput input) =>
      _localDataSource.createSavingsGoal(input);

  @override
  Future<String> createPaydaySchedule(CreatePaydayScheduleInput input) =>
      _localDataSource.createPaydaySchedule(input);

  @override
  Future<String> createAllocation(CreateAllocationInput input) =>
      _localDataSource.createAllocation(input);

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
