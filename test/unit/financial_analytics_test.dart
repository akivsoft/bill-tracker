import 'package:bill_tracker/features/dashboard/domain/services/financial_analytics.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_values.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DashboardDateWindow window = DashboardDateWindow(
    start: DateTime(2026, 10, 1),
    endExclusive: DateTime(2026, 11, 1),
    previousStart: DateTime(2026, 9, 1),
    previousEndExclusive: DateTime(2026, 10, 1),
    currencyCode: 'PHP',
  );

  FinancialTransactionView transaction({
    required String id,
    required String type,
    required int amount,
    required DateTime date,
    String currency = 'PHP',
    String? category,
    String? reversalOfId,
  }) => FinancialTransactionView(
    id: id,
    type: type,
    title: id,
    amountMinorUnits: amount,
    currencyCode: currency,
    occurredAt: date,
    category: category,
    reversalOfId: reversalOfId,
  );

  test('summarizes current and previous cash flow and expense categories', () {
    final FinancialAnalyticsSummary result =
        FinancialAnalyticsCalculator.summarize(
          window: window,
          transactions: <FinancialTransactionView>[
            transaction(
              id: 'prior-income',
              type: 'income',
              amount: 50000,
              date: DateTime(2026, 9, 10),
            ),
            transaction(
              id: 'prior-expense',
              type: 'expense',
              amount: 10000,
              date: DateTime(2026, 9, 11),
            ),
            transaction(
              id: 'salary',
              type: 'income',
              amount: 70000,
              date: DateTime(2026, 10, 2),
            ),
            transaction(
              id: 'food',
              type: 'expense',
              amount: 12000,
              date: DateTime(2026, 10, 3),
              category: 'Food',
            ),
            transaction(
              id: 'bill',
              type: 'bill_payment',
              amount: 8000,
              date: DateTime(2026, 10, 4),
            ),
          ],
        );

    expect(result.incomeMinorUnits, 70000);
    expect(result.expensesMinorUnits, 20000);
    expect(result.netCashFlowMinorUnits, 50000);
    expect(result.previousIncomeMinorUnits, 50000);
    expect(result.previousExpensesMinorUnits, 10000);
    expect(result.expenseChangeMinorUnits, 10000);
    expect(result.expensesByCategory, <String, int>{
      'Food': 12000,
      'Bill payments': 8000,
    });
    expect(result.trend, hasLength(3));
    expect(
      result.trend.fold<int>(0, (sum, point) => sum + point.incomeMinorUnits),
      70000,
    );
    expect(
      result.trend.fold<int>(0, (sum, point) => sum + point.expensesMinorUnits),
      20000,
    );
  });

  test(
    'excludes transfers, card payments, other currencies, and reversals',
    () {
      final FinancialAnalyticsSummary result =
          FinancialAnalyticsCalculator.summarize(
            window: window,
            transactions: <FinancialTransactionView>[
              transaction(
                id: 'transfer',
                type: 'transfer',
                amount: 9000,
                date: DateTime(2026, 10, 2),
              ),
              transaction(
                id: 'card-payment',
                type: 'credit_card_payment',
                amount: 10000,
                date: DateTime(2026, 10, 2),
              ),
              transaction(
                id: 'usd-income',
                type: 'income',
                amount: 100000,
                date: DateTime(2026, 10, 2),
                currency: 'USD',
              ),
              transaction(
                id: 'reversal',
                type: 'expense',
                amount: 7000,
                date: DateTime(2026, 10, 2),
                reversalOfId: 'old-expense',
              ),
            ],
          );

      expect(result.incomeMinorUnits, 0);
      expect(result.expensesMinorUnits, 0);
      expect(result.trend, isEmpty);
      expect(result.expensesByCategory, isEmpty);
    },
  );

  test('returns a clean empty summary', () {
    final FinancialAnalyticsSummary result =
        FinancialAnalyticsCalculator.summarize(
          window: window,
          transactions: const <FinancialTransactionView>[],
        );

    expect(result.netCashFlowMinorUnits, 0);
    expect(result.incomeChangeMinorUnits, 0);
    expect(result.expenseChangeMinorUnits, 0);
    expect(result.expensesByCategory, isEmpty);
    expect(result.trend, isEmpty);
  });
}
