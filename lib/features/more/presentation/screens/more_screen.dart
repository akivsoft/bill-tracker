import 'package:bill_tracker/app/router/route_names.dart';
import 'package:bill_tracker/app/theme/app_spacing.dart';
import 'package:bill_tracker/core/widgets/app_card.dart';
import 'package:bill_tracker/features/authentication/domain/entities/auth_session.dart';
import 'package:bill_tracker/features/authentication/presentation/providers/authentication_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  static const List<_MoreDestination> _destinations = <_MoreDestination>[
    _MoreDestination(
      'Income',
      'Paydays and other income',
      Icons.south_west_rounded,
      'income',
    ),
    _MoreDestination(
      'Expenses',
      'Spending and categories',
      Icons.north_east_rounded,
      'expenses',
    ),
    _MoreDestination(
      'Planner',
      'Plan paydays and allocations',
      Icons.event_note_rounded,
      'planner',
    ),
    _MoreDestination(
      'Calendar',
      'Bills, paydays, and installments',
      Icons.calendar_month_rounded,
      'calendar',
    ),
    _MoreDestination(
      'Savings',
      'Goals and contributions',
      Icons.savings_outlined,
      'savings',
    ),
    _MoreDestination(
      'Reports',
      'Monthly and yearly summaries',
      Icons.insert_chart_outlined_rounded,
      'reports',
    ),
    _MoreDestination(
      'Transactions',
      'Confirmed account activity',
      Icons.receipt_long_outlined,
      'transactions',
    ),
    _MoreDestination(
      'Notifications',
      'Reminder preferences',
      Icons.notifications_none_rounded,
      'notifications',
    ),
    _MoreDestination(
      'Settings',
      'Preferences and data security',
      Icons.settings_outlined,
      'settings',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthenticationState auth = ref.watch(authenticationProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.medium),
            children: <Widget>[
              AppCard(
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      child: Icon(
                        auth.isAuthenticated
                            ? Icons.cloud_done_outlined
                            : Icons.phone_iphone_rounded,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.medium),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            auth.isAuthenticated
                                ? 'Supabase account'
                                : 'Local-only mode',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            auth.email ?? 'Your records stay on this device.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: auth.isLoading
                          ? null
                          : () async {
                              if (auth.isAuthenticated) {
                                await ref
                                    .read(authenticationProvider.notifier)
                                    .signOut();
                              } else {
                                context.push(RouteNames.authenticationPath);
                              }
                            },
                      child: Text(
                        auth.isAuthenticated ? 'Sign out' : 'Sign in',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.large),
              Text(
                'Manage your money',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.small),
              Text(
                'Choose a section to explore. You can add real records as each module is built.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    for (
                      int index = 0;
                      index < _destinations.length;
                      index++
                    ) ...<Widget>[
                      _DestinationTile(destination: _destinations[index]),
                      if (index < _destinations.length - 1)
                        const Divider(height: 1, indent: 64, endIndent: 16),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({required this.destination});

  final _MoreDestination destination;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
      child: Icon(destination.icon),
    ),
    title: Text(destination.title),
    subtitle: Text(destination.subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () => context.go(RouteNames.moreModule(destination.slug)),
  );
}

class _MoreDestination {
  const _MoreDestination(this.title, this.subtitle, this.icon, this.slug);

  final String title;
  final String subtitle;
  final IconData icon;
  final String slug;
}
