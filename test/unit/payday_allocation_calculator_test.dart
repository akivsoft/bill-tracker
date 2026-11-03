import 'package:bill_tracker/features/planner/domain/services/payday_allocation_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'uses expected income while unpaid and separates confirmed payments',
    () {
      final summary = PaydayAllocationCalculator.calculate(
        expectedIncomeMinorUnits: 1_500_000,
        actualReceivedIncomeMinorUnits: 0,
        plannedAllocationsMinorUnits: 900_000,
        confirmedPaymentsMinorUnits: 250_000,
      );
      expect(summary.incomeBasisMinorUnits, 1_500_000);
      expect(summary.unallocatedMinorUnits, 600_000);
      expect(summary.projectedRemainingMinorUnits, 600_000);
      expect(summary.confirmedPaymentsMinorUnits, 250_000);
      expect(summary.isOverallocated, isFalse);
    },
  );

  test('uses linked received income and flags over-allocation', () {
    final summary = PaydayAllocationCalculator.calculate(
      expectedIncomeMinorUnits: 1_500_000,
      actualReceivedIncomeMinorUnits: 800_000,
      plannedAllocationsMinorUnits: 900_000,
      confirmedPaymentsMinorUnits: 300_000,
    );
    expect(summary.incomeBasisMinorUnits, 800_000);
    expect(summary.unallocatedMinorUnits, 600_000);
    expect(summary.projectedRemainingMinorUnits, -100_000);
    expect(summary.isOverallocated, isTrue);
  });
}
