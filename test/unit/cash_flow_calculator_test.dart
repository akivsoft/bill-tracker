import 'package:bill_tracker/features/dashboard/domain/services/cash_flow_calculator.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'dashboard totals separate expected income and exclude non-recorded expenses',
    () {
      final DateTime start = DateTime(2026, 11, 1);
      final DateTime end = DateTime(2026, 12, 1);
      final CashFlowSummary summary = CashFlowCalculator.summarize(
        incomes: <IncomeEntry>[
          IncomeEntry(
            id: 'received',
            source: 'Salary',
            amountMinorUnits: 500000,
            currencyCode: 'PHP',
            expectedDate: DateTime(2026, 10, 30),
            actualReceivedAt: DateTime(2026, 11, 2),
            frequency: 'monthly',
            status: 'received',
          ),
          IncomeEntry(
            id: 'expected',
            source: 'Freelance',
            amountMinorUnits: 125000,
            currencyCode: 'PHP',
            expectedDate: DateTime(2026, 11, 15),
            frequency: 'one_time',
            status: 'expected',
          ),
          IncomeEntry(
            id: 'cancelled',
            source: 'Cancelled',
            amountMinorUnits: 90000,
            currencyCode: 'PHP',
            expectedDate: DateTime(2026, 11, 20),
            frequency: 'one_time',
            status: 'cancelled',
          ),
        ],
        expenses: <ExpenseEntry>[
          ExpenseEntry(
            id: 'food',
            title: 'Food',
            amountMinorUnits: 50000,
            currencyCode: 'PHP',
            occurredAt: DateTime(2026, 11, 3),
            status: 'confirmed',
            categoryId: 'food',
          ),
          ExpenseEntry(
            id: 'planned',
            title: 'Planned',
            amountMinorUnits: 99000,
            currencyCode: 'PHP',
            occurredAt: DateTime(2026, 11, 4),
            status: 'planned',
            categoryId: 'food',
          ),
          ExpenseEntry(
            id: 'old',
            title: 'Old',
            amountMinorUnits: 10000,
            currencyCode: 'PHP',
            occurredAt: DateTime(2026, 10, 31),
            status: 'confirmed',
            categoryId: 'other',
          ),
        ],
        start: start,
        endExclusive: end,
      );

      expect(summary.incomeReceivedMinorUnits, 500000);
      expect(summary.expectedIncomeMinorUnits, 125000);
      expect(summary.expensesMinorUnits, 50000);
      expect(summary.remainingCashFlowMinorUnits, 450000);
      expect(summary.expensesByCategory, <String?, int>{'food': 50000});
    },
  );
}
