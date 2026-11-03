final class LoanInstallmentPlan {
  const LoanInstallmentPlan({
    required this.number,
    required this.dueDate,
    required this.amountMinorUnits,
  });

  final int number;
  final DateTime dueDate;
  final int amountMinorUnits;
}

final class LoanScheduleCalculator {
  const LoanScheduleCalculator._();

  static List<LoanInstallmentPlan> generate({
    required DateTime firstDueDate,
    required String frequency,
    required int count,
    required int totalMinorUnits,
    int installmentAmountMinorUnits = 0,
  }) {
    if (count < 1 || totalMinorUnits < count) {
      throw ArgumentError(
        'Schedule needs at least one centavo per installment.',
      );
    }
    final List<LoanInstallmentPlan> schedule = <LoanInstallmentPlan>[];
    final int evenAmount = totalMinorUnits ~/ count;
    final int target = installmentAmountMinorUnits > 0
        ? installmentAmountMinorUnits
        : evenAmount;
    int allocated = 0;
    for (int index = 1; index <= count; index++) {
      final int amount = index == count
          ? totalMinorUnits - allocated
          : target.clamp(1, totalMinorUnits - allocated - (count - index));
      schedule.add(
        LoanInstallmentPlan(
          number: index,
          dueDate: _dateAt(firstDueDate, frequency, index - 1),
          amountMinorUnits: amount,
        ),
      );
      allocated += amount;
    }
    return List<LoanInstallmentPlan>.unmodifiable(schedule);
  }

  static DateTime _dateAt(DateTime anchor, String frequency, int index) {
    final DateTime day = DateTime(anchor.year, anchor.month, anchor.day);
    if (frequency == 'weekly') return day.add(Duration(days: index * 7));
    if (frequency == 'biweekly') return day.add(Duration(days: index * 14));
    if (frequency == 'quarterly') return _addMonths(anchor, index * 3);
    if (frequency == 'monthly') return _addMonths(anchor, index);
    if (frequency.startsWith('custom:')) {
      final int interval = int.tryParse(frequency.substring(7)) ?? 30;
      return day.add(Duration(days: interval * index));
    }
    throw ArgumentError.value(frequency, 'frequency');
  }

  static DateTime _addMonths(DateTime anchor, int count) {
    final int monthIndex = anchor.year * 12 + anchor.month - 1 + count;
    final int year = monthIndex ~/ 12;
    final int month = monthIndex % 12 + 1;
    final int lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, anchor.day.clamp(1, lastDay));
  }
}
