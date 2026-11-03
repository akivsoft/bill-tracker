import 'package:bill_tracker/app/theme/app_spacing.dart';
import 'package:bill_tracker/core/utils/money.dart';
import 'package:bill_tracker/core/widgets/account_card.dart';
import 'package:bill_tracker/core/widgets/app_card.dart';
import 'package:bill_tracker/core/widgets/app_loading.dart';
import 'package:bill_tracker/core/widgets/empty_state.dart';
import 'package:bill_tracker/features/dashboard/presentation/providers/financial_overview_providers.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_commands.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_values.dart';
import 'package:bill_tracker/features/transactions/domain/repositories/financial_repository.dart';
import 'package:bill_tracker/features/wallets/domain/services/wallet_calculator.dart';
import 'package:bill_tracker/features/wallets/presentation/widgets/account_edit_sheet.dart';
import 'package:bill_tracker/features/wallets/presentation/widgets/wallet_entry_sheet.dart';
import 'package:bill_tracker/shared/providers/app_providers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class AccountDetailsScreen extends ConsumerStatefulWidget {
  const AccountDetailsScreen({required this.accountId, super.key});

  final String accountId;

  @override
  ConsumerState<AccountDetailsScreen> createState() =>
      _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends ConsumerState<AccountDetailsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  String _typeFilter = 'all';
  String _dateFilter = 'all';
  bool _newestFirst = true;
  BalanceHistoryRange _historyRange = BalanceHistoryRange.monthly;
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<FinancialAccount?> accountValue = ref.watch(
      accountDetailsProvider(widget.accountId),
    );
    final AsyncValue<List<FinancialAccount>> allAccountsValue = ref.watch(
      walletManagementAccountsProvider,
    );
    final AsyncValue<List<FinancialTransactionView>> transactionsValue = ref
        .watch(accountTransactionsProvider(widget.accountId));

    return Scaffold(
      appBar: AppBar(
        title: Text(accountValue.asData?.value?.name ?? 'Account details'),
        actions: <Widget>[
          if (accountValue.asData?.value case final FinancialAccount account)
            IconButton(
              tooltip: 'Edit account',
              onPressed: account.archivedAt == null
                  ? () => _editAccount(account, allAccountsValue)
                  : null,
              icon: const Icon(Icons.edit_outlined),
            ),
          if (accountValue.asData?.value case final FinancialAccount account)
            PopupMenuButton<_AccountAction>(
              tooltip: 'Account options',
              onSelected: (value) => _handleAccountAction(account, value),
              itemBuilder: (context) => <PopupMenuEntry<_AccountAction>>[
                if (account.archivedAt ==
                    null) ...<PopupMenuEntry<_AccountAction>>[
                  PopupMenuItem<_AccountAction>(
                    value: account.isActive
                        ? _AccountAction.deactivate
                        : _AccountAction.activate,
                    child: Text(account.isActive ? 'Deactivate' : 'Activate'),
                  ),
                  const PopupMenuItem<_AccountAction>(
                    value: _AccountAction.archive,
                    child: Text('Archive account'),
                  ),
                ] else ...<PopupMenuEntry<_AccountAction>>[
                  const PopupMenuItem<_AccountAction>(
                    value: _AccountAction.restore,
                    child: Text('Restore account'),
                  ),
                  const PopupMenuItem<_AccountAction>(
                    value: _AccountAction.delete,
                    child: Text('Delete account'),
                  ),
                ],
              ],
            ),
        ],
      ),
      body: accountValue.when(
        loading: () => const AppLoading(label: 'Loading account'),
        error: (Object error, StackTrace stackTrace) => _errorState(),
        data: (FinancialAccount? account) {
          if (account == null) {
            return const Center(
              child: Text('This account is no longer available.'),
            );
          }
          final List<FinancialTransactionView> transactions =
              transactionsValue.asData?.value ??
              const <FinancialTransactionView>[];
          final AccountLedgerSummary summary = WalletCalculator.summarize(
            account,
            transactions,
          );
          final List<FinancialTransactionView> visibleTransactions =
              _filteredTransactions(transactions, account);
          final List<BalanceHistoryPoint> balancePoints =
              WalletCalculator.balanceHistory(
                account,
                transactions,
                range: _historyRange,
                now: DateTime.now(),
                customStart: _customStart,
                customEnd: _customEnd,
              );
          final bool isCreditCard = account.accountType == 'credit_card';

          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.medium,
                    AppSpacing.small,
                    AppSpacing.medium,
                    AppSpacing.large,
                  ),
                  children: <Widget>[
                    AccountCard(account: account),
                    if (!account.isActive || account.archivedAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.small),
                        child: Text(
                          account.archivedAt != null
                              ? 'This account is archived. Restore it to record new activity.'
                              : 'This account is inactive. Activate it to record new activity.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ),
                    if (account.linkedAccountId != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.small),
                      AppCard(
                        child: Text(
                          'This debit card is linked to a deposit account. Its balance and transactions are recorded on that account to prevent double-counting.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.large),
                    _quickActions(account, allAccountsValue),
                    const SizedBox(height: AppSpacing.large),
                    Text(
                      'Balance summary',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.small),
                    _summaryGrid(account, summary),
                    if (isCreditCard) ...<Widget>[
                      const SizedBox(height: AppSpacing.large),
                      _creditCardDetails(account),
                    ],
                    const SizedBox(height: AppSpacing.large),
                    _balanceHistory(account, balancePoints),
                    const SizedBox(height: AppSpacing.large),
                    _transactionHistory(
                      context,
                      account,
                      visibleTransactions,
                      transactions,
                      transactionsValue.isLoading,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _errorState() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text('Account details could not be loaded.'),
        TextButton.icon(
          onPressed: () =>
              ref.invalidate(accountDetailsProvider(widget.accountId)),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ],
    ),
  );

  Widget _quickActions(
    FinancialAccount account,
    AsyncValue<List<FinancialAccount>> accountsValue,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text('Quick actions', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.small),
      Wrap(
        spacing: AppSpacing.small,
        runSpacing: AppSpacing.small,
        children: <Widget>[
          _ActionChip(
            icon: Icons.south_west_rounded,
            label: 'Add money',
            onPressed: () =>
                _openEntry(WalletAction.addMoney, account, accountsValue),
          ),
          _ActionChip(
            icon: Icons.north_east_rounded,
            label: 'Record expense',
            onPressed: () =>
                _openEntry(WalletAction.expense, account, accountsValue),
          ),
          _ActionChip(
            icon: Icons.swap_horiz_rounded,
            label: 'Transfer',
            onPressed: () =>
                _openEntry(WalletAction.transfer, account, accountsValue),
          ),
          _ActionChip(
            icon: Icons.tune_rounded,
            label: 'Adjust balance',
            onPressed: () =>
                _openEntry(WalletAction.adjustBalance, account, accountsValue),
          ),
          if (account.accountType == 'credit_card')
            _ActionChip(
              icon: Icons.payments_outlined,
              label: 'Pay card',
              onPressed: () =>
                  _openEntry(WalletAction.cardPayment, account, accountsValue),
            ),
        ],
      ),
    ],
  );

  Widget _summaryGrid(FinancialAccount account, AccountLedgerSummary summary) {
    final bool card = account.accountType == 'credit_card';
    final int opening = card
        ? account.openingOutstandingCreditMinorUnits
        : account.openingBalanceMinorUnits;
    final List<(String, int, IconData)> items = <(String, int, IconData)>[
      ('Opening balance', opening, Icons.flag_outlined),
      if (!card)
        (
          'Money received',
          summary.moneyReceivedMinorUnits,
          Icons.south_west_rounded,
        ),
      ('Money spent', summary.moneySpentMinorUnits, Icons.north_east_rounded),
      (
        'Transfers received',
        summary.transfersReceivedMinorUnits,
        Icons.call_received_rounded,
      ),
      (
        'Transfers sent',
        summary.transfersSentMinorUnits,
        Icons.call_made_rounded,
      ),
      if (card)
        (
          'Card payments',
          summary.creditCardPaymentsMinorUnits,
          Icons.credit_score_outlined,
        ),
      (
        'Balance adjustments',
        summary.adjustmentsMinorUnits,
        Icons.tune_rounded,
      ),
    ];
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth > 600 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.small,
            mainAxisSpacing: AppSpacing.small,
            childAspectRatio: 1.8,
          ),
          itemBuilder: (BuildContext context, int index) {
            final (String label, int amount, IconData icon) = items[index];
            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: AppSpacing.xSmall),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.xSmall),
                  Text(
                    Money(amount, currencyCode: account.currencyCode).format(),
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _creditCardDetails(FinancialAccount account) {
    final int utilization = WalletCalculator.creditUtilizationBasisPoints(
      account,
    );
    final String percent =
        '${utilization ~/ 100}.${(utilization % 100).toString().padLeft(2, '0')}%';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Credit card details',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.medium),
          _detailLine(
            context,
            'Credit limit',
            Money(
              account.creditLimitMinorUnits,
              currencyCode: account.currencyCode,
            ).format(),
          ),
          _detailLine(
            context,
            'Outstanding balance',
            Money(
              account.outstandingCreditMinorUnits,
              currencyCode: account.currencyCode,
            ).format(),
          ),
          _detailLine(
            context,
            'Available credit',
            Money(
              WalletCalculator.availableCredit(account),
              currencyCode: account.currencyCode,
            ).format(),
          ),
          _detailLine(
            context,
            'Statement balance',
            Money(
              account.statementBalanceMinorUnits,
              currencyCode: account.currencyCode,
            ).format(),
          ),
          _detailLine(
            context,
            'Minimum payment',
            Money(
              account.minimumPaymentMinorUnits,
              currencyCode: account.currencyCode,
            ).format(),
          ),
          _detailLine(
            context,
            'Statement date',
            _dateLabel(account.statementDate),
          ),
          _detailLine(
            context,
            'Payment due date',
            _dateLabel(account.paymentDueDate),
          ),
          const SizedBox(height: AppSpacing.small),
          Text('Credit utilization · $percent'),
          const SizedBox(height: AppSpacing.xSmall),
          LinearProgressIndicator(value: (utilization / 10000).clamp(0, 1)),
        ],
      ),
    );
  }

  Widget _detailLine(BuildContext context, String label, String value) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xSmall),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(label)),
            const SizedBox(width: AppSpacing.small),
            Text(value, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      );

  String _dateLabel(DateTime? date) =>
      date == null ? 'Not set' : DateFormat.yMMMd().format(date.toLocal());

  Widget _balanceHistory(
    FinancialAccount account,
    List<BalanceHistoryPoint> points,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text('Balance history', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.small),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<BalanceHistoryRange>(
          segments: const <ButtonSegment<BalanceHistoryRange>>[
            ButtonSegment(
              value: BalanceHistoryRange.daily,
              label: Text('Daily'),
            ),
            ButtonSegment(
              value: BalanceHistoryRange.weekly,
              label: Text('Weekly'),
            ),
            ButtonSegment(
              value: BalanceHistoryRange.monthly,
              label: Text('Monthly'),
            ),
            ButtonSegment(
              value: BalanceHistoryRange.custom,
              label: Text('Custom'),
            ),
          ],
          selected: <BalanceHistoryRange>{_historyRange},
          onSelectionChanged: (Set<BalanceHistoryRange> values) {
            final BalanceHistoryRange range = values.first;
            if (range == BalanceHistoryRange.custom) {
              _pickHistoryRange();
            } else {
              setState(() => _historyRange = range);
            }
          },
        ),
      ),
      if (points.isEmpty)
        const AppCard(
          child: EmptyState(
            icon: Icons.show_chart_rounded,
            title: 'No balance history yet',
            message:
                'Recorded transactions and adjustments will appear here. No historical balances are estimated.',
          ),
        )
      else
        AppCard(
          child: SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 68,
                      getTitlesWidget: (double value, TitleMeta meta) => Text(
                        Money(
                          (value * 100).round(),
                          currencyCode: account.currencyCode,
                        ).format(),
                        style: Theme.of(context).textTheme.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final int index = value.round();
                        if (index < 0 || index >= points.length) {
                          return const SizedBox.shrink();
                        }
                        if (points.length > 5 &&
                            index != 0 &&
                            index != points.length - 1 &&
                            index % (points.length ~/ 4) != 0) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat.Md().format(points[index].date),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: <LineChartBarData>[
                  LineChartBarData(
                    spots: points.indexed
                        .map(
                          ((int, BalanceHistoryPoint) item) => FlSpot(
                            item.$1.toDouble(),
                            item.$2.balanceMinorUnits / 100,
                          ),
                        )
                        .toList(growable: false),
                    isCurved: false,
                    barWidth: 3,
                    color: Theme.of(context).colorScheme.primary,
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );

  Future<void> _pickHistoryRange() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
        start: _customStart ?? now.subtract(const Duration(days: 30)),
        end: _customEnd ?? now,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _customStart = selected.start;
      _customEnd = selected.end;
      _historyRange = BalanceHistoryRange.custom;
    });
  }

  Widget _transactionHistory(
    BuildContext context,
    FinancialAccount account,
    List<FinancialTransactionView> visible,
    List<FinancialTransactionView> all,
    bool loading,
  ) {
    final List<String> types =
        all
            .map((FinancialTransactionView transaction) => transaction.type)
            .toSet()
            .toList()
          ..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Transaction history',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.small),
        TextField(
          controller: _searchController,
          onChanged: (String value) => setState(() => _search = value),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            labelText: 'Search transactions',
            suffixIcon: _search.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () => setState(() {
                      _searchController.clear();
                      _search = '';
                    }),
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        Wrap(
          spacing: AppSpacing.small,
          runSpacing: AppSpacing.small,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            DropdownButton<String>(
              value: _typeFilter,
              hint: const Text('Transaction type'),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(
                  value: 'all',
                  child: Text('All types'),
                ),
                ...types.map(
                  (String type) => DropdownMenuItem<String>(
                    value: type,
                    child: Text(_transactionTypeLabel(type)),
                  ),
                ),
              ],
              onChanged: (String? value) =>
                  setState(() => _typeFilter = value ?? 'all'),
            ),
            DropdownButton<String>(
              value: _dateFilter,
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'all', child: Text('All dates')),
                DropdownMenuItem(value: '30', child: Text('Last 30 days')),
                DropdownMenuItem(value: 'year', child: Text('This year')),
                DropdownMenuItem(value: 'custom', child: Text('Custom range')),
              ],
              onChanged: (String? value) {
                if (value == 'custom') {
                  _pickTransactionDateRange();
                } else {
                  setState(() => _dateFilter = value ?? 'all');
                }
              },
            ),
            TextButton.icon(
              onPressed: () => setState(() => _newestFirst = !_newestFirst),
              icon: Icon(
                _newestFirst ? Icons.south_rounded : Icons.north_rounded,
              ),
              label: Text(_newestFirst ? 'Newest first' : 'Oldest first'),
            ),
          ],
        ),
        if (loading)
          const AppLoading(label: 'Loading transactions')
        else if (visible.isEmpty)
          AppCard(
            child: EmptyState(
              icon: Icons.receipt_long_outlined,
              title: all.isEmpty ? 'No transactions yet' : 'No matches found',
              message: all.isEmpty
                  ? 'Income, expenses, transfers, and adjustments for this account will appear here.'
                  : 'Change the search or filters to see more activity.',
            ),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                for (
                  int index = 0;
                  index < visible.length;
                  index++
                ) ...<Widget>[
                  _transactionTile(account, visible[index]),
                  if (index < visible.length - 1)
                    const Divider(height: 1, indent: 72, endIndent: 16),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _transactionTile(
    FinancialAccount account,
    FinancialTransactionView transaction,
  ) {
    final String subtitle = <String>[
      _transactionTypeLabel(transaction.type),
      transaction.category ?? 'Uncategorized',
      DateFormat.yMMMd().format(transaction.occurredAt.toLocal()),
    ].join(' · ');
    final IconData icon = switch (transaction.type) {
      'income' => Icons.south_west_rounded,
      'expense' || 'credit_card_purchase' => Icons.north_east_rounded,
      'account_transfer' || 'credit_card_payment' => Icons.swap_horiz_rounded,
      'balance_adjustment' => Icons.tune_rounded,
      'reversal' => Icons.undo_rounded,
      _ => Icons.receipt_long_outlined,
    };
    return ListTile(
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(transaction.title),
      subtitle: Text(subtitle),
      trailing: Text(
        Money(
          transaction.amountMinorUnits,
          currencyCode: account.currencyCode,
        ).format(),
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }

  List<FinancialTransactionView> _filteredTransactions(
    List<FinancialTransactionView> transactions,
    FinancialAccount account,
  ) {
    final DateTime now = DateTime.now();
    final DateTime? since = switch (_dateFilter) {
      '30' => now.subtract(const Duration(days: 30)),
      'year' => DateTime(now.year),
      'custom' => _customStart,
      _ => null,
    };
    final DateTime? until = _dateFilter == 'custom' ? _customEnd : null;
    final String query = _search.trim().toLowerCase();
    final List<FinancialTransactionView> output = transactions.where((item) {
      if (_typeFilter != 'all' && item.type != _typeFilter) return false;
      if (since != null && item.occurredAt.isBefore(since)) return false;
      if (until != null &&
          item.occurredAt.isAfter(until.add(const Duration(days: 1)))) {
        return false;
      }
      if (query.isEmpty) return true;
      return <String>[
        item.title,
        item.category ?? '',
        item.description ?? '',
        item.notes ?? '',
      ].any((String value) => value.toLowerCase().contains(query));
    }).toList();
    output.sort((FinancialTransactionView a, FinancialTransactionView b) {
      final int order = a.occurredAt.compareTo(b.occurredAt);
      return _newestFirst ? -order : order;
    });
    return output;
  }

  Future<void> _pickTransactionDateRange() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
        start: _customStart ?? now.subtract(const Duration(days: 30)),
        end: _customEnd ?? now,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _customStart = selected.start;
      _customEnd = selected.end;
      _dateFilter = 'custom';
    });
  }

  Future<void> _openEntry(
    WalletAction action,
    FinancialAccount account,
    AsyncValue<List<FinancialAccount>> accountsValue,
  ) async {
    if (!account.isActive || account.archivedAt != null) {
      _showMessage('Activate this account before recording transactions.');
      return;
    }
    final List<FinancialAccount> accounts =
        accountsValue.asData?.value ?? <FinancialAccount>[account];
    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => WalletEntrySheet(
        action: action,
        accounts: accounts,
        currencyCode: account.currencyCode,
        preselectedAccountId: account.id,
      ),
    );
    if (saved == true && mounted) _showMessage('Account activity recorded.');
  }

  Future<void> _editAccount(
    FinancialAccount account,
    AsyncValue<List<FinancialAccount>> accountsValue,
  ) async {
    final UpdateAccountInput? input =
        await showModalBottomSheet<UpdateAccountInput>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (BuildContext context) => AccountEditSheet(
            account: account,
            availableAccounts:
                accountsValue.asData?.value ?? <FinancialAccount>[account],
          ),
        );
    if (input == null) return;
    try {
      await ref.read(financialRepositoryProvider).updateAccount(input);
      if (mounted) _showMessage('Account details saved.');
    } catch (error) {
      if (mounted) _showMessage('Could not update this account: $error');
    }
  }

  Future<void> _handleAccountAction(
    FinancialAccount account,
    _AccountAction action,
  ) async {
    final String actionName = switch (action) {
      _AccountAction.activate => 'activate',
      _AccountAction.deactivate => 'deactivate',
      _AccountAction.archive => 'archive',
      _AccountAction.restore => 'restore',
      _AccountAction.delete => 'permanently delete',
    };
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(
          '${actionName[0].toUpperCase()}${actionName.substring(1)} account?',
        ),
        content: Text(
          action == _AccountAction.delete
              ? 'An account can be deleted only when it has no history or linked records. Transactions are never deleted with an account.'
              : 'Are you sure you want to $actionName ${account.name}?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(actionName[0].toUpperCase() + actionName.substring(1)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final FinancialRepository repository = ref.read(
        financialRepositoryProvider,
      );
      switch (action) {
        case _AccountAction.activate:
          await repository.setAccountActive(account.id, true);
        case _AccountAction.deactivate:
          await repository.setAccountActive(account.id, false);
        case _AccountAction.archive:
          await repository.archiveAccount(account.id);
        case _AccountAction.restore:
          await repository.restoreAccount(account.id);
        case _AccountAction.delete:
          await repository.deleteAccount(account.id);
          if (mounted) context.pop();
      }
      if (mounted && action != _AccountAction.delete) {
        _showMessage('Account ${actionName}d.');
      }
    } catch (error) {
      if (mounted) _showMessage('Could not $actionName this account: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _transactionTypeLabel(String type) => switch (type) {
    'income' => 'Income',
    'expense' => 'Expense',
    'account_transfer' => 'Transfer',
    'credit_card_purchase' => 'Card purchase',
    'credit_card_payment' => 'Card payment',
    'bill_payment' => 'Bill payment',
    'loan_payment' => 'Loan payment',
    'balance_adjustment' => 'Balance adjustment',
    'reversal' => 'Reversal',
    'savings_contribution' => 'Savings contribution',
    _ => type.replaceAll('_', ' '),
  };
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Icon(icon, size: 18),
    label: Text(label),
    onPressed: onPressed,
  );
}

enum _AccountAction { activate, deactivate, archive, restore, delete }
