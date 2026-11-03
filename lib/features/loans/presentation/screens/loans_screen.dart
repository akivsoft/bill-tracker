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

class LoansScreen extends ConsumerWidget {
  const LoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(userPreferencesProvider).asData?.value;
    final String preferredCurrency = preferences?.currencyCode ?? 'PHP';
    final String dateFormat = preferences?.dateFormat ?? 'MM/dd/yyyy';
    final AsyncValue<List<LoanEntry>> loansValue = ref.watch(
      loansOverviewProvider,
    );
    final AsyncValue<List<LoanInstallmentEntry>> installmentsValue = ref.watch(
      installmentsOverviewProvider,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Loans')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: loansValue.when(
              loading: () => const AppLoading(label: 'Loading loans'),
              error: (Object error, StackTrace stackTrace) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text('Loans could not be loaded.'),
                    TextButton.icon(
                      onPressed: () => ref.invalidate(loansOverviewProvider),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
              data: (List<LoanEntry> allLoans) {
                final List<LoanEntry> active = allLoans
                    .where((LoanEntry loan) => loan.status == 'active')
                    .toList(growable: false);
                final int totalOutstanding = active
                    .where(
                      (LoanEntry loan) =>
                          loan.currencyCode == preferredCurrency,
                    )
                    .fold<int>(
                      0,
                      (int sum, LoanEntry loan) =>
                          sum + loan.remainingBalanceMinorUnits,
                    );
                final List<LoanInstallmentEntry> installments =
                    installmentsValue.asData?.value ??
                    const <LoanInstallmentEntry>[];
                final DateTime now = DateTime.now();
                final DateTime today = DateTime(now.year, now.month, now.day);
                final Set<String> activeIds = active
                    .map((LoanEntry loan) => loan.id)
                    .toSet();
                bool isUnpaid(LoanInstallmentEntry item) =>
                    activeIds.contains(item.loanId) &&
                    (item.status == 'unpaid' || item.status == 'partial');
                final List<LoanInstallmentEntry> overdue = installments
                    .where(
                      (LoanInstallmentEntry item) =>
                          isUnpaid(item) && _beforeDay(item.dueDate, today),
                    )
                    .toList(growable: false);
                final List<LoanInstallmentEntry> upcoming =
                    installments
                        .where(
                          (LoanInstallmentEntry item) =>
                              isUnpaid(item) &&
                              !_beforeDay(item.dueDate, today),
                        )
                        .toList(growable: false)
                      ..sort(
                        (LoanInstallmentEntry a, LoanInstallmentEntry b) =>
                            a.dueDate.compareTo(b.dueDate),
                      );
                final Map<String, int> providers = <String, int>{};
                for (final LoanEntry loan in active) {
                  providers.update(
                    loan.providerName,
                    (int count) => count + 1,
                    ifAbsent: () => 1,
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.medium,
                    AppSpacing.small,
                    AppSpacing.medium,
                    AppSpacing.large,
                  ),
                  children: <Widget>[
                    Text(
                      'Loan overview',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.small),
                    Text(
                      'Outstanding totals use the selected currency. Payments are recorded when you confirm them.',
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
                                  label: 'Outstanding loans',
                                  value: Money(
                                    totalOutstanding,
                                    currencyCode: preferredCurrency,
                                  ).format(),
                                  icon: Icons.account_balance_outlined,
                                ),
                                SummaryCard(
                                  label: 'Active loans',
                                  value: active.length.toString(),
                                  icon: Icons.credit_score_outlined,
                                ),
                                SummaryCard(
                                  label: 'Overdue installments',
                                  value: installmentsValue.isLoading
                                      ? '…'
                                      : overdue.length.toString(),
                                  icon: Icons.warning_amber_rounded,
                                ),
                                SummaryCard(
                                  label: 'Upcoming installments',
                                  value: installmentsValue.isLoading
                                      ? '…'
                                      : upcoming.length.toString(),
                                  icon: Icons.event_note_rounded,
                                ),
                              ],
                            );
                          },
                    ),
                    const SizedBox(height: AppSpacing.large),
                    const SectionHeader(title: 'Providers'),
                    const SizedBox(height: AppSpacing.small),
                    if (providers.isEmpty)
                      const AppCard(
                        child: EmptyState(
                          icon: Icons.account_balance_outlined,
                          title: 'No active loans',
                          message:
                              'Loans and providers you add will appear here.',
                        ),
                      )
                    else
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: providers.entries
                              .map(
                                (MapEntry<String, int> provider) => ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.business_outlined),
                                  ),
                                  title: Text(provider.key),
                                  subtitle: Text(
                                    '${provider.value} active ${provider.value == 1 ? 'loan' : 'loans'}',
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    if (active.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.large),
                      const SectionHeader(title: 'Active loans'),
                      const SizedBox(height: AppSpacing.small),
                      ...active.map(
                        (LoanEntry loan) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.small,
                          ),
                          child: AppCard(
                            child: Row(
                              children: <Widget>[
                                CircleAvatar(
                                  child: Text(
                                    loan.providerName.characters.first
                                        .toUpperCase(),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.medium),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        loan.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      Text(loan.providerName),
                                      if (loan.nextDueDate != null)
                                        Text(
                                          'Next due ${DateFormat(dateFormat).format(loan.nextDueDate!)}',
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.small),
                                Text(
                                  Money(
                                    loan.remainingBalanceMinorUnits,
                                    currencyCode: loan.currencyCode,
                                  ).format(),
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (overdue.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.large),
                      const SectionHeader(title: 'Past due installments'),
                      const SizedBox(height: AppSpacing.small),
                      _InstallmentList(
                        installments: overdue.take(5).toList(growable: false),
                        loans: active,
                        dateFormat: dateFormat,
                      ),
                    ],
                    if (upcoming.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.large),
                      const SectionHeader(title: 'Upcoming installments'),
                      const SizedBox(height: AppSpacing.small),
                      _InstallmentList(
                        installments: upcoming.take(6).toList(growable: false),
                        loans: active,
                        dateFormat: dateFormat,
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
}

class _InstallmentList extends StatelessWidget {
  const _InstallmentList({
    required this.installments,
    required this.loans,
    required this.dateFormat,
  });

  final List<LoanInstallmentEntry> installments;
  final List<LoanEntry> loans;
  final String dateFormat;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: installments
          .map((LoanInstallmentEntry installment) {
            final LoanEntry? loan = loans
                .where((LoanEntry item) => item.id == installment.loanId)
                .firstOrNull;
            final int remaining =
                installment.scheduledMinorUnits - installment.paidMinorUnits;
            return ListTile(
              leading: const Icon(Icons.event_note_rounded),
              title: Text(loan?.name ?? 'Loan installment'),
              subtitle: Text(
                '${loan?.providerName ?? ''} · Due ${DateFormat(dateFormat).format(installment.dueDate)}',
              ),
              trailing: Text(
                Money(
                  remaining,
                  currencyCode: loan?.currencyCode ?? 'PHP',
                ).format(),
              ),
            );
          })
          .toList(growable: false),
    ),
  );
}
