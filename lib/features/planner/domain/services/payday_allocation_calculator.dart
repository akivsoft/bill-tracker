final class PaydayAllocationSummary {
  const PaydayAllocationSummary({
    required this.incomeBasisMinorUnits,
    required this.plannedAllocationsMinorUnits,
    required this.confirmedPaymentsMinorUnits,
    required this.unallocatedMinorUnits,
    required this.projectedRemainingMinorUnits,
    required this.isOverallocated,
  });

  final int incomeBasisMinorUnits;
  final int plannedAllocationsMinorUnits;
  final int confirmedPaymentsMinorUnits;
  final int unallocatedMinorUnits;
  final int projectedRemainingMinorUnits;
  final bool isOverallocated;
}

abstract final class PaydayAllocationCalculator {
  static PaydayAllocationSummary calculate({
    required int expectedIncomeMinorUnits,
    required int actualReceivedIncomeMinorUnits,
    required int plannedAllocationsMinorUnits,
    required int confirmedPaymentsMinorUnits,
  }) {
    final int incomeBasis = actualReceivedIncomeMinorUnits > 0
        ? actualReceivedIncomeMinorUnits
        : expectedIncomeMinorUnits;
    final int remaining = incomeBasis - plannedAllocationsMinorUnits;
    return PaydayAllocationSummary(
      incomeBasisMinorUnits: incomeBasis,
      plannedAllocationsMinorUnits: plannedAllocationsMinorUnits,
      confirmedPaymentsMinorUnits: confirmedPaymentsMinorUnits,
      unallocatedMinorUnits:
          expectedIncomeMinorUnits - plannedAllocationsMinorUnits,
      projectedRemainingMinorUnits: remaining,
      isOverallocated: remaining < 0,
    );
  }
}
