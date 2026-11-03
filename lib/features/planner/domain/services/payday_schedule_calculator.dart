/// Projects payday dates without writing generated dates to the financial ledger.
abstract final class PaydayScheduleCalculator {
  static List<DateTime> occurrences({
    required DateTime anchor,
    required String frequency,
    required DateTime start,
    required DateTime end,
  }) {
    if (end.isBefore(start)) return const <DateTime>[];
    final DateTime first = DateTime(start.year, start.month, start.day);
    final DateTime last = DateTime(end.year, end.month, end.day);
    final DateTime base = DateTime(anchor.year, anchor.month, anchor.day);
    if (frequency == 'irregular' || frequency == 'one_time') {
      return !base.isBefore(first) && !base.isAfter(last)
          ? <DateTime>[base]
          : const <DateTime>[];
    }

    final List<DateTime> dates = <DateTime>[];
    if (frequency == 'twice_monthly') {
      var cursor = DateTime(first.year, first.month);
      while (!cursor.isAfter(last)) {
        for (final int day in <int>[1, 15]) {
          final DateTime date = DateTime(cursor.year, cursor.month, day);
          if (!date.isBefore(base) &&
              !date.isBefore(first) &&
              !date.isAfter(last)) {
            dates.add(date);
          }
        }
        cursor = DateTime(cursor.year, cursor.month + 1);
      }
      return dates;
    }

    DateTime cursor = base;
    while (cursor.isBefore(first)) {
      cursor = _next(cursor, anchor, frequency);
      if (cursor == base) return const <DateTime>[];
    }
    while (!cursor.isAfter(last)) {
      dates.add(cursor);
      final DateTime next = _next(cursor, anchor, frequency);
      if (!next.isAfter(cursor)) break;
      cursor = next;
    }
    return dates;
  }

  static DateTime _next(DateTime date, DateTime anchor, String frequency) {
    switch (frequency) {
      case 'daily':
        return date.add(const Duration(days: 1));
      case 'weekly':
        return date.add(const Duration(days: 7));
      case 'biweekly':
        return date.add(const Duration(days: 14));
      case 'monthly':
        return _monthDate(date.year, date.month + 1, anchor.day);
      case 'quarterly':
        return _monthDate(date.year, date.month + 3, anchor.day);
      case 'yearly':
        return _monthDate(date.year + 1, date.month, anchor.day);
      default:
        return date;
    }
  }

  static DateTime _monthDate(int year, int month, int day) {
    final DateTime first = DateTime(year, month);
    final int lastDay = DateTime(first.year, first.month + 1, 0).day;
    return DateTime(first.year, first.month, day.clamp(1, lastDay));
  }
}
