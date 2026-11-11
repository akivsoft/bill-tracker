import 'package:bill_tracker/app/router/route_names.dart';
import 'package:bill_tracker/app/theme/app_spacing.dart';
import 'package:bill_tracker/core/utils/money.dart';
import 'package:bill_tracker/core/widgets/account_card.dart';
import 'package:bill_tracker/core/widgets/app_card.dart';
import 'package:bill_tracker/core/widgets/app_loading.dart';
import 'package:bill_tracker/core/widgets/empty_state.dart';
import 'package:bill_tracker/core/widgets/summary_card.dart';
import 'package:bill_tracker/features/dashboard/presentation/providers/financial_overview_providers.dart';
import 'package:bill_tracker/features/dashboard/presentation/providers/dashboard_section_state_provider.dart';
import 'package:bill_tracker/features/dashboard/presentation/widgets/financial_analytics_panel.dart';
import 'package:bill_tracker/features/settings/domain/entities/user_preferences.dart';
import 'package:bill_tracker/features/settings/presentation/providers/user_preferences_provider.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_values.dart';
import 'package:bill_tracker/features/transactions/domain/services/financial_calculator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserPreferences? preferences = ref
        .watch(userPreferencesProvider)
        .asData
        ?.value;
    final String currencyCode = preferences?.currencyCode ?? 'PHP';
    final AsyncValue<List<FinancialAccount>> accounts = ref.watch(
      financialAccountsProvider,
    );
    final AsyncValue<List<BillEntry>> bills = ref.watch(billsOverviewProvider);
    final AsyncValue<List<LoanEntry>> loans = ref.watch(loansOverviewProvider);
    final AsyncValue<List<FinancialTransactionView>> transactions = ref.watch(
      dashboardRecentTransactionsProvider,
    );
    final Map<String, bool> sectionStates = ref.watch(
      dashboardSectionStateProvider,
    );
    final bool accountsExpanded = sectionStates['yourAccounts'] ?? true;
    final bool activityExpanded = sectionStates['recentActivity'] ?? true;
    final int accountCount =
        accounts.asData?.value
            .where((FinancialAccount item) => item.isActive)
            .length ??
        0;
    final int activityCount = transactions.asData?.value.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MyFinance'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.go(RouteNames.moreModule('settings')),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(financialAccountsProvider);
                ref.invalidate(accountBalancesProvider);
                ref.invalidate(incomeOverviewProvider);
                ref.invalidate(expensesOverviewProvider);
                ref.invalidate(billsOverviewProvider);
                ref.invalidate(billPaymentsOverviewProvider);
                ref.invalidate(loansOverviewProvider);
                ref.invalidate(installmentsOverviewProvider);
                ref.invalidate(loanPaymentsOverviewProvider);
                ref.invalidate(savingsGoalsOverviewProvider);
                ref.invalidate(paydaySchedulesProvider);
                ref.invalidate(dashboardRecentTransactionsProvider);
                try {
                  await ref.read(dashboardRecentTransactionsProvider.future);
                } catch (_) {
                  // The normal stream error states remain visible after refresh.
                }
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.medium,
                  AppSpacing.small,
                  AppSpacing.medium,
                  AppSpacing.large,
                ),
                children: <Widget>[
                  Text(
                    _greeting(preferences?.displayName),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xSmall),
                  Text(
                    'Your money, bills, and commitments in one place.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.large),
                  _AvailableMoneyCard(
                    currencyCode: currencyCode,
                    onTap: () => context.go(RouteNames.walletsPath),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  FinancialAnalyticsPanel(currencyCode: currencyCode),
                  const SizedBox(height: AppSpacing.medium),
                  LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          const double gap = AppSpacing.small;
                          const int columns = 3;
                          final double tileWidth =
                              (constraints.maxWidth - gap * (columns - 1)) /
                              columns;
                          return GridView.count(
                            crossAxisCount: columns,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: gap,
                            mainAxisSpacing: gap,
                            childAspectRatio: tileWidth / 112,
                            children: <Widget>[
                              _QuickSummary(
                                value: bills.when(
                                  data: (List<BillEntry> value) => value
                                      .where(
                                        (BillEntry bill) =>
                                            bill.isActive &&
                                            bill.status != 'paid' &&
                                            bill.status != 'cancelled',
                                      )
                                      .length
                                      .toString(),
                                  loading: () => '…',
                                  error: (_, _) => '—',
                                ),
                                label: 'Open bills',
                                icon: Icons.receipt_long_outlined,
                                onTap: () => context.go(RouteNames.billsPath),
                              ),
                              _QuickSummary(
                                value: loans.when(
                                  data: (List<LoanEntry> value) => value
                                      .where(
                                        (LoanEntry loan) =>
                                            loan.status == 'active',
                                      )
                                      .length
                                      .toString(),
                                  loading: () => '…',
                                  error: (_, _) => '—',
                                ),
                                label: 'Active loans',
                                icon: Icons.credit_score_outlined,
                                onTap: () => context.go(RouteNames.loansPath),
                              ),
                              _QuickSummary(
                                value: accounts.when(
                                  data: (List<FinancialAccount> value) => value
                                      .where(
                                        (FinancialAccount account) =>
                                            account.isActive,
                                      )
                                      .length
                                      .toString(),
                                  loading: () => '…',
                                  error: (_, _) => '—',
                                ),
                                label: 'Active accounts',
                                icon: Icons.account_balance_wallet_outlined,
                                onTap: () => context.go(RouteNames.walletsPath),
                              ),
                            ],
                          );
                        },
                  ),
                  const SizedBox(height: AppSpacing.large),
                  _sectionHeader(
                    context,
                    ref,
                    sectionId: 'yourAccounts',
                    title: 'Your accounts',
                    summary: '$accountCount active accounts',
                    actionLabel: 'All wallets',
                    onAction: () => context.go(RouteNames.walletsPath),
                    expanded: accountsExpanded,
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: accountsExpanded
                        ? Padding(
                            padding: const EdgeInsets.only(
                              top: AppSpacing.small,
                            ),
                            child: accounts.when(
                              loading: () =>
                                  const AppLoading(label: 'Loading accounts'),
                              error: (Object error, StackTrace stackTrace) =>
                                  _InlineError(
                                    message: 'Accounts could not be loaded.',
                                    onRetry: () => ref.invalidate(
                                      financialAccountsProvider,
                                    ),
                                  ),
                              data: (List<FinancialAccount> values) {
                                final List<FinancialAccount> active = values
                                    .where(
                                      (FinancialAccount account) =>
                                          account.isActive,
                                    )
                                    .take(2)
                                    .toList(growable: false);
                                if (active.isEmpty) {
                                  return AppCard(
                                    child: EmptyState(
                                      icon: Icons.wallet_outlined,
                                      title: 'Start with an account',
                                      message:
                                          'Add a cash, bank, or e-wallet balance to see your available money.',
                                      action: TextButton.icon(
                                        onPressed: () =>
                                            context.go(RouteNames.walletsPath),
                                        icon: const Icon(Icons.add_rounded),
                                        label: const Text('Open wallets'),
                                      ),
                                    ),
                                  );
                                }
                                return Column(
                                  children: active
                                      .map(
                                        (FinancialAccount account) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: AppSpacing.small,
                                          ),
                                          child: AccountCard(account: account),
                                        ),
                                      )
                                      .toList(growable: false),
                                );
                              },
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: AppSpacing.large),
                  _sectionHeader(
                    context,
                    ref,
                    sectionId: 'recentActivity',
                    title: 'Recent activity',
                    summary: '$activityCount recent transactions',
                    actionLabel: 'Transactions',
                    onAction: () =>
                        context.go(RouteNames.moreModule('transactions')),
                    expanded: activityExpanded,
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: activityExpanded
                        ? Padding(
                            padding: const EdgeInsets.only(
                              top: AppSpacing.small,
                            ),
                            child: transactions.when(
                              loading: () =>
                                  const AppLoading(label: 'Loading activity'),
                              error: (Object error, StackTrace stackTrace) =>
                                  _InlineError(
                                    message:
                                        'Recent activity could not be loaded.',
                                    onRetry: () => ref.invalidate(
                                      recentTransactionsProvider,
                                    ),
                                  ),
                              data: (List<FinancialTransactionView> values) {
                                if (values.isEmpty) {
                                  return const AppCard(
                                    child: EmptyState(
                                      icon: Icons.receipt_long_outlined,
                                      title: 'No activity yet',
                                      message:
                                          'Confirmed income and payments will appear here.',
                                    ),
                                  );
                                }
                                return AppCard(
                                  padding: EdgeInsets.zero,
                                  child: Column(
                                    children: values
                                        .take(4)
                                        .map((
                                          FinancialTransactionView transaction,
                                        ) {
                                          final bool isIncome = <String>{
                                            'income',
                                            'transfer_in',
                                          }.contains(transaction.type);
                                          final String sign = isIncome
                                              ? '+'
                                              : '−';
                                          return ListTile(
                                            leading: CircleAvatar(
                                              child: Icon(
                                                _transactionIcon(
                                                  transaction.type,
                                                ),
                                              ),
                                            ),
                                            title: Text(transaction.title),
                                            subtitle: Text(
                                              '${_labelForTransaction(transaction.type)} · ${_accountName(accounts.asData?.value ?? const <FinancialAccount>[], transaction.sourceAccountId ?? transaction.destinationAccountId)} · ${DateFormat.yMMMd().format(transaction.occurredAt.toLocal())}',
                                            ),
                                            trailing: Text(
                                              '$sign${Money(transaction.amountMinorUnits, currencyCode: transaction.currencyCode).format()}',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.labelLarge,
                                            ),
                                            onTap: () => context.go(
                                              RouteNames.moreModule(
                                                'transactions',
                                              ),
                                            ),
                                          );
                                        })
                                        .toList(growable: false),
                                  ),
                                );
                              },
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  AppCard(
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.offline_bolt_outlined,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(width: AppSpacing.medium),
                        Expanded(
                          child: Text(
                            'Your records are stored on this device. Online account access is optional.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext context,
    WidgetRef ref, {
    required String sectionId,
    required String title,
    required String summary,
    required String actionLabel,
    required VoidCallback onAction,
    required bool expanded,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: InkWell(
              onTap: () => ref
                  .read(dashboardSectionStateProvider.notifier)
                  .toggle(sectionId),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          ),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
          IconButton(
            tooltip: expanded ? 'Collapse $title' : 'Expand $title',
            onPressed: () => ref
                .read(dashboardSectionStateProvider.notifier)
                .toggle(sectionId),
            icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
          ),
        ],
      ),
      if (!expanded)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.small),
          child: Text(summary, style: Theme.of(context).textTheme.bodySmall),
        ),
    ],
  );

  String _greeting(String? name) => name == null || name.trim().isEmpty
      ? 'Welcome to MyFinance'
      : 'Welcome, ${name.trim()}';

  IconData _transactionIcon(String type) => switch (type) {
    'income' => Icons.south_west_rounded,
    'expense' || 'credit_card_purchase' => Icons.north_east_rounded,
    'bill_payment' => Icons.receipt_long_outlined,
    'loan_payment' => Icons.credit_score_outlined,
    'account_transfer' => Icons.swap_horiz_rounded,
    _ => Icons.sync_alt_rounded,
  };

  String _labelForTransaction(String type) => type.replaceAll('_', ' ');

  String _accountName(List<FinancialAccount> accounts, String? id) =>
      accounts
          .where((FinancialAccount account) => account.id == id)
          .map((FinancialAccount account) => account.name)
          .firstOrNull ??
      'Account';
}

class _AvailableMoneyCard extends ConsumerWidget {
  const _AvailableMoneyCard({required this.currencyCode, this.onTap});

  final String currencyCode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AccountBalance>> balances = ref.watch(
      accountBalancesProvider,
    );
    return balances.when(
      loading: () => const AppCard(
        child: AppLoading(label: 'Calculating available money'),
      ),
      error: (Object error, StackTrace stackTrace) => _InlineError(
        message: 'Balance summary is unavailable.',
        onRetry: () => ref.invalidate(accountBalancesProvider),
      ),
      data: (List<AccountBalance> values) {
        final int available = FinancialCalculator.actualAvailableMoney(
          values,
          currencyCode: currencyCode,
        );
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          child: SummaryCard(
            label: 'Actual available money',
            value: Money(available, currencyCode: currencyCode).format(),
            icon: Icons.account_balance_wallet_outlined,
            caption: 'Credit limits and expected income are excluded.',
          ),
        );
      },
    );
  }
}

class _QuickSummary extends StatelessWidget {
  const _QuickSummary({
    required this.value,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.small),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, color: colors.primary, size: 18),
                  const Spacer(),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      children: <Widget>[
        Expanded(child: Text(message)),
        IconButton(
          tooltip: 'Retry',
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
  );
}
