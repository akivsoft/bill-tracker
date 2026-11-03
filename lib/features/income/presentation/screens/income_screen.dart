import 'package:bill_tracker/features/shared/presentation/screens/module_placeholder_screen.dart';
import 'package:flutter/material.dart';

class IncomeScreen extends StatelessWidget {
  const IncomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const ModulePlaceholderScreen(
    title: 'Income',
    description: 'Record paydays and other income sources.',
    icon: Icons.south_west_rounded,
  );
}
