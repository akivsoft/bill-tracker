import 'package:bill_tracker/features/shared/presentation/screens/module_placeholder_screen.dart';
import 'package:flutter/material.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) => const ModulePlaceholderScreen(
    title: 'Expenses',
    description: 'Track spending against your monthly plan.',
    icon: Icons.north_east_rounded,
  );
}
