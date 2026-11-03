import 'package:bill_tracker/app/theme/app_spacing.dart';
import 'package:bill_tracker/core/utils/money.dart';
import 'package:bill_tracker/core/widgets/app_card.dart';
import 'package:bill_tracker/core/widgets/app_loading.dart';
import 'package:bill_tracker/core/widgets/empty_state.dart';
import 'package:bill_tracker/core/widgets/section_header.dart';
import 'package:bill_tracker/core/widgets/summary_card.dart';
import 'package:bill_tracker/features/dashboard/presentation/providers/financial_overview_providers.dart';
import 'package:bill_tracker/features/settings/presentation/providers/user_preferences_provider.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(userPreferencesProvider).asData?.value;
    final String currencyCode = preferences?.currencyCode ?? 'PHP';
    final String dateFormat = preferences?.dateFormat ?? 'MM/dd/yyyy';
    final AsyncValue<List<BillEntry>> billsValue = ref.watch(
      billsOverviewProvider,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Bills')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: billsValue.when(
              loading: () => const AppLoading(label: 'Loading bills'),
              error: (Object error, StackTrace stackTrace) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text('Bills could not be loaded.'),
                    TextButton.icon(
                      onPressed: () => ref.invalidate(billsOverviewProvider),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
              data: (List<BillEntry> values) {
                final DateTime now = DateTime.now();
                final DateTime today = DateTime(now.year, now.month, now.day);
                final List<BillEntry> active = values
                    .where((BillEntry bill) => bill.isActive)
                    .toList(growable: false);
                final List<BillEntry> outstanding = active
                    .where(
                      (BillEntry bill) =>
                          bill.status != 'paid' && bill.status != 'cancelled',
                    )
                    .toList(growable: false);
                final List<BillEntry> upcoming =
                    outstanding
                        .where(
                          (BillEntry bill) => !_beforeDay(bill.dueDate, today),
                        )
                        .toList(growable: false)
                      ..sort(
                        (BillEntry a, BillEntry b) =>
                            a.dueDate.compareTo(b.dueDate),
                      );
                final List<BillEntry> overdue = outstanding
                    .where((BillEntry bill) => _beforeDay(bill.dueDate, today))
                    .toList(growable: false);
                final int paidCount = active
                    .where((BillEntry bill) => bill.status == 'paid')
                    .length;
                final int upcomingTotal = upcoming.fold<int>(
                  0,
                  (int sum, BillEntry bill) => sum + bill.amountMinorUnits,
                );

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.medium,
                    AppSpacing.small,
                    AppSpacing.medium,
                    AppSpacing.large,
                  ),
                  children: <Widget>[
                    Text(
                      'Payment overview',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.small),
                    Text(
                      'A due date is a reminder. Your balance changes only when you record a payment.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final int columns = constraints.maxWidth > 500
                                ? 2
                                : 1;
                            return GridView.count(
                              crossAxisCount: columns,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: AppSpacing.medium,
                              mainAxisSpacing: AppSpacing.medium,
                              childAspectRatio: columns == 1 ? 2.5 : 1.8,
                              children: <Widget>[
                                SummaryCard(
                                  label: 'Upcoming bills',
                                  value: upcoming.length.toString(),
                                  icon: Icons.event_note_rounded,
                                  caption: Money(
                                    upcomingTotal,
                                    currencyCode: currencyCode,
                                  ).format(),
                                ),
                                SummaryCard(
                                  label: 'Unpaid',
                                  value: outstanding.length.toString(),
                                  icon: Icons.pending_actions_rounded,
                                ),
                                SummaryCard(
                                  label: 'Paid',
                                  value: paidCount.toString(),
                                  icon: Icons.task_alt_rounded,
                                ),
                                SummaryCard(
                                  label: 'Overdue',
                                  value: overdue.length.toString(),
                                  icon: Icons.warning_amber_rounded,
                                ),
                              ],
                            );
                          },
                    ),
                    const SizedBox(height: AppSpacing.large),
                    const SectionHeader(title: 'Upcoming payments'),
                    const SizedBox(height: AppSpacing.small),
                    if (upcoming.isEmpty)
                      const AppCard(
                        child: EmptyState(
                          icon: Icons.event_available_outlined,
                          title: 'Nothing due soon',
                          message: 'Upcoming bills will appear here.',
                        ),
                      )
                    else
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: upcoming
                              .take(8)
                              .map((BillEntry bill) {
                                final String date = DateFormat(
                                  dateFormat,
                                ).format(bill.dueDate);
                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Icon(
                                      bill.status == 'partial'
                                          ? Icons.timelapse_rounded
                                          : Icons.receipt_long_outlined,
                                    ),
                                  ),
                                  title: Text(bill.name),
                                  subtitle: Text(
                                    'Due $date · ${_statusLabel(bill.status)}',
                                  ),
                                  trailing: Text(
                                    Money(
                                      bill.amountMinorUnits,
                                      currencyCode: bill.currencyCode,
                                    ).format(),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelLarge,
                                  ),
                                );
                              })
                              .toList(growable: false),
                        ),
                      ),
                    if (overdue.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.large),
                      const SectionHeader(title: 'Past due'),
                      const SizedBox(height: AppSpacing.small),
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: overdue
                              .take(5)
                              .map(
                                (BillEntry bill) => ListTile(
                                  leading: const Icon(
                                    Icons.warning_amber_rounded,
                                  ),
                                  title: Text(bill.name),
                                  subtitle: Text(
                                    'Due ${DateFormat(dateFormat).format(bill.dueDate)}',
                                  ),
                                  trailing: Text(
                                    Money(
                                      bill.amountMinorUnits,
                                      currencyCode: bill.currencyCode,
                                    ).format(),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  bool _beforeDay(DateTime date, DateTime day) =>
      DateTime(date.year, date.month, date.day).isBefore(day);

  String _statusLabel(String status) => switch (status) {
    'partial' => 'Partially paid',
    'paid' => 'Paid',
    'cancelled' => 'Cancelled',
    _ => 'Unpaid',
  };
}
