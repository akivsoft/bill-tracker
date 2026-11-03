import 'package:bill_tracker/app/theme/app_spacing.dart';
import 'package:bill_tracker/core/utils/money.dart';
import 'package:bill_tracker/core/widgets/account_card.dart';
import 'package:bill_tracker/core/widgets/app_card.dart';
import 'package:bill_tracker/core/widgets/app_loading.dart';
import 'package:bill_tracker/core/widgets/empty_state.dart';
import 'package:bill_tracker/core/widgets/section_header.dart';
import 'package:bill_tracker/core/widgets/summary_card.dart';
import 'package:bill_tracker/features/dashboard/presentation/providers/financial_overview_providers.dart';
import 'package:bill_tracker/features/settings/presentation/providers/user_preferences_provider.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_commands.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_values.dart';
import 'package:bill_tracker/features/transactions/domain/services/financial_calculator.dart';
import 'package:bill_tracker/features/wallets/presentation/widgets/account_entry_sheet.dart';
import 'package:bill_tracker/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String currencyCode =
        ref.watch(userPreferencesProvider).asData?.value.currencyCode ?? 'PHP';
    final AsyncValue<List<FinancialAccount>> accountsValue = ref.watch(
      financialAccountsProvider,
    );
    final AsyncValue<List<AccountBalance>> balancesValue = ref.watch(
      accountBalancesProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallets'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Add account',
            onPressed: () => _addAccount(context, ref, currencyCode),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: accountsValue.when(
              loading: () => const AppLoading(label: 'Loading wallets'),
              error: (Object error, StackTrace stackTrace) => _ErrorState(
                onRetry: () => ref.invalidate(financialAccountsProvider),
              ),
              data: (List<FinancialAccount> allAccounts) {
                final List<FinancialAccount> activeAccounts = allAccounts
                    .where((FinancialAccount account) => account.isActive)
                    .toList(growable: false);
                if (activeAccounts.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(AppSpacing.medium),
                    children: <Widget>[
                      const EmptyState(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'No wallets yet',
                        message:
                            'Add cash, bank, e-wallet, or card accounts to see your balances together.',
                      ),
                      Center(
                        child: FilledButton.icon(
                          onPressed: () =>
                              _addAccount(context, ref, currencyCode),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add an account'),
                        ),
                      ),
                    ],
                  );
                }

                final List<FinancialAccount> selectedCurrencyAccounts =
                    activeAccounts
                        .where(
                          (FinancialAccount account) =>
                              account.currencyCode == currencyCode,
                        )
                        .toList(growable: false);
                final List<AccountBalance> balances =
                    balancesValue.asData?.value ?? const <AccountBalance>[];
                final int available = FinancialCalculator.actualAvailableMoney(
                  balances,
                  currencyCode: currencyCode,
                );
                final int cash = _sum(
                  selectedCurrencyAccounts.where(
                    (FinancialAccount account) => account.accountType == 'cash',
                  ),
                );
                final int bank = _sum(
                  selectedCurrencyAccounts.where(
                    (FinancialAccount account) => <String>{
                      'bank',
                      'savings',
                      'debit_card',
                    }.contains(account.accountType),
                  ),
                );
                final int eWallet = _sum(
                  selectedCurrencyAccounts.where(
                    (FinancialAccount account) => <String>{
                      'e_wallet',
                      'gcash',
                      'maya',
                    }.contains(account.accountType),
                  ),
                );
                final int outstanding = selectedCurrencyAccounts
                    .where(
                      (FinancialAccount account) =>
                          account.accountType == 'credit_card',
                    )
                    .fold<int>(
                      0,
                      (int sum, FinancialAccount account) =>
                          sum + account.outstandingCreditMinorUnits,
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
                      'Balances you track',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.small),
                    Text(
                      'Available money includes active cash and deposit accounts only.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    if (balancesValue.isLoading)
                      const AppCard(
                        child: AppLoading(label: 'Calculating balances'),
                      )
                    else
                      SummaryCard(
                        label: 'Actual available money',
                        value: Money(
                          available,
                          currencyCode: currencyCode,
                        ).format(),
                        icon: Icons.account_balance_wallet_outlined,
                        caption: 'Unused credit is not included.',
                      ),
                    const SizedBox(height: AppSpacing.medium),
                    LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final int columns = constraints.maxWidth > 560
                                ? 2
                                : 1;
                            return GridView.count(
                              crossAxisCount: columns,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: AppSpacing.medium,
                              mainAxisSpacing: AppSpacing.medium,
                              childAspectRatio: columns == 1 ? 2.6 : 1.8,
                              children: <Widget>[
                                SummaryCard(
                                  label: 'Cash',
                                  value: Money(
                                    cash,
                                    currencyCode: currencyCode,
                                  ).format(),
                                  icon: Icons.payments_outlined,
                                ),
                                SummaryCard(
                                  label: 'Bank balances',
                                  value: Money(
                                    bank,
                                    currencyCode: currencyCode,
                                  ).format(),
                                  icon: Icons.account_balance_outlined,
                                ),
                                SummaryCard(
                                  label: 'E-wallets',
                                  value: Money(
                                    eWallet,
                                    currencyCode: currencyCode,
                                  ).format(),
                                  icon: Icons.phone_android_rounded,
                                ),
                                SummaryCard(
                                  label: 'Credit card balances',
                                  value: Money(
                                    outstanding,
                                    currencyCode: currencyCode,
                                  ).format(),
                                  icon: Icons.credit_score_outlined,
                                  caption:
                                      'Shown separately from available money.',
                                ),
                              ],
                            );
                          },
                    ),
                    const SizedBox(height: AppSpacing.large),
                    SectionHeader(
                      title: 'Accounts',
                      actionLabel: 'Add account',
                      onAction: () => _addAccount(context, ref, currencyCode),
                    ),
                    const SizedBox(height: AppSpacing.small),
                    ...activeAccounts.map(
                      (FinancialAccount account) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppSpacing.small,
                        ),
                        child: AccountCard(account: account),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  int _sum(Iterable<FinancialAccount> accounts) => accounts.fold<int>(
    0,
    (int total, FinancialAccount account) =>
        total + account.currentBalanceMinorUnits,
  );

  Future<void> _addAccount(
    BuildContext context,
    WidgetRef ref,
    String currencyCode,
  ) async {
    final CreateAccountInput? input =
        await showModalBottomSheet<CreateAccountInput>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (BuildContext context) =>
              AccountEntrySheet(currencyCode: currencyCode),
        );
    if (input == null) return;
    try {
      await ref.read(financialRepositoryProvider).createAccount(input);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add account: $error')),
        );
      }
    }
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text('Wallets could not be loaded.'),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}
