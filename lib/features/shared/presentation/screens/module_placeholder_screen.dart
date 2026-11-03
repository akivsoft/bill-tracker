import 'package:bill_tracker/app/theme/app_spacing.dart';
import 'package:bill_tracker/core/widgets/empty_state.dart';
import 'package:flutter/material.dart';

class ModulePlaceholderScreen extends StatelessWidget {
  const ModulePlaceholderScreen({
    required this.title,
    required this.description,
    required this.icon,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: EmptyState(
            icon: icon,
            title: 'No records yet',
            message: '$description This section is ready for the next phase.',
          ),
        ),
      ),
    ),
  );
}
