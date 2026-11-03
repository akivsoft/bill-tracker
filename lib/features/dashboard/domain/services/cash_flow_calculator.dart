import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';

final class CashFlowSummary {
  const CashFlowSummary({
    required this.incomeReceivedMinorUnits,
    required this.expectedIncomeMinorUnits,
    required this.expensesMinorUnits,
    required this.expensesByCategory,
  });

  final int incomeReceivedMinorUnits;
  final int expectedIncomeMinorUnits;
  final int expensesMinorUnits;
  final Map<String?, int> expensesByCategory;

  int get remainingCashFlowMinorUnits =>
      incomeReceivedMinorUnits - expensesMinorUnits;
}

final class CashFlowCalculator {
  const CashFlowCalculator._();

  static CashFlowSummary summarize({
    required Iterable<IncomeEntry> incomes,
    required Iterable<ExpenseEntry> expenses,
    required DateTime start,
    required DateTime endExclusive,
  }) {
    bool within(DateTime date) =>
        !date.isBefore(start) && date.isBefore(endExclusive);
    int received = 0;
    int expected = 0;
    int spent = 0;
    final Map<String?, int> categories = <String?, int>{};
    for (final IncomeEntry income in incomes) {
      if (income.status == 'received' &&
          income.actualReceivedAt != null &&
          within(income.actualReceivedAt!)) {
        received += income.amountMinorUnits;
      } else if (income.status == 'expected' && within(income.expectedDate)) {
        expected += income.amountMinorUnits;
      }
    }
    for (final ExpenseEntry expense in expenses) {
      if (expense.status != 'confirmed' || !within(expense.occurredAt)) {
        continue;
      }
      spent += expense.amountMinorUnits;
      categories.update(
        expense.categoryId,
        (int current) => current + expense.amountMinorUnits,
        ifAbsent: () => expense.amountMinorUnits,
      );
    }
    return CashFlowSummary(
      incomeReceivedMinorUnits: received,
      expectedIncomeMinorUnits: expected,
      expensesMinorUnits: spent,
      expensesByCategory: Map<String?, int>.unmodifiable(categories),
    );
  }
}
