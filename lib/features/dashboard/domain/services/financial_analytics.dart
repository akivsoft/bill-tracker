import 'package:bill_tracker/features/transactions/domain/entities/financial_values.dart';

final class DashboardDateWindow {
  const DashboardDateWindow({
    required this.start,
    required this.endExclusive,
    required this.previousStart,
    required this.previousEndExclusive,
    required this.currencyCode,
  });

  final DateTime start;
  final DateTime endExclusive;
  final DateTime previousStart;
  final DateTime previousEndExclusive;
  final String currencyCode;

  DateTime get queryStartUtc => previousStart.toUtc();
  DateTime get queryEndUtc => endExclusive.toUtc();

  @override
  bool operator ==(Object other) =>
      other is DashboardDateWindow &&
      other.start == start &&
      other.endExclusive == endExclusive &&
      other.previousStart == previousStart &&
      other.previousEndExclusive == previousEndExclusive &&
      other.currencyCode == currencyCode;

  @override
  int get hashCode => Object.hash(
    start,
    endExclusive,
    previousStart,
    previousEndExclusive,
    currencyCode,
  );
}

final class CashFlowTrendPoint {
  const CashFlowTrendPoint({
    required this.date,
    required this.incomeMinorUnits,
    required this.expensesMinorUnits,
  });

  final DateTime date;
  final int incomeMinorUnits;
  final int expensesMinorUnits;
}

final class FinancialAnalyticsSummary {
  const FinancialAnalyticsSummary({
    required this.incomeMinorUnits,
    required this.expensesMinorUnits,
    required this.previousIncomeMinorUnits,
    required this.previousExpensesMinorUnits,
    required this.expensesByCategory,
    required this.trend,
  });

  final int incomeMinorUnits;
  final int expensesMinorUnits;
  final int previousIncomeMinorUnits;
  final int previousExpensesMinorUnits;
  final Map<String, int> expensesByCategory;
  final List<CashFlowTrendPoint> trend;

  int get netCashFlowMinorUnits => incomeMinorUnits - expensesMinorUnits;

  int get expenseChangeMinorUnits =>
      expensesMinorUnits - previousExpensesMinorUnits;

  int get incomeChangeMinorUnits => incomeMinorUnits - previousIncomeMinorUnits;
}

abstract final class FinancialAnalyticsCalculator {
  static const Set<String> _incomeTypes = <String>{'income'};
  static const Set<String> _expenseTypes = <String>{
    'expense',
    'credit_card_purchase',
    'bill_payment',
    'loan_payment',
  };

  static FinancialAnalyticsSummary summarize({
    required Iterable<FinancialTransactionView> transactions,
    required DashboardDateWindow window,
  }) {
    int income = 0;
    int expenses = 0;
    int previousIncome = 0;
    int previousExpenses = 0;
    final Map<String, int> categories = <String, int>{};
    final Map<DateTime, _MutableTrendPoint> trend =
        <DateTime, _MutableTrendPoint>{};

    DateTime bucketDate(DateTime value) {
      final DateTime local = value.toLocal();
      final int days = window.endExclusive.difference(window.start).inDays;
      if (days > 31) return DateTime(local.year, local.month);
      return DateTime(local.year, local.month, local.day);
    }

    for (final FinancialTransactionView transaction in transactions) {
      if (transaction.currencyCode != window.currencyCode ||
          transaction.reversalOfId != null ||
          transaction.type == 'reversal') {
        continue;
      }
      final DateTime localDate = transaction.occurredAt.toLocal();
      final bool inCurrent =
          !localDate.isBefore(window.start) &&
          localDate.isBefore(window.endExclusive);
      final bool inPrevious =
          !localDate.isBefore(window.previousStart) &&
          localDate.isBefore(window.previousEndExclusive);
      if (!inCurrent && !inPrevious) continue;

      final bool isIncome = _incomeTypes.contains(transaction.type);
      final bool isExpense = _expenseTypes.contains(transaction.type);
      if (!isIncome && !isExpense) continue;

      if (inPrevious) {
        if (isIncome) previousIncome += transaction.amountMinorUnits;
        if (isExpense) previousExpenses += transaction.amountMinorUnits;
      }
      if (!inCurrent) continue;
      final DateTime bucket = bucketDate(localDate);
      final _MutableTrendPoint point = trend.putIfAbsent(
        bucket,
        () => _MutableTrendPoint(bucket),
      );
      if (isIncome) {
        income += transaction.amountMinorUnits;
        point.income += transaction.amountMinorUnits;
      } else {
        expenses += transaction.amountMinorUnits;
        point.expenses += transaction.amountMinorUnits;
        final String category = _categoryName(transaction);
        categories.update(
          category,
          (int value) => value + transaction.amountMinorUnits,
          ifAbsent: () => transaction.amountMinorUnits,
        );
      }
    }

    return FinancialAnalyticsSummary(
      incomeMinorUnits: income,
      expensesMinorUnits: expenses,
      previousIncomeMinorUnits: previousIncome,
      previousExpensesMinorUnits: previousExpenses,
      expensesByCategory: Map<String, int>.unmodifiable(categories),
      trend:
          trend.values
              .map(
                (_MutableTrendPoint point) => CashFlowTrendPoint(
                  date: point.date,
                  incomeMinorUnits: point.income,
                  expensesMinorUnits: point.expenses,
                ),
              )
              .toList(growable: false)
            ..sort(
              (CashFlowTrendPoint a, CashFlowTrendPoint b) =>
                  a.date.compareTo(b.date),
            ),
    );
  }

  static String _categoryName(FinancialTransactionView transaction) {
    final String? category = transaction.category?.trim();
    if (category != null && category.isNotEmpty) return category;
    return switch (transaction.type) {
      'credit_card_purchase' => 'Credit card purchases',
      'bill_payment' => 'Bill payments',
      'loan_payment' => 'Loan payments',
      _ => 'Uncategorised',
    };
  }
}

final class _MutableTrendPoint {
  _MutableTrendPoint(this.date);
  final DateTime date;
  int income = 0;
  int expenses = 0;
}
