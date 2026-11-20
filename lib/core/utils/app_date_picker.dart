import 'package:flutter/material.dart';

/// Shared date picker entry point so date selection behaves consistently
/// across forms, sheets, and feature screens.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  DatePickerEntryMode? initialEntryMode,
  DatePickerMode initialDatePickerMode = DatePickerMode.day,
  String? helpText,
}) => showDatePicker(
  context: context,
  initialDate: initialDate,
  firstDate: firstDate,
  lastDate: lastDate,
  initialEntryMode: initialEntryMode ?? DatePickerEntryMode.calendar,
  initialDatePickerMode: initialDatePickerMode,
  helpText: helpText,
);

Future<DateTimeRange?> showAppDateRangePicker({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initialDateRange,
}) => showDateRangePicker(
  context: context,
  firstDate: firstDate,
  lastDate: lastDate,
  initialDateRange: initialDateRange,
);

