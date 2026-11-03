import 'package:bill_tracker/features/shared/presentation/screens/module_placeholder_screen.dart';
import 'package:flutter/material.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) => const ModulePlaceholderScreen(
    title: 'Calendar',
    description: 'See upcoming bills, paydays, and installments.',
    icon: Icons.calendar_month_rounded,
  );
}
