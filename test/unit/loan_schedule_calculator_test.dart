import 'package:bill_tracker/features/loans/domain/services/loan_schedule_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoanScheduleCalculator', () {
    test('monthly schedule clamps short months and returns to anchor date', () {
      final schedule = LoanScheduleCalculator.generate(
        firstDueDate: DateTime(2026, 1, 31),
        frequency: 'monthly',
        count: 3,
        totalMinorUnits: 300000,
      );
      expect(schedule.map((item) => item.dueDate), <DateTime>[
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
      ]);
      expect(
        schedule.fold<int>(0, (int n, item) => n + item.amountMinorUnits),
        300000,
      );
    });

    test(
      'custom interval and entered installment amount leave remainder last',
      () {
        final schedule = LoanScheduleCalculator.generate(
          firstDueDate: DateTime(2026, 11, 3),
          frequency: 'custom:10',
          count: 3,
          totalMinorUnits: 100000,
          installmentAmountMinorUnits: 40000,
        );
        expect(schedule.map((item) => item.dueDate), <DateTime>[
          DateTime(2026, 11, 3),
          DateTime(2026, 11, 13),
          DateTime(2026, 11, 23),
        ]);
        expect(schedule.map((item) => item.amountMinorUnits), <int>[
          40000,
          40000,
          20000,
        ]);
      },
    );
  });
}
