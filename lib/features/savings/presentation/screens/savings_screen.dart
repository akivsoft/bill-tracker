import 'package:bill_tracker/features/shared/presentation/screens/module_placeholder_screen.dart';
import 'package:flutter/material.dart';

class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context) => const ModulePlaceholderScreen(
    title: 'Savings',
    description: 'Set goals and record your contributions.',
    icon: Icons.savings_outlined,
  );
}
