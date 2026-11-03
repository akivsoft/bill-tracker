import 'package:bill_tracker/features/shared/presentation/screens/module_placeholder_screen.dart';
import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) => const ModulePlaceholderScreen(
    title: 'Notifications',
    description: 'Manage local reminders for payments and scheduled events.',
    icon: Icons.notifications_outlined,
  );
}
