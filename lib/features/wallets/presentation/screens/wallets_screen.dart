import 'package:bill_tracker/app/router/route_names.dart';
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
import 'package:bill_tracker/features/wallets/domain/services/wallet_calculator.dart';
import 'package:bill_tracker/features/wallets/presentation/widgets/account_entry_sheet.dart';
import 'package:bill_tracker/features/wallets/presentation/widgets/wallet_entry_sheet.dart';
import 'package:bill_tracker/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class WalletsScreen extends ConsumerStatefulWidget {
  const WalletsScreen({super.key});

  @override
  ConsumerState<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends ConsumerState<WalletsScreen> {
  String? _currencyCode;
  String _status = 'active';
  WalletAccountGroup _group = WalletAccountGroup.all;
  WalletSortOrder _sort = WalletSortOrder.name;

  @override
  Widget build(BuildContext context) {
    final String preferredCurrency =
        ref.watch(userPreferencesProvider).asData?.value.currencyCode ?? 'PHP';
    final AsyncValue<List<FinancialAccount>> accountsValue = ref.watch(
      walletManagementAccountsProvider,
    );
    final AsyncValue<List<AccountBalance>> balancesValue = ref.watch(
      accountBalancesProvider,
    );
    final List<FinancialAccount> allAccounts =
        accountsValue.asData?.value ?? const <FinancialAccount>[];
    final List<String> currencies = <String>{
      preferredCurrency,
      ...allAccounts.map((FinancialAccount account) => account.currencyCode),
    }.toList()..sort();
    final String currencyCode = currencies.contains(_currencyCode)
        ? _currencyCode!
        : preferredCurrency;
    final List<FinancialAccount> currentCurrencyAccounts = allAccounts
        .where(
          (FinancialAccount account) => account.currencyCode == currencyCode,
        )
        .toList(growable: false);
    final List<FinancialAccount> activeCurrentCurrency = currentCurrencyAccounts
        .where(
          (FinancialAccount account) =>
              account.isActive && account.archivedAt == null,
        )
        .toList(growable: false);
    final List<AccountBalance> balances =
        balancesValue.asData?.value ?? const <AccountBalance>[];
    final int available = FinancialCalculator.actualAvailableMoney(
      balances,
      currencyCode: currencyCode,
    );
    final int cash = _sum(
      activeCurrentCurrency.where(
        (FinancialAccount account) => account.accountType == 'cash',
      ),
    );
    final int bank = _sum(
      activeCurrentCurrency.where(
        (FinancialAccount account) =>
            <String>{
              'bank',
              'savings',
              'debit_card',
            }.contains(account.accountType) &&
            account.linkedAccountId == null,
      ),
    );
    final int wallets = _sum(
      activeCurrentCurrency.where(
        (FinancialAccount account) =>
            <String>{'e_wallet', 'gcash', 'maya'}.contains(account.accountType),
      ),
    );
    final int outstanding = activeCurrentCurrency
        .where(
          (FinancialAccount account) => account.accountType == 'credit_card',
        )
        .fold<int>(
          0,
          (int total, FinancialAccount account) =>
              total + account.outstandingCreditMinorUnits,
        );
    final int availableCredit = activeCurrentCurrency
        .where(
          (FinancialAccount account) => account.accountType == 'credit_card',
        )
        .fold<int>(
          0,
          (int total, FinancialAccount account) =>
              total + WalletCalculator.availableCredit(account),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallets'),
        actions: <Widget>[
          PopupMenuButton<WalletAction>(
            tooltip: 'Wallet actions',
            icon: const Icon(Icons.bolt_rounded),
            onSelected: (WalletAction action) =>
                _openAction(action, allAccounts, currencyCode),
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<WalletAction>>[
                  PopupMenuItem(
                    value: WalletAction.addMoney,
                    child: ListTile(
                      leading: Icon(Icons.south_west_rounded),
                      title: Text('Add money'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: WalletAction.expense,
                    child: ListTile(
                      leading: Icon(Icons.north_east_rounded),
                      title: Text('Record expense'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: WalletAction.transfer,
                    child: ListTile(
                      leading: Icon(Icons.swap_horiz_rounded),
                      title: Text('Transfer money'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: WalletAction.adjustBalance,
                    child: ListTile(
                      leading: Icon(Icons.tune_rounded),
                      title: Text('Adjust balance'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: WalletAction.cardPayment,
                    child: ListTile(
                      leading: Icon(Icons.credit_score_outlined),
                      title: Text('Pay credit card'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
          ),
          IconButton(
            tooltip: 'Add account',
            onPressed: () => _addAccount(allAccounts, currencyCode),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: accountsValue.when(
              loading: () => const AppLoading(label: 'Loading accounts'),
              error: (Object error, StackTrace stackTrace) => _errorState(),
              data: (List<FinancialAccount> accounts) => ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.medium,
                  AppSpacing.small,
                  AppSpacing.medium,
                  AppSpacing.large,
                ),
                children: <Widget>[
                  Text(
                    'Your accounts, clearly separated.',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    'Available money uses actual cash and deposit balances. Credit limits, expected income, and future allocations are excluded.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  Row(
                    children: <Widget>[
                      Text(
                        'Currency',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(width: AppSpacing.small),
                      DropdownButton<String>(
                        value: currencyCode,
                        items: currencies
                            .map(
                              (String code) => DropdownMenuItem<String>(
                                value: code,
                                child: Text(code),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (String? value) =>
                            setState(() => _currencyCode = value),
                      ),
                      const Spacer(),
                      Text(
                        '${activeCurrentCurrency.length} active',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                  if (balancesValue.isLoading)
                    const AppCard(
                      child: AppLoading(label: 'Calculating balances'),
                    )
                  else ...<Widget>[
                    SummaryCard(
                      label: 'Total available money',
                      value: Money(
                        available,
                        currencyCode: currencyCode,
                      ).format(),
                      icon: Icons.account_balance_wallet_outlined,
                      caption: 'Actual balances only',
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final int columns = constraints.maxWidth > 570
                                ? 3
                                : 2;
                            return GridView.count(
                              crossAxisCount: columns,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: AppSpacing.small,
                              mainAxisSpacing: AppSpacing.small,
                              childAspectRatio: columns == 2 ? 1.65 : 1.7,
                              children: <Widget>[
                                _compactSummary(
                                  'Cash',
                                  cash,
                                  currencyCode,
                                  Icons.payments_outlined,
                                ),
                                _compactSummary(
                                  'Bank balances',
                                  bank,
                                  currencyCode,
                                  Icons.account_balance_outlined,
                                ),
                                _compactSummary(
                                  'E-wallets',
                                  wallets,
                                  currencyCode,
                                  Icons.phone_android_rounded,
                                ),
                                _compactSummary(
                                  'Card outstanding',
                                  outstanding,
                                  currencyCode,
                                  Icons.credit_score_outlined,
                                ),
                                _compactSummary(
                                  'Available credit',
                                  availableCredit,
                                  currencyCode,
                                  Icons.credit_card_outlined,
                                ),
                                _compactSummary(
                                  'Active accounts',
                                  activeCurrentCurrency.length,
                                  null,
                                  Icons.wallet_outlined,
                                ),
                              ],
                            );
                          },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.large),
                  SectionHeader(
                    title: _statusTitle,
                    actionLabel: 'Add account',
                    onAction: () => _addAccount(accounts, currencyCode),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  SegmentedButton<String>(
                    segments: const <ButtonSegment<String>>[
                      ButtonSegment(value: 'active', label: Text('Active')),
                      ButtonSegment(value: 'inactive', label: Text('Inactive')),
                      ButtonSegment(value: 'archived', label: Text('Archived')),
                    ],
                    selected: <String>{_status},
                    onSelectionChanged: (Set<String> value) =>
                        setState(() => _status = value.first),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: WalletAccountGroup.values
                          .map(
                            (WalletAccountGroup group) => Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpacing.small,
                              ),
                              child: ChoiceChip(
                                label: Text(_groupLabel(group)),
                                selected: group == _group,
                                onSelected: (_) =>
                                    setState(() => _group = group),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Align(
                    alignment: Alignment.centerRight,
                    child: DropdownButton<WalletSortOrder>(
                      value: _sort,
                      items: const <DropdownMenuItem<WalletSortOrder>>[
                        DropdownMenuItem(
                          value: WalletSortOrder.name,
                          child: Text('Sort: Name'),
                        ),
                        DropdownMenuItem(
                          value: WalletSortOrder.balanceHighToLow,
                          child: Text('Sort: Balance high to low'),
                        ),
                        DropdownMenuItem(
                          value: WalletSortOrder.balanceLowToHigh,
                          child: Text('Sort: Balance low to high'),
                        ),
                      ],
                      onChanged: (WalletSortOrder? value) =>
                          setState(() => _sort = value ?? WalletSortOrder.name),
                    ),
                  ),
                  ..._visibleAccounts(accounts, currencyCode).map(
                    (FinancialAccount account) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.small),
                      child: AccountCard(
                        account: account,
                        onTap: () =>
                            context.push(RouteNames.walletAccount(account.id)),
                      ),
                    ),
                  ),
                  if (_visibleAccounts(accounts, currencyCode).isEmpty)
                    AppCard(
                      child: EmptyState(
                        icon: _status == 'archived'
                            ? Icons.archive_outlined
                            : Icons.account_balance_wallet_outlined,
                        title: _status == 'archived'
                            ? 'No archived accounts'
                            : 'No accounts in this view',
                        message: _status == 'active'
                            ? 'Add cash, a bank account, an e-wallet, or a credit card to get started.'
                            : 'Accounts that match this filter will appear here.',
                        action: _status == 'active'
                            ? FilledButton.icon(
                                onPressed: () =>
                                    _addAccount(accounts, currencyCode),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Add an account'),
                              )
                            : null,
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

  String get _statusTitle => switch (_status) {
    'inactive' => 'Inactive accounts',
    'archived' => 'Archived accounts',
    _ => 'Accounts',
  };

  Widget _compactSummary(
    String label,
    int value,
    String? currency,
    IconData icon,
  ) {
    final String formatted = currency == null
        ? value.toString()
        : Money(value, currencyCode: currency).format();
    return SummaryCard(label: label, value: formatted, icon: icon);
  }

  List<FinancialAccount> _visibleAccounts(
    List<FinancialAccount> accounts,
    String currency,
  ) {
    final List<FinancialAccount> visible = accounts.where((account) {
      if (account.currencyCode != currency) return false;
      final bool matchesStatus = switch (_status) {
        'inactive' => account.archivedAt == null && !account.isActive,
        'archived' => account.archivedAt != null,
        _ => account.archivedAt == null && account.isActive,
      };
      if (!matchesStatus) return false;
      return _matchesGroup(account, _group);
    }).toList();
    visible.sort((FinancialAccount a, FinancialAccount b) {
      final int balanceA = WalletCalculator.accountBalance(a);
      final int balanceB = WalletCalculator.accountBalance(b);
      return switch (_sort) {
        WalletSortOrder.name => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
        WalletSortOrder.balanceHighToLow => balanceB.compareTo(balanceA),
        WalletSortOrder.balanceLowToHigh => balanceA.compareTo(balanceB),
      };
    });
    return visible;
  }

  bool _matchesGroup(FinancialAccount account, WalletAccountGroup group) {
    if (group == WalletAccountGroup.all) return true;
    return switch (group) {
      WalletAccountGroup.cash => account.accountType == 'cash',
      WalletAccountGroup.banks => <String>{
        'bank',
        'savings',
        'debit_card',
      }.contains(account.accountType),
      WalletAccountGroup.eWallets => <String>{
        'gcash',
        'maya',
        'e_wallet',
      }.contains(account.accountType),
      WalletAccountGroup.creditCards => account.accountType == 'credit_card',
      WalletAccountGroup.other => !<String>{
        'cash',
        'bank',
        'savings',
        'debit_card',
        'gcash',
        'maya',
        'e_wallet',
        'credit_card',
      }.contains(account.accountType),
      WalletAccountGroup.all => true,
    };
  }

  String _groupLabel(WalletAccountGroup group) => switch (group) {
    WalletAccountGroup.all => 'All',
    WalletAccountGroup.cash => 'Cash',
    WalletAccountGroup.banks => 'Banks',
    WalletAccountGroup.eWallets => 'E-wallets',
    WalletAccountGroup.creditCards => 'Credit cards',
    WalletAccountGroup.other => 'Other',
  };

  int _sum(Iterable<FinancialAccount> accounts) => accounts.fold<int>(
    0,
    (int total, FinancialAccount account) =>
        total + account.currentBalanceMinorUnits,
  );

  Widget _errorState() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text('Accounts could not be loaded.'),
        TextButton.icon(
          onPressed: () => ref.invalidate(walletManagementAccountsProvider),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ],
    ),
  );

  Future<void> _addAccount(
    List<FinancialAccount> allAccounts,
    String currencyCode,
  ) async {
    final CreateAccountInput? input =
        await showModalBottomSheet<CreateAccountInput>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (BuildContext context) => AccountEntrySheet(
            currencyCode: currencyCode,
            availableAccounts: allAccounts,
          ),
        );
    if (input == null) return;
    try {
      await ref.read(financialRepositoryProvider).createAccount(input);
      if (mounted) _showMessage('Account added.');
    } catch (error) {
      if (mounted) _showMessage('Could not add account: $error');
    }
  }

  Future<void> _openAction(
    WalletAction action,
    List<FinancialAccount> allAccounts,
    String currencyCode,
  ) async {
    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => WalletEntrySheet(
        action: action,
        accounts: allAccounts,
        currencyCode: currencyCode,
      ),
    );
    if (saved == true && mounted) _showMessage('Account activity recorded.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
