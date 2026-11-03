import 'package:bill_tracker/app/theme/app_spacing.dart';
import 'package:bill_tracker/core/utils/money.dart';
import 'package:bill_tracker/core/validators/money_input_parser.dart';
import 'package:bill_tracker/features/dashboard/presentation/providers/financial_overview_providers.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_commands.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_values.dart';
import 'package:bill_tracker/features/transactions/domain/repositories/financial_repository.dart';
import 'package:bill_tracker/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class IncomeScreen extends ConsumerStatefulWidget {
  const IncomeScreen({super.key});

  @override
  ConsumerState<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends ConsumerState<IncomeScreen> {
  final TextEditingController _search = TextEditingController();
  String _status = 'all';
  String _period = 'month';
  static const Uuid _uuid = Uuid();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final incomes = ref.watch(incomeOverviewProvider);
    final transactions = ref.watch(recentTransactionsProvider);
    final accounts = ref.watch(walletManagementAccountsProvider);
    final incomeRows = incomes.asData?.value ?? const <IncomeEntry>[];
    final now = DateTime.now();
    final DateTimeRange range = _range(now);
    final selected = incomeRows.where((IncomeEntry item) {
      final DateTime date = item.status == 'received'
          ? item.actualReceivedAt ?? item.expectedDate
          : item.expectedDate;
      return !date.isBefore(range.start) &&
          date.isBefore(range.end.add(const Duration(days: 1)));
    });
    final int received = selected
        .where((IncomeEntry item) => item.status == 'received')
        .fold<int>(
          0,
          (int sum, IncomeEntry item) => sum + item.amountMinorUnits,
        );
    final int expected = selected
        .where((IncomeEntry item) => item.status == 'expected')
        .fold<int>(
          0,
          (int sum, IncomeEntry item) => sum + item.amountMinorUnits,
        );
    final String query = _search.text.trim().toLowerCase();
    final List<IncomeEntry> visible = incomeRows
        .where((IncomeEntry item) {
          final bool statusMatches =
              _status == 'all' ||
              item.status == _status ||
              (_status == 'overdue' && _isOverdue(item, now));
          return statusMatches &&
              (query.isEmpty || item.source.toLowerCase().contains(query));
        })
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Income'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Add income',
            onPressed: () =>
                _editIncome(accounts.asData?.value ?? const [], null),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editIncome(accounts.asData?.value ?? const [], null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add income'),
      ),
      body: incomes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) =>
            _message('Income records could not be loaded.'),
        data: (_) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.medium,
            AppSpacing.medium,
            AppSpacing.medium,
            100,
          ),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _summary(
                    'Received',
                    received,
                    Icons.check_circle_outline,
                  ),
                ),
                const SizedBox(width: AppSpacing.small),
                Expanded(
                  child: _summary(
                    'Expected',
                    expected,
                    Icons.schedule_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.small),
            Align(
              alignment: Alignment.centerRight,
              child: DropdownButton<String>(
                value: _period,
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'day', child: Text('Today')),
                  DropdownMenuItem(value: 'week', child: Text('This week')),
                  DropdownMenuItem(value: 'month', child: Text('This month')),
                  DropdownMenuItem(
                    value: 'quarter',
                    child: Text('This quarter'),
                  ),
                  DropdownMenuItem(value: 'year', child: Text('This year')),
                  DropdownMenuItem(
                    value: 'custom',
                    child: Text('Custom dates'),
                  ),
                ],
                onChanged: (String? value) async {
                  if (value == 'custom') {
                    final DateTimeRange? custom = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (custom != null && mounted) {
                      setState(() => _customRange = custom);
                    }
                  }
                  if (value != null) setState(() => _period = value);
                },
              ),
            ),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search income',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.small),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'all', child: Text('All statuses')),
                DropdownMenuItem(value: 'expected', child: Text('Expected')),
                DropdownMenuItem(value: 'received', child: Text('Received')),
                DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
              ],
              onChanged: (String? value) =>
                  setState(() => _status = value ?? 'all'),
            ),
            const SizedBox(height: AppSpacing.medium),
            if (visible.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No income records match this view.'),
                ),
              )
            else
              ...visible.map(
                (IncomeEntry income) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.south_west_rounded),
                    ),
                    title: Text(income.source),
                    subtitle: Text(
                      '${_statusLabel(income, now)} · ${DateFormat.yMMMd().format((income.actualReceivedAt ?? income.expectedDate).toLocal())} · ${income.frequency.replaceAll('_', ' ')}',
                    ),
                    trailing: Text(
                      Money(
                        income.amountMinorUnits,
                        currencyCode: income.currencyCode,
                      ).format(),
                      textAlign: TextAlign.end,
                    ),
                    onTap: () => _showDetails(income),
                    isThreeLine: false,
                  ),
                ),
              ),
            ...visible
                .where((IncomeEntry item) => item.status == 'expected')
                .map(
                  (IncomeEntry income) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.small),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: AppSpacing.small,
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: () => _editIncome(
                            accounts.asData?.value ?? const [],
                            income,
                          ),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit'),
                        ),
                        TextButton.icon(
                          onPressed: () => _confirmReceipt(
                            income,
                            accounts.asData?.value ?? const [],
                          ),
                          icon: const Icon(Icons.check),
                          label: const Text('Mark received'),
                        ),
                        IconButton(
                          tooltip: 'Cancel income',
                          onPressed: () => _cancel(income),
                          icon: const Icon(Icons.cancel_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
            ...visible
                .where((IncomeEntry item) => item.status == 'received')
                .map((IncomeEntry income) {
                  final FinancialTransactionView? transaction =
                      (transactions.asData?.value ??
                              const <FinancialTransactionView>[])
                          .where(
                            (FinancialTransactionView item) =>
                                item.type == 'income' &&
                                item.relatedRecordId == income.id,
                          )
                          .firstOrNull;
                  if (transaction == null) return const SizedBox.shrink();
                  return Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _reverseReceived(income, transaction),
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('Reverse received entry'),
                    ),
                  );
                }),
          ],
        ),
      ),
    );
  }

  DateTimeRange? _customRange;
  DateTimeRange _range(DateTime now) {
    final DateTime today = DateTime(now.year, now.month, now.day);
    if (_period == 'custom' && _customRange != null) return _customRange!;
    final DateTime start = switch (_period) {
      'day' => today,
      'week' => today.subtract(Duration(days: today.weekday - 1)),
      'quarter' => DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1),
      'year' => DateTime(now.year),
      _ => DateTime(now.year, now.month),
    };
    return DateTimeRange(start: start, end: today);
  }

  bool _isOverdue(IncomeEntry item, DateTime now) =>
      item.status == 'expected' &&
      item.expectedDate.isBefore(DateTime(now.year, now.month, now.day));

  String _statusLabel(IncomeEntry item, DateTime now) => _isOverdue(item, now)
      ? 'Overdue'
      : item.status[0].toUpperCase() + item.status.substring(1);

  Widget _summary(String label, int amount, IconData icon) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon),
          const SizedBox(height: AppSpacing.small),
          Text(label),
          Text(
            Money(amount, currencyCode: 'PHP').format(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    ),
  );

  Widget _message(String text) => Center(
    child: Padding(padding: const EdgeInsets.all(24), child: Text(text)),
  );

  Future<void> _editIncome(
    List<FinancialAccount> accounts,
    IncomeEntry? income,
  ) async {
    final List<FinancialAccount> eligible = accounts
        .where(
          (FinancialAccount item) =>
              item.isActive &&
              item.archivedAt == null &&
              item.accountType != 'credit_card',
        )
        .toList();
    final TextEditingController source = TextEditingController(
      text: income?.source ?? '',
    );
    final TextEditingController category = TextEditingController(
      text: income?.category ?? 'Other',
    );
    final TextEditingController amount = TextEditingController(
      text: income == null
          ? ''
          : (income.amountMinorUnits / 100).toStringAsFixed(2),
    );
    final TextEditingController notes = TextEditingController(
      text: income?.notes ?? '',
    );
    DateTime date = income?.expectedDate ?? DateTime.now();
    String frequency = income?.frequency ?? 'one_time';
    String? accountId = income?.receivingAccountId;
    final form = GlobalKey<FormState>();
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) =>
            AlertDialog(
              title: Text(
                income == null ? 'Add expected income' : 'Edit expected income',
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Form(
                    key: form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        TextFormField(
                          controller: source,
                          decoration: const InputDecoration(
                            labelText: 'Title / source',
                          ),
                          validator: (String? value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter the income source.'
                              : null,
                        ),
                        TextFormField(
                          controller: amount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            prefixText: 'PHP ',
                          ),
                          validator: (String? value) {
                            final int? parsed = value == null
                                ? null
                                : parseMinorUnits(value);
                            return parsed == null || parsed <= 0
                                ? 'Enter an amount greater than zero.'
                                : null;
                          },
                        ),
                        TextFormField(
                          controller: category,
                          decoration: const InputDecoration(
                            labelText: 'Income category',
                            hintText: 'Salary, freelance, business, bonus…',
                          ),
                          validator: (String? value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter an income category.'
                              : null,
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: frequency,
                          decoration: const InputDecoration(
                            labelText: 'Frequency',
                          ),
                          items:
                              const <String>[
                                    'one_time',
                                    'daily',
                                    'weekly',
                                    'biweekly',
                                    'twice_monthly',
                                    'monthly',
                                    'quarterly',
                                    'annually',
                                    'custom',
                                  ]
                                  .map(
                                    (String value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value.replaceAll('_', ' ')),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (String? value) => setDialogState(
                            () => frequency = value ?? frequency,
                          ),
                        ),
                        DropdownButtonFormField<String?>(
                          initialValue: accountId,
                          decoration: const InputDecoration(
                            labelText: 'Receiving account (optional)',
                          ),
                          items: <DropdownMenuItem<String?>>[
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Choose when received'),
                            ),
                            ...eligible.map(
                              (FinancialAccount item) => DropdownMenuItem(
                                value: item.id,
                                child: Text(item.name),
                              ),
                            ),
                          ],
                          onChanged: (String? value) =>
                              setDialogState(() => accountId = value),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final DateTime? chosen = await showDatePicker(
                              context: context,
                              initialDate: date,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (chosen != null) {
                              setDialogState(() => date = chosen);
                            }
                          },
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: Text(
                            'Expected · ${DateFormat.yMMMd().format(date)}',
                          ),
                        ),
                        TextFormField(
                          controller: notes,
                          decoration: const InputDecoration(
                            labelText: 'Notes (optional)',
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (form.currentState?.validate() ?? false) {
                      Navigator.pop(dialogContext, true);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
      ),
    );
    if (saved == true && mounted) {
      final FinancialRepository repository = ref.read(
        financialRepositoryProvider,
      );
      final int minor = parseMinorUnits(amount.text)!;
      try {
        if (income == null) {
          await repository.createIncome(
            CreateIncomeInput(
              source: source.text.trim(),
              amountMinorUnits: minor,
              expectedDate: date,
              frequency: frequency,
              category: category.text.trim(),
              receivingAccountId: accountId,
              notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
            ),
          );
        } else {
          await repository.updateIncome(
            UpdateIncomeInput(
              incomeId: income.id,
              source: source.text.trim(),
              amountMinorUnits: minor,
              expectedDate: date,
              frequency: frequency,
              category: category.text.trim(),
              receivingAccountId: accountId,
              notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
            ),
          );
        }
      } catch (error) {
        _toast('Could not save income: $error');
      }
    }
    source.dispose();
    category.dispose();
    amount.dispose();
    notes.dispose();
  }

  Future<void> _confirmReceipt(
    IncomeEntry income,
    List<FinancialAccount> accounts,
  ) async {
    final List<FinancialAccount> eligible = accounts
        .where(
          (FinancialAccount item) =>
              item.isActive &&
              item.archivedAt == null &&
              item.accountType != 'credit_card',
        )
        .toList();
    if (eligible.isEmpty) {
      _toast('Add an active cash or deposit account first.');
      return;
    }
    String accountId =
        eligible.any(
          (FinancialAccount item) => item.id == income.receivingAccountId,
        )
        ? income.receivingAccountId!
        : eligible.first.id;
    DateTime date = DateTime.now();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
          title: const Text('Confirm income received'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Record ${Money(income.amountMinorUnits, currencyCode: income.currencyCode).format()} as received?',
              ),
              DropdownButtonFormField<String>(
                initialValue: accountId,
                decoration: const InputDecoration(
                  labelText: 'Receiving account',
                ),
                items: eligible
                    .map(
                      (FinancialAccount item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) {
                  if (value != null) setDialogState(() => accountId = value);
                },
              ),
              TextButton(
                onPressed: () async {
                  final DateTime? chosen = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (chosen != null) setDialogState(() => date = chosen);
                },
                child: Text('Received · ${DateFormat.yMMMd().format(date)}'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      try {
        await ref
            .read(financialRepositoryProvider)
            .confirmIncome(
              ConfirmIncomeInput(
                incomeId: income.id,
                accountId: accountId,
                receivedAt: date,
                idempotencyKey: _uuid.v4(),
              ),
            );
      } catch (error) {
        _toast('Could not confirm income: $error');
      }
    }
  }

  Future<void> _cancel(IncomeEntry income) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Cancel expected income?'),
        content: Text(
          '“${income.source}” will remain in your history as cancelled.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel income'),
          ),
        ],
      ),
    );
    if (yes == true) {
      try {
        await ref.read(financialRepositoryProvider).cancelIncome(income.id);
      } catch (error) {
        _toast('Could not cancel income: $error');
      }
    }
  }

  Future<void> _reverseReceived(
    IncomeEntry income,
    FinancialTransactionView transaction,
  ) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Reverse this income?'),
        content: const Text(
          'The original transaction stays in history. A reversal will adjust the account balance.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reverse'),
          ),
        ],
      ),
    );
    if (yes == true) {
      try {
        await ref
            .read(financialRepositoryProvider)
            .reverseTransaction(
              transactionId: transaction.id,
              reversedAt: DateTime.now(),
              idempotencyKey: _uuid.v4(),
              notes: 'Income correction: ${income.source}',
            );
      } catch (error) {
        _toast('Could not reverse income: $error');
      }
    }
  }

  void _showDetails(IncomeEntry income) => showDialog<void>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(income.source),
      content: Text(
        '${Money(income.amountMinorUnits, currencyCode: income.currencyCode).format()}\nStatus: ${income.status}\nFrequency: ${income.frequency.replaceAll('_', ' ')}\nExpected: ${DateFormat.yMMMd().format(income.expectedDate.toLocal())}${income.notes == null ? '' : '\n\n${income.notes}'}',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  void _toast(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }
}
