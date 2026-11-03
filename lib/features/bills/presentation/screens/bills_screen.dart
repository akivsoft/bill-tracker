import 'dart:convert';

import 'package:bill_tracker/app/theme/app_spacing.dart';
import 'package:bill_tracker/core/utils/money.dart';
import 'package:bill_tracker/core/validators/money_input_parser.dart';
import 'package:bill_tracker/core/widgets/app_card.dart';
import 'package:bill_tracker/core/widgets/app_loading.dart';
import 'package:bill_tracker/core/widgets/empty_state.dart';
import 'package:bill_tracker/core/widgets/summary_card.dart';
import 'package:bill_tracker/features/bills/domain/services/bill_schedule_calculator.dart';
import 'package:bill_tracker/features/dashboard/presentation/providers/financial_overview_providers.dart';
import 'package:bill_tracker/features/settings/presentation/providers/user_preferences_provider.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_commands.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_values.dart';
import 'package:bill_tracker/features/transactions/domain/repositories/financial_repository.dart';
import 'package:bill_tracker/features/transactions/domain/services/financial_calculator.dart';
import 'package:bill_tracker/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});

  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen> {
  static const Uuid _uuid = Uuid();
  static const List<String> _defaultCategories = <String>[
    'Rent',
    'Electricity',
    'Water',
    'Internet',
    'Phone',
    'Insurance',
    'Subscriptions',
    'School fees',
    'Groceries',
    'Family allowance',
    'Transportation',
    'Other',
  ];
  final TextEditingController _search = TextEditingController();
  String _statusFilter = 'all';
  String _period = 'month';
  DateTimeRange? _customRange;
  bool _seedStarted = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final billsValue = ref.watch(billsOverviewProvider);
    final paymentsValue = ref.watch(billPaymentsOverviewProvider);
    final categoriesValue = ref.watch(billCategoriesProvider);
    final accountsValue = ref.watch(walletManagementAccountsProvider);
    final balancesValue = ref.watch(accountBalancesProvider);
    final transactionsValue = ref.watch(recentTransactionsProvider);
    final String currency =
        ref.watch(userPreferencesProvider).asData?.value.currencyCode ?? 'PHP';
    final List<BillEntry> bills =
        billsValue.asData?.value ?? const <BillEntry>[];
    final List<BillPaymentEntry> payments =
        paymentsValue.asData?.value ?? const <BillPaymentEntry>[];
    final List<CategoryEntry> categories =
        categoriesValue.asData?.value ?? const <CategoryEntry>[];
    if (categoriesValue.hasValue && !_seedStarted) {
      _seedStarted = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _seedCategories(categories),
      );
    }
    final DateTime today = DateTime.now();
    final DateTimeRange range = _selectedRange(today);
    final DateTime earliestGenerated = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 35));
    final DateTime latestGenerated = DateTime(
      today.year,
      today.month,
      today.day,
    ).add(const Duration(days: 120));
    final DateTime generationStart = range.start.isBefore(earliestGenerated)
        ? range.start
        : earliestGenerated;
    final DateTime generationEnd = range.end.isAfter(latestGenerated)
        ? range.end
        : latestGenerated;
    final List<BillOccurrence> occurrences =
        <BillOccurrence>[
          for (final BillEntry bill in bills.where(
            (BillEntry item) => item.isActive,
          ))
            for (final DateTime date in BillScheduleCalculator.occurrences(
              anchor: bill.dueDate,
              frequency: bill.frequency,
              start: bill.frequency == 'one_time'
                  ? bill.dueDate
                  : generationStart,
              end: generationEnd,
            ))
              BillOccurrence(bill: bill, dueDate: date),
        ]..sort(
          (BillOccurrence a, BillOccurrence b) =>
              a.dueDate.compareTo(b.dueDate),
        );
    final List<BillOccurrence> periodOccurrences = occurrences
        .where(
          (BillOccurrence item) =>
              !item.dueDate.isBefore(range.start) &&
              item.dueDate.isBefore(range.end.add(const Duration(days: 1))),
        )
        .toList(growable: false);
    final Map<String, String> categoryNames = <String, String>{
      for (final CategoryEntry category in categories)
        category.id: category.name,
    };
    final String query = _search.text.trim().toLowerCase();
    final List<BillOccurrence> visible = periodOccurrences
        .where((BillOccurrence occurrence) {
          final BillOccurrenceStatus state = occurrence.status(payments, today);
          final bool statusMatches = switch (_statusFilter) {
            'upcoming' => state == BillOccurrenceStatus.upcoming,
            'unpaid' =>
              state == BillOccurrenceStatus.unpaid ||
                  state == BillOccurrenceStatus.overdue,
            'partial' => state == BillOccurrenceStatus.partiallyPaid,
            'paid' => state == BillOccurrenceStatus.paid,
            'overdue' => state == BillOccurrenceStatus.overdue,
            'skipped' => state == BillOccurrenceStatus.skipped,
            _ => true,
          };
          return statusMatches &&
              (query.isEmpty ||
                  occurrence.bill.name.toLowerCase().contains(query));
        })
        .toList(growable: false);
    final List<BillOccurrence> outstanding = periodOccurrences
        .where((BillOccurrence item) {
          final BillOccurrenceStatus state = item.status(payments, today);
          return state != BillOccurrenceStatus.paid &&
              state != BillOccurrenceStatus.skipped &&
              state != BillOccurrenceStatus.cancelled;
        })
        .toList(growable: false);
    final int unpaidTotal = outstanding.fold<int>(
      0,
      (int sum, BillOccurrence item) => sum + item.remaining(payments),
    );
    final int overdueTotal = outstanding
        .where(
          (BillOccurrence item) =>
              item.status(payments, today) == BillOccurrenceStatus.overdue,
        )
        .fold<int>(
          0,
          (int sum, BillOccurrence item) => sum + item.remaining(payments),
        );
    final int paidThisMonth = payments
        .where(
          (BillPaymentEntry payment) =>
              !payment.isSkipped &&
              payment.reversedAt == null &&
              payment.paidAt.year == today.year &&
              payment.paidAt.month == today.month,
        )
        .fold<int>(
          0,
          (int sum, BillPaymentEntry payment) => sum + payment.amountMinorUnits,
        );
    final int actual = FinancialCalculator.actualAvailableMoney(
      balancesValue.asData?.value ?? const <AccountBalance>[],
      currencyCode: currency,
    );
    final BillAllocationForecast forecast = BillScheduleCalculator.forecast(
      occurrences: occurrences,
      payments: payments,
      actualAvailableMinorUnits: actual,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bills'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Add bill category',
            onPressed: _addCategory,
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
          IconButton(
            tooltip: 'Add bill',
            onPressed: () => _editBill(
              bills,
              categories,
              accountsValue.asData?.value ?? const <FinancialAccount>[],
              null,
            ),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editBill(
          bills,
          categories,
          accountsValue.asData?.value ?? const <FinancialAccount>[],
          null,
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add bill'),
      ),
      body: billsValue.when(
        loading: () => const AppLoading(label: 'Loading bills'),
        error: (Object error, StackTrace stack) => _message(
          'Bills could not be loaded. Tap to retry.',
          () => ref.invalidate(billsOverviewProvider),
        ),
        data: (_) => SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.medium,
                  AppSpacing.small,
                  AppSpacing.medium,
                  100,
                ),
                children: <Widget>[
                  Text(
                    'Payment overview',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xSmall),
                  Text(
                    'Due dates are reminders. Only confirmed payments change actual account balances.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  DropdownButton<String>(
                    value: _period,
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'day', child: Text('Today')),
                      DropdownMenuItem(value: 'week', child: Text('This week')),
                      DropdownMenuItem(
                        value: 'month',
                        child: Text('This month'),
                      ),
                      DropdownMenuItem(
                        value: 'custom',
                        child: Text('Custom dates'),
                      ),
                    ],
                    onChanged: (String? value) async {
                      if (value == 'custom') {
                        final DateTimeRange? picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          initialDateRange: _customRange,
                        );
                        if (picked != null) {
                          setState(() => _customRange = picked);
                        }
                      }
                      if (value != null) setState(() => _period = value);
                    },
                  ),
                  LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final int columns = constraints.maxWidth > 550
                              ? 3
                              : 2;
                          return GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: columns,
                            crossAxisSpacing: AppSpacing.small,
                            mainAxisSpacing: AppSpacing.small,
                            childAspectRatio: 1.55,
                            children: <Widget>[
                              SummaryCard(
                                label: 'Upcoming bills',
                                value: outstanding.length.toString(),
                                icon: Icons.event_note_rounded,
                                caption: Money(
                                  unpaidTotal,
                                  currencyCode: currency,
                                ).format(),
                              ),
                              SummaryCard(
                                label: 'Unpaid',
                                value: outstanding.length.toString(),
                                icon: Icons.pending_actions_rounded,
                                caption: Money(
                                  unpaidTotal,
                                  currencyCode: currency,
                                ).format(),
                              ),
                              SummaryCard(
                                label: 'Overdue',
                                value: outstanding
                                    .where(
                                      (BillOccurrence item) =>
                                          item.status(payments, today) ==
                                          BillOccurrenceStatus.overdue,
                                    )
                                    .length
                                    .toString(),
                                icon: Icons.warning_amber_rounded,
                                caption: Money(
                                  overdueTotal,
                                  currencyCode: currency,
                                ).format(),
                              ),
                              SummaryCard(
                                label: 'Paid this month',
                                value: Money(
                                  paidThisMonth,
                                  currencyCode: currency,
                                ).format(),
                                icon: Icons.task_alt_rounded,
                              ),
                            ],
                          );
                        },
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Bill allocation forecast',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.small),
                        _moneyLine(
                          'Upcoming obligations',
                          forecast.upcomingObligationsMinorUnits,
                          currency,
                        ),
                        _moneyLine(
                          'Allocated',
                          forecast.allocatedMinorUnits,
                          currency,
                        ),
                        _moneyLine(
                          'Unallocated',
                          forecast.unallocatedMinorUnits,
                          currency,
                        ),
                        _moneyLine(
                          'Projected after bills',
                          forecast.projectedRemainingMinorUnits,
                          currency,
                        ),
                        Text(
                          'Allocations are plans only; they do not move wallet money.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Search bills',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  DropdownButtonFormField<String>(
                    initialValue: _statusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Payment status',
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All statuses'),
                      ),
                      DropdownMenuItem(
                        value: 'upcoming',
                        child: Text('Upcoming'),
                      ),
                      DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
                      DropdownMenuItem(
                        value: 'partial',
                        child: Text('Partially paid'),
                      ),
                      DropdownMenuItem(value: 'paid', child: Text('Paid')),
                      DropdownMenuItem(
                        value: 'overdue',
                        child: Text('Overdue'),
                      ),
                      DropdownMenuItem(
                        value: 'skipped',
                        child: Text('Skipped'),
                      ),
                    ],
                    onChanged: (String? value) =>
                        setState(() => _statusFilter = value ?? 'all'),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  if (paymentsValue.isLoading) const LinearProgressIndicator(),
                  if (visible.isEmpty)
                    const AppCard(
                      child: EmptyState(
                        icon: Icons.event_available_outlined,
                        title: 'No bills in this view',
                        message:
                            'Create a bill or change the filters to see its due dates.',
                      ),
                    ),
                  ...visible.map((BillOccurrence occurrence) {
                    final BillOccurrenceStatus state = occurrence.status(
                      payments,
                      today,
                    );
                    final String status = _statusLabel(state);
                    final int remaining = occurrence.remaining(payments);
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.small),
                      child: Column(
                        children: <Widget>[
                          ListTile(
                            leading: CircleAvatar(
                              child: Icon(
                                state == BillOccurrenceStatus.overdue
                                    ? Icons.warning_amber_rounded
                                    : state == BillOccurrenceStatus.paid
                                    ? Icons.task_alt
                                    : Icons.receipt_long_outlined,
                              ),
                            ),
                            title: Text(occurrence.bill.name),
                            subtitle: Text(
                              '${categoryNames[occurrence.bill.categoryId] ?? 'Other'} · Due ${DateFormat.yMMMd().format(occurrence.dueDate)} · $status',
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                Text(
                                  Money(
                                    occurrence.bill.amountMinorUnits,
                                    currencyCode: occurrence.bill.currencyCode,
                                  ).format(),
                                ),
                                if (state == BillOccurrenceStatus.partiallyPaid)
                                  Text(
                                    'Left ${Money(remaining, currencyCode: occurrence.bill.currencyCode).format()}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                            onTap: () => _showHistory(
                              occurrence,
                              payments,
                              transactionsValue.asData?.value ??
                                  const <FinancialTransactionView>[],
                            ),
                          ),
                          if (state != BillOccurrenceStatus.paid &&
                              state != BillOccurrenceStatus.skipped &&
                              state != BillOccurrenceStatus.cancelled)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.small,
                                0,
                                AppSpacing.small,
                                AppSpacing.small,
                              ),
                              child: Wrap(
                                alignment: WrapAlignment.end,
                                spacing: AppSpacing.small,
                                children: <Widget>[
                                  TextButton.icon(
                                    onPressed: () => _pay(
                                      occurrence,
                                      remaining,
                                      accountsValue.asData?.value ??
                                          const <FinancialAccount>[],
                                    ),
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                    ),
                                    label: const Text('Mark as paid'),
                                  ),
                                  TextButton(
                                    onPressed: () => _skip(
                                      occurrence,
                                      accountsValue.asData?.value ??
                                          const <FinancialAccount>[],
                                    ),
                                    child: const Text('Skip period'),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (String action) => _billAction(
                                      action,
                                      occurrence.bill,
                                      bills,
                                      categories,
                                      accountsValue.asData?.value ??
                                          const <FinancialAccount>[],
                                    ),
                                    itemBuilder: (BuildContext context) =>
                                        const <PopupMenuEntry<String>>[
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Edit bill'),
                                          ),
                                          PopupMenuItem(
                                            value: 'duplicate',
                                            child: Text('Duplicate bill'),
                                          ),
                                          PopupMenuItem(
                                            value: 'deactivate',
                                            child: Text('Deactivate'),
                                          ),
                                          PopupMenuItem(
                                            value: 'archive',
                                            child: Text('Archive'),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Remove bill'),
                                          ),
                                        ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  if (bills.isEmpty) const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  DateTimeRange _selectedRange(DateTime now) {
    if (_period == 'custom' && _customRange != null) return _customRange!;
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime start = switch (_period) {
      'day' => today,
      'week' => today.subtract(Duration(days: today.weekday - 1)),
      _ => DateTime(now.year, now.month),
    };
    final DateTime end = switch (_period) {
      'day' => today,
      'week' => start.add(const Duration(days: 6)),
      _ => DateTime(now.year, now.month + 1, 0),
    };
    return DateTimeRange(start: start, end: end);
  }

  Future<void> _seedCategories(List<CategoryEntry> existing) async {
    final Set<String> present = existing
        .map((CategoryEntry item) => item.name.toLowerCase())
        .toSet();
    final FinancialRepository repository = ref.read(
      financialRepositoryProvider,
    );
    for (final String name in _defaultCategories.where(
      (String name) => !present.contains(name.toLowerCase()),
    )) {
      try {
        await repository.createCategory(
          CreateCategoryInput(
            name: name,
            categoryType: 'bill',
            isDefault: true,
          ),
        );
      } catch (_) {
        /* A concurrent first run may already have inserted it. */
      }
    }
  }

  Future<void> _addCategory() async {
    final TextEditingController name = TextEditingController();
    final bool? save = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('New bill category'),
        content: TextField(
          controller: name,
          maxLength: 80,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Category name'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, name.text.trim().isNotEmpty),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (save == true) {
      try {
        await ref
            .read(financialRepositoryProvider)
            .createCategory(
              CreateCategoryInput(name: name.text.trim(), categoryType: 'bill'),
            );
      } catch (error) {
        _toast('Could not add category: $error');
      }
    }
    name.dispose();
  }

  Future<void> _editBill(
    List<BillEntry> bills,
    List<CategoryEntry> categories,
    List<FinancialAccount> accounts,
    BillEntry? original, {
    bool duplicate = false,
  }) async {
    final BillEntry? bill = duplicate ? null : original;
    final BillEntry? initial = original;
    final TextEditingController name = TextEditingController(
      text: duplicate ? '${initial?.name ?? ''} (copy)' : bill?.name ?? '',
    );
    final TextEditingController amount = TextEditingController(
      text: (bill ?? initial) == null
          ? ''
          : ((bill ?? initial)!.amountMinorUnits / 100).toStringAsFixed(2),
    );
    final TextEditingController notes = TextEditingController(
      text: (bill ?? initial)?.notes ?? '',
    );
    final metadata = _metadata((bill ?? initial)?.reminderConfiguration);
    final TextEditingController provider = TextEditingController(
      text: metadata['provider'] ?? '',
    );
    final TextEditingController reference = TextEditingController(
      text: metadata['reference'] ?? '',
    );
    final TextEditingController customDays = TextEditingController(
      text: (bill ?? initial)?.frequency.startsWith('custom:') == true
          ? (bill ?? initial)!.frequency.substring(7)
          : '30',
    );
    DateTime dueDate = (bill ?? initial)?.dueDate ?? DateTime.now();
    String frequency =
        (bill ?? initial)?.frequency.startsWith('custom:') == true
        ? 'custom'
        : (bill ?? initial)?.frequency ?? 'one_time';
    String reminder = metadata['reminder'] ?? 'none';
    String? categoryId =
        (bill ?? initial)?.categoryId ??
        (categories.isEmpty ? null : categories.first.id);
    String? accountId = (bill ?? initial)?.paymentAccountId;
    bool allocation = (bill ?? initial)?.automaticAllocation ?? false;
    final form = GlobalKey<FormState>();
    final bool? save = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
          title: Text(
            bill == null
                ? (duplicate ? 'Duplicate bill' : 'Add bill')
                : 'Edit bill',
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Bill name'),
                      validator: (String? value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter a bill name.'
                          : null,
                    ),
                    TextFormField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Scheduled amount',
                        prefixText: 'PHP ',
                      ),
                      validator: (String? value) {
                        final int? n = value == null
                            ? null
                            : parseMinorUnits(value);
                        return n == null || n <= 0
                            ? 'Enter an amount greater than zero.'
                            : null;
                      },
                    ),
                    DropdownButtonFormField<String?>(
                      initialValue: categoryId,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Other / none'),
                        ),
                        ...categories.map(
                          (CategoryEntry item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        ),
                      ],
                      onChanged: (String? value) =>
                          setDialogState(() => categoryId = value),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: frequency,
                      decoration: const InputDecoration(labelText: 'Frequency'),
                      items:
                          const <String>[
                                'one_time',
                                'daily',
                                'weekly',
                                'biweekly',
                                'monthly',
                                'quarterly',
                                'semiannual',
                                'annual',
                                'custom',
                              ]
                              .map(
                                (String value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value.replaceAll('_', ' ')),
                                ),
                              )
                              .toList(),
                      onChanged: (String? value) =>
                          setDialogState(() => frequency = value ?? frequency),
                    ),
                    if (frequency == 'custom')
                      TextFormField(
                        controller: customDays,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Repeat every N days',
                        ),
                        validator: (String? value) {
                          final int? days = int.tryParse(value ?? '');
                          return days == null || days < 1 || days > 3660
                              ? 'Enter 1 to 3660 days.'
                              : null;
                        },
                      ),
                    TextButton.icon(
                      onPressed: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: dueDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => dueDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text('Due ${DateFormat.yMMMd().format(dueDate)}'),
                    ),
                    DropdownButtonFormField<String?>(
                      initialValue: accountId,
                      decoration: const InputDecoration(
                        labelText: 'Suggested payment account',
                      ),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Choose when paying'),
                        ),
                        ...accounts
                            .where(
                              (FinancialAccount item) =>
                                  item.isActive &&
                                  item.archivedAt == null &&
                                  item.accountType != 'credit_card',
                            )
                            .map(
                              (FinancialAccount item) => DropdownMenuItem(
                                value: item.id,
                                child: Text(item.name),
                              ),
                            ),
                      ],
                      onChanged: (String? value) =>
                          setDialogState(() => accountId = value),
                    ),
                    TextFormField(
                      controller: provider,
                      decoration: const InputDecoration(
                        labelText: 'Provider (optional)',
                      ),
                    ),
                    TextFormField(
                      controller: reference,
                      decoration: const InputDecoration(
                        labelText: 'Reference number (optional)',
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: reminder,
                      decoration: const InputDecoration(
                        labelText: 'Reminder preference',
                      ),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(
                          value: 'none',
                          child: Text('No reminder'),
                        ),
                        DropdownMenuItem(
                          value: '1_day',
                          child: Text('1 day before'),
                        ),
                        DropdownMenuItem(
                          value: '3_days',
                          child: Text('3 days before'),
                        ),
                        DropdownMenuItem(
                          value: '1_week',
                          child: Text('1 week before'),
                        ),
                      ],
                      onChanged: (String? value) =>
                          setDialogState(() => reminder = value ?? reminder),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: allocation,
                      title: const Text('Allocate full remaining bill amount'),
                      subtitle: const Text(
                        'Forecast only; does not reserve or move wallet money.',
                      ),
                      onChanged: (bool value) =>
                          setDialogState(() => allocation = value),
                    ),
                    TextFormField(
                      controller: notes,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                      ),
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
    if (save == true && mounted) {
      final String savedFrequency = frequency == 'custom'
          ? 'custom:${int.parse(customDays.text)}'
          : frequency;
      final String? config = _encodeMetadata(
        provider.text.trim(),
        reference.text.trim(),
        reminder,
      );
      final int value = parseMinorUnits(amount.text)!;
      final FinancialRepository repository = ref.read(
        financialRepositoryProvider,
      );
      try {
        if (bill == null) {
          await repository.createBill(
            CreateBillInput(
              name: name.text.trim(),
              amountMinorUnits: value,
              dueDate: dueDate,
              frequency: savedFrequency,
              categoryId: categoryId,
              paymentAccountId: accountId,
              reminderConfiguration: config,
              automaticAllocation: allocation,
              notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
            ),
          );
        } else {
          await repository.updateBill(
            UpdateBillInput(
              billId: bill.id,
              name: name.text.trim(),
              amountMinorUnits: value,
              dueDate: dueDate,
              frequency: savedFrequency,
              categoryId: categoryId,
              paymentAccountId: accountId,
              reminderConfiguration: config,
              automaticAllocation: allocation,
              notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
            ),
          );
        }
      } catch (error) {
        _toast('Could not save bill: $error');
      }
    }
    name.dispose();
    amount.dispose();
    notes.dispose();
    provider.dispose();
    reference.dispose();
    customDays.dispose();
  }

  Future<void> _pay(
    BillOccurrence occurrence,
    int remaining,
    List<FinancialAccount> accounts,
  ) async {
    final List<FinancialAccount> eligible = accounts
        .where(
          (FinancialAccount account) =>
              account.isActive &&
              account.archivedAt == null &&
              account.accountType != 'credit_card' &&
              account.currencyCode == occurrence.bill.currencyCode,
        )
        .toList();
    if (eligible.isEmpty) {
      _toast('Add an active cash or deposit account first.');
      return;
    }
    final TextEditingController amount = TextEditingController(
      text: (remaining / 100).toStringAsFixed(2),
    );
    final TextEditingController notes = TextEditingController();
    String accountId =
        eligible.any(
          (FinancialAccount item) =>
              item.id == occurrence.bill.paymentAccountId,
        )
        ? occurrence.bill.paymentAccountId!
        : eligible.first.id;
    DateTime paidAt = DateTime.now();
    final form = GlobalKey<FormState>();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
          title: const Text('Confirm bill payment'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    occurrence.bill.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    'Scheduled ${Money(occurrence.bill.amountMinorUnits, currencyCode: occurrence.bill.currencyCode).format()} · Remaining ${Money(remaining, currencyCode: occurrence.bill.currencyCode).format()}',
                  ),
                  TextFormField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Actual amount paid',
                      prefixText: 'PHP ',
                    ),
                    validator: (String? value) {
                      final int? n = value == null
                          ? null
                          : parseMinorUnits(value);
                      return n == null || n <= 0 || n > remaining
                          ? 'Enter an amount up to the remaining balance.'
                          : null;
                    },
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: accountId,
                    decoration: const InputDecoration(
                      labelText: 'Payment account',
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
                      if (value != null) {
                        setDialogState(() => accountId = value);
                      }
                    },
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: paidAt,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setDialogState(() => paidAt = picked);
                    },
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                      'Payment date · ${DateFormat.yMMMd().format(paidAt)}',
                    ),
                  ),
                  TextField(
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
              child: const Text('Confirm payment'),
            ),
          ],
        ),
      ),
    );
    if (confirm == true) {
      try {
        await ref
            .read(financialRepositoryProvider)
            .confirmBillPayment(
              BillPaymentInput(
                billId: occurrence.bill.id,
                accountId: accountId,
                amountMinorUnits: parseMinorUnits(amount.text)!,
                occurrenceKey: occurrence.key,
                paidAt: paidAt,
                idempotencyKey: _uuid.v4(),
                notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
              ),
            );
      } catch (error) {
        _toast('Could not record payment: $error');
      }
    }
    amount.dispose();
    notes.dispose();
  }

  Future<void> _skip(
    BillOccurrence occurrence,
    List<FinancialAccount> accounts,
  ) async {
    final FinancialAccount? account =
        accounts
            .where(
              (FinancialAccount item) =>
                  item.id == occurrence.bill.paymentAccountId &&
                  item.isActive &&
                  item.archivedAt == null &&
                  item.currencyCode == occurrence.bill.currencyCode &&
                  item.accountType != 'credit_card',
            )
            .firstOrNull ??
        accounts
            .where(
              (FinancialAccount item) =>
                  item.isActive &&
                  item.currencyCode == occurrence.bill.currencyCode &&
                  item.accountType != 'credit_card',
            )
            .firstOrNull;
    if (account == null) {
      _toast(
        'Choose a payment account for this bill before skipping a period.',
      );
      return;
    }
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Skip this billing period?'),
        content: Text(
          '${occurrence.bill.name} due ${DateFormat.yMMMd().format(occurrence.dueDate)} will remain in history as skipped. No money will move.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Skip period'),
          ),
        ],
      ),
    );
    if (yes == true) {
      try {
        await ref
            .read(financialRepositoryProvider)
            .skipBillOccurrence(
              SkipBillOccurrenceInput(
                billId: occurrence.bill.id,
                occurrenceKey: occurrence.key,
                skippedAt: DateTime.now(),
                idempotencyKey: _uuid.v4(),
                accountId: account.id,
              ),
            );
      } catch (error) {
        _toast('Could not skip period: $error');
      }
    }
  }

  Future<void> _billAction(
    String action,
    BillEntry bill,
    List<BillEntry> bills,
    List<CategoryEntry> categories,
    List<FinancialAccount> accounts,
  ) async {
    final FinancialRepository repository = ref.read(
      financialRepositoryProvider,
    );
    try {
      switch (action) {
        case 'edit':
          await _editBill(bills, categories, accounts, bill);
        case 'duplicate':
          await _editBill(bills, categories, accounts, bill, duplicate: true);
        case 'deactivate':
          await repository.setBillActive(bill.id, false);
        case 'archive':
          final bool? yes = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              title: const Text('Archive bill?'),
              content: const Text('Payment history will be preserved.'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Archive'),
                ),
              ],
            ),
          );
          if (yes == true) await repository.archiveBill(bill.id);
        case 'delete':
          final bool? yes = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              title: const Text('Remove this bill?'),
              content: const Text(
                'Bills with payment history cannot be deleted; archive them instead.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Remove'),
                ),
              ],
            ),
          );
          if (yes == true) await repository.deleteBill(bill.id);
      }
    } catch (error) {
      _toast('Could not $action bill: $error');
    }
  }

  Future<void> _showHistory(
    BillOccurrence occurrence,
    List<BillPaymentEntry> payments,
    List<FinancialTransactionView> transactions,
  ) async {
    final List<BillPaymentEntry> rows = payments
        .where(
          (BillPaymentEntry payment) =>
              payment.billId == occurrence.bill.id &&
              payment.occurrenceKey == occurrence.key,
        )
        .toList();
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(
          '${occurrence.bill.name} · ${DateFormat.yMMMd().format(occurrence.dueDate)}',
        ),
        content: SizedBox(
          width: 460,
          child: rows.isEmpty
              ? const Text('No payments have been recorded for this period.')
              : ListView(
                  shrinkWrap: true,
                  children: rows.map((BillPaymentEntry payment) {
                    final FinancialTransactionView? tx = transactions
                        .where(
                          (FinancialTransactionView item) =>
                              item.id == payment.transactionId,
                        )
                        .firstOrNull;
                    final String state = payment.isSkipped
                        ? 'Skipped'
                        : payment.reversedAt != null
                        ? 'Reversed'
                        : 'Paid';
                    return ListTile(
                      title: Text(state),
                      subtitle: Text(
                        DateFormat.yMMMd().format(payment.paidAt.toLocal()),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            Money(
                              payment.amountMinorUnits,
                              currencyCode: occurrence.bill.currencyCode,
                            ).format(),
                          ),
                          if (tx != null && payment.reversedAt == null)
                            IconButton(
                              tooltip: 'Reverse payment',
                              icon: const Icon(Icons.undo_rounded),
                              onPressed: () async {
                                final bool? yes = await showDialog<bool>(
                                  context: dialogContext,
                                  builder: (BuildContext context) => AlertDialog(
                                    title: const Text('Reverse this payment?'),
                                    content: const Text(
                                      'The transaction history is preserved and the account balance is restored.',
                                    ),
                                    actions: <Widget>[
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Keep'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Reverse'),
                                      ),
                                    ],
                                  ),
                                );
                                if (yes == true) {
                                  await ref
                                      .read(financialRepositoryProvider)
                                      .reverseTransaction(
                                        transactionId: tx.id,
                                        reversedAt: DateTime.now(),
                                        idempotencyKey: _uuid.v4(),
                                      );
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                }
                              },
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Map<String, String> _metadata(String? value) {
    if (value == null || value.isEmpty) return <String, String>{};
    try {
      return (jsonDecode(value) as Map<String, dynamic>).map(
        (String k, dynamic v) => MapEntry(k, v.toString()),
      );
    } catch (_) {
      return <String, String>{};
    }
  }

  String? _encodeMetadata(String provider, String reference, String reminder) {
    final Map<String, String> values = <String, String>{'reminder': reminder};
    if (provider.isNotEmpty) values['provider'] = provider;
    if (reference.isNotEmpty) values['reference'] = reference;
    return jsonEncode(values);
  }

  String _statusLabel(BillOccurrenceStatus status) => switch (status) {
    BillOccurrenceStatus.upcoming => 'Upcoming',
    BillOccurrenceStatus.unpaid => 'Unpaid',
    BillOccurrenceStatus.partiallyPaid => 'Partially paid',
    BillOccurrenceStatus.paid => 'Paid',
    BillOccurrenceStatus.overdue => 'Overdue',
    BillOccurrenceStatus.skipped => 'Skipped',
    BillOccurrenceStatus.cancelled => 'Cancelled',
  };

  Widget _moneyLine(String label, int amount, String currency) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        Text(Money(amount, currencyCode: currency).format()),
      ],
    ),
  );
  Widget _message(String text, VoidCallback retry) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(text),
        TextButton(onPressed: retry, child: const Text('Retry')),
      ],
    ),
  );
  void _toast(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }
}
