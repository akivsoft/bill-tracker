import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

abstract final class PaymentRangeFormatter {
  static String label(DateTimeRange range) {
    final DateTime first = DateTime(range.start.year, range.start.month, 1);
    final DateTime last = DateTime(range.start.year, range.start.month + 1, 0);
    if (range.start == first && range.end == last) {
      return DateFormat.yMMMM().format(range.start);
    }
    if (range.start.year == range.end.year &&
        range.start.month == range.end.month) {
      return '${DateFormat.MMMd().format(range.start)}–${DateFormat.d().format(range.end)}, ${range.end.year}';
    }
    return '${DateFormat.yMMMd().format(range.start)} – ${DateFormat.yMMMd().format(range.end)}';
  }
}
