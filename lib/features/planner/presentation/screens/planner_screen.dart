import 'package:bill_tracker/app/theme/app_spacing.dart';
import 'package:bill_tracker/core/utils/money.dart';
import 'package:bill_tracker/core/validators/money_input_parser.dart';
import 'package:bill_tracker/features/bills/domain/services/bill_schedule_calculator.dart';
import 'package:bill_tracker/features/dashboard/presentation/providers/financial_overview_providers.dart';
import 'package:bill_tracker/features/planner/domain/services/payday_schedule_calculator.dart';
import 'package:bill_tracker/features/planner/domain/services/payday_allocation_calculator.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_commands.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:bill_tracker/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  static const Uuid _uuid = Uuid();
  static const Map<String, String> _frequencies = <String, String>{
    'daily': 'Daily',
    'weekly': 'Weekly',
    'biweekly': 'Biweekly',
    'twice_monthly': 'Twice monthly',
    'monthly': 'Monthly',
    'quarterly': 'Quarterly',
    'yearly': 'Yearly',
    'irregular': 'Irregular',
  };
  static const List<String> _categories = <String>[
    'rent',
    'electricity',
    'water',
    'internet',
    'groceries',
    'family_allowance',
    'insurance',
    'subscriptions',
    'loan_installment',
    'credit_card_payment',
    'savings',
    'custom',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(paydaySchedulesProvider);
    final incomes =
        ref.watch(incomeOverviewProvider).asData?.value ??
        const <IncomeEntry>[];
    final bills =
        ref.watch(billsOverviewProvider).asData?.value ?? const <BillEntry>[];
    final installments =
        ref.watch(installmentsOverviewProvider).asData?.value ??
        const <LoanInstallmentEntry>[];
    final loans =
        ref.watch(loansOverviewProvider).asData?.value ?? const <LoanEntry>[];
    final goals =
        ref.watch(savingsGoalsOverviewProvider).asData?.value ??
        const <SavingsGoalEntry>[];
    final accounts =
        ref.watch(walletManagementAccountsProvider).asData?.value ??
        const <FinancialAccount>[];
    final currency = accounts.isEmpty ? 'PHP' : accounts.first.currencyCode;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payday planner'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Add payday schedule',
            onPressed: () => _editSchedule(context, ref, accounts, null),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editSchedule(context, ref, accounts, null),
        icon: const Icon(Icons.add),
        label: const Text('Add payday'),
      ),
      body: schedules.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) =>
            const Center(child: Text('Payday schedules could not be loaded.')),
        data: (List<PaydayScheduleEntry> rows) {
          final active = rows
              .where((PaydayScheduleEntry row) => row.isActive)
              .toList();
          final DateTime today = DateTime.now();
          final DateTime horizon = DateTime(
            today.year,
            today.month + 3,
            today.day,
          );
          final Map<String, List<AllocationEntry>> allocationsBySchedule =
              <String, List<AllocationEntry>>{
                for (final PaydayScheduleEntry schedule in rows)
                  schedule.id:
                      ref
                          .watch(paydayAllocationsProvider(schedule.id))
                          .asData
                          ?.value ??
                      const <AllocationEntry>[],
              };
          final List<AllocationEntry> allAllocations = allocationsBySchedule
              .values
              .expand((items) => items)
              .toList();
          final DateTime? nextPayday = active
              .map(
                (PaydayScheduleEntry schedule) =>
                    _nextDate(schedule, today, horizon),
              )
              .whereType<DateTime>()
              .fold<DateTime?>(
                null,
                (DateTime? earliest, DateTime date) =>
                    earliest == null || date.isBefore(earliest)
                    ? date
                    : earliest,
              );
          final List<DateTime> unassignedBillDates = <DateTime>[
            for (final BillEntry bill in bills.where((item) => item.isActive))
              for (final DateTime dueDate in BillScheduleCalculator.occurrences(
                anchor: bill.dueDate,
                frequency: bill.frequency,
                start: today,
                end: nextPayday ?? today,
              ))
                if (!allAllocations.any(
                  (AllocationEntry allocation) =>
                      allocation.relatedBillId == bill.id &&
                      allocation.relatedDueDate != null &&
                      _sameDay(allocation.relatedDueDate!, dueDate),
                ))
                  dueDate,
          ];
          final List<LoanInstallmentEntry> unassignedInstallments = installments
              .where(
                (LoanInstallmentEntry installment) =>
                    installment.status != 'paid' &&
                    installment.status != 'settled' &&
                    (nextPayday == null ||
                        !installment.dueDate.isAfter(nextPayday)) &&
                    !allAllocations.any(
                      (AllocationEntry allocation) =>
                          allocation.relatedInstallmentId == installment.id,
                    ),
              )
              .toList();
          final int approachingLoans = installments.where((item) {
            final DateTime due = DateTime(
              item.dueDate.year,
              item.dueDate.month,
              item.dueDate.day,
            );
            final DateTime todayOnly = DateTime(
              today.year,
              today.month,
              today.day,
            );
            return item.status != 'paid' &&
                item.status != 'settled' &&
                !due.isBefore(todayOnly) &&
                !due.isAfter(todayOnly.add(const Duration(days: 14)));
          }).length;
          final int expected = active
              .where((s) => _nextDate(s, today, horizon) != null)
              .fold<int>(
                0,
                (int sum, PaydayScheduleEntry s) =>
                    sum + s.expectedIncomeMinorUnits,
              );
          final int planned = active.fold<int>(0, (
            int sum,
            PaydayScheduleEntry s,
          ) {
            final List<AllocationEntry> items =
                allocationsBySchedule[s.id] ?? const <AllocationEntry>[];
            final DateTime? next = _nextDate(s, today, horizon);
            return sum +
                items
                    .where(
                      (AllocationEntry a) =>
                          a.status != 'cancelled' &&
                          a.periodDate != null &&
                          next != null &&
                          _sameDay(a.periodDate!, next),
                    )
                    .fold<int>(
                      0,
                      (int total, AllocationEntry a) =>
                          total + a.allocatedAmountMinorUnits,
                    );
          });
          final int incomeBasis = active.fold<int>(0, (
            int sum,
            PaydayScheduleEntry schedule,
          ) {
            final DateTime? payday = _nextDate(schedule, today, horizon);
            final bool received =
                payday != null &&
                schedule.actualReceivedAt != null &&
                _sameDay(payday, schedule.actualReceivedAt!);
            return sum +
                (received
                    ? schedule.actualIncomeMinorUnits
                    : schedule.expectedIncomeMinorUnits);
          });
          final int unallocated = incomeBasis - planned;
          return ListView(
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
                    child: _summary('Expected per cycle', expected, currency),
                  ),
                  const SizedBox(width: AppSpacing.small),
                  Expanded(
                    child: _summary('Unallocated', unallocated, currency),
                  ),
                ],
              ),
              if (unassignedBillDates.isNotEmpty ||
                  unassignedInstallments.isNotEmpty)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.medium),
                    child: Text(
                      '${unassignedBillDates.length} bill occurrence(s) and ${unassignedInstallments.length} loan installment(s) due before the next payday are not assigned.',
                    ),
                  ),
                ),
              if (approachingLoans > 0)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.notification_important_outlined),
                    title: Text(
                      '$approachingLoans loan installment(s) due within 14 days.',
                    ),
                    subtitle: const Text(
                      'Check whether they are assigned to an upcoming payday.',
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.medium),
              const Text(
                'Schedules',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              if (rows.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.medium),
                    child: Text(
                      'Add each income source and its payday frequency to start planning.',
                    ),
                  ),
                ),
              ...rows.map((PaydayScheduleEntry schedule) {
                final List<DateTime> dates =
                    PaydayScheduleCalculator.occurrences(
                      anchor: schedule.paydayDate,
                      frequency: schedule.frequency,
                      start: today,
                      end: horizon,
                    );
                final DateTime? next = dates.isEmpty ? null : dates.first;
                final List<AllocationEntry> allocations =
                    allocationsBySchedule[schedule.id] ??
                    const <AllocationEntry>[];
                final DateTime? nextKey = next == null
                    ? null
                    : DateTime(next.year, next.month, next.day);
                final List<AllocationEntry> forNext = allocations
                    .where(
                      (AllocationEntry a) =>
                          a.periodDate != null &&
                          nextKey != null &&
                          _sameDay(a.periodDate!, nextKey),
                    )
                    .toList();
                final List<AllocationEntry> visibleAllocations =
                    allocations
                        .where(
                          (AllocationEntry item) => item.status != 'cancelled',
                        )
                        .toList()
                      ..sort((AllocationEntry a, AllocationEntry b) {
                        final int byDate = (a.periodDate ?? schedule.paydayDate)
                            .compareTo(b.periodDate ?? schedule.paydayDate);
                        return byDate != 0
                            ? byDate
                            : a.priority.compareTo(b.priority);
                      });
                final int allocationTotal = forNext.fold<int>(
                  0,
                  (int s, AllocationEntry a) => s + a.allocatedAmountMinorUnits,
                );
                final int received =
                    schedule.actualReceivedAt != null &&
                        next != null &&
                        _sameDay(schedule.actualReceivedAt!, next)
                    ? schedule.actualIncomeMinorUnits
                    : 0;
                final int confirmed = forNext.fold<int>(
                  0,
                  (int sum, AllocationEntry a) =>
                      sum + a.fulfilledAmountMinorUnits,
                );
                final PaydayAllocationSummary allocationSummary =
                    PaydayAllocationCalculator.calculate(
                      expectedIncomeMinorUnits:
                          schedule.expectedIncomeMinorUnits,
                      actualReceivedIncomeMinorUnits: received,
                      plannedAllocationsMinorUnits: allocationTotal,
                      confirmedPaymentsMinorUnits: confirmed,
                    );
                final int remaining =
                    allocationSummary.projectedRemainingMinorUnits;
                final bool insufficient = allocationSummary.isOverallocated;
                return Card(
                  margin: const EdgeInsets.only(top: AppSpacing.small),
                  child: ExpansionTile(
                    leading: Icon(
                      schedule.isActive
                          ? Icons.payments_outlined
                          : Icons.pause_circle_outline,
                    ),
                    title: Text(schedule.name),
                    subtitle: Text(
                      '${_frequencies[schedule.frequency] ?? schedule.frequency} · ${next == null ? 'No upcoming payday' : DateFormat.yMMMd().format(next)} · ${Money(schedule.expectedIncomeMinorUnits, currencyCode: schedule.currencyCode).format()} expected',
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: <Widget>[
                      if (schedule.status == 'received')
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.check_circle_outline),
                          title: const Text('Income linked'),
                          subtitle: Text(
                            '${Money(schedule.actualIncomeMinorUnits, currencyCode: schedule.currencyCode).format()} · ${schedule.actualReceivedAt == null ? 'Received' : DateFormat.yMMMd().format(schedule.actualReceivedAt!)}',
                          ),
                        ),
                      if (next != null) ...<Widget>[
                        ListTile(
                          dense: true,
                          title: const Text('Projected remaining'),
                          subtitle: Text(
                            'Expected ${Money(schedule.expectedIncomeMinorUnits, currencyCode: schedule.currencyCode).format()} less planned ${Money(allocationTotal, currencyCode: schedule.currencyCode).format()}',
                          ),
                          trailing: Text(
                            Money(
                              remaining,
                              currencyCode: schedule.currencyCode,
                            ).format(),
                            style: TextStyle(
                              color: insufficient
                                  ? Theme.of(context).colorScheme.error
                                  : null,
                            ),
                          ),
                        ),
                        ListTile(
                          dense: true,
                          title: const Text('Confirmed payments toward plan'),
                          trailing: Text(
                            Money(
                              confirmed,
                              currencyCode: schedule.currencyCode,
                            ).format(),
                          ),
                        ),
                        if (insufficient)
                          const ListTile(
                            dense: true,
                            leading: Icon(Icons.warning_amber),
                            title: Text(
                              'Planned obligations exceed this payday.',
                            ),
                          ),
                        if (forNext.isEmpty)
                          const ListTile(
                            dense: true,
                            title: Text(
                              'No allocations planned for this payday.',
                            ),
                          ),
                        ...visibleAllocations.map(
                          (AllocationEntry item) => ListTile(
                            dense: true,
                            leading: Icon(
                              item.status == 'completed'
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                            ),
                            title: Text(
                              '${_label(item.allocationCategory)} · ${Money(item.allocatedAmountMinorUnits, currencyCode: schedule.currencyCode).format()}',
                            ),
                            subtitle: Text(
                              '${item.periodDate == null ? 'Payday not selected' : DateFormat.yMMMd().format(item.periodDate!)} · Priority ${item.priority} · ${_allocationStatus(item.status)}',
                            ),
                            onLongPress: () => _editAllocation(
                              context,
                              ref,
                              schedule,
                              item,
                              bills,
                              installments,
                              loans,
                              goals,
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (String value) {
                                if (value == 'edit') {
                                  _editAllocation(
                                    context,
                                    ref,
                                    schedule,
                                    item,
                                    bills,
                                    installments,
                                    loans,
                                    goals,
                                  );
                                }
                                if (value == 'remove') {
                                  _removeAllocation(context, ref, item);
                                }
                              },
                              itemBuilder: (_) =>
                                  const <PopupMenuEntry<String>>[
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit planned allocation'),
                                    ),
                                    PopupMenuItem(
                                      value: 'remove',
                                      child: Text('Remove planned allocation'),
                                    ),
                                  ],
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _editAllocation(
                              context,
                              ref,
                              schedule,
                              null,
                              bills,
                              installments,
                              loans,
                              goals,
                              initialDate: next,
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Allocate to this payday'),
                          ),
                        ),
                      ],
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 4,
                        children: <Widget>[
                          TextButton(
                            onPressed: () =>
                                _editSchedule(context, ref, accounts, schedule),
                            child: const Text('Edit'),
                          ),
                          TextButton(
                            onPressed: () =>
                                _linkReceipt(context, ref, schedule, incomes),
                            child: const Text('Link received income'),
                          ),
                          TextButton(
                            onPressed: () => ref
                                .read(financialRepositoryProvider)
                                .setPaydayScheduleActive(
                                  schedule.id,
                                  !schedule.isActive,
                                ),
                            child: Text(schedule.isActive ? 'Pause' : 'Resume'),
                          ),
                          TextButton(
                            onPressed: () =>
                                _removeSchedule(context, ref, schedule),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: AppSpacing.medium),
              Text(
                'Forecasts do not change wallet balances. Link income only after it is already received in Income; the existing transaction is reused.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summary(String title, int amount, String currency) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            Money(amount, currencyCode: currency).format(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );

  DateTime? _nextDate(
    PaydayScheduleEntry schedule,
    DateTime start,
    DateTime end,
  ) {
    final List<DateTime> dates = PaydayScheduleCalculator.occurrences(
      anchor: schedule.paydayDate,
      frequency: schedule.frequency,
      start: start,
      end: end,
    );
    return dates.isEmpty ? null : dates.first;
  }

  Future<void> _editSchedule(
    BuildContext context,
    WidgetRef ref,
    List<FinancialAccount> accounts,
    PaydayScheduleEntry? existing,
  ) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final amount = TextEditingController(
      text: existing == null ? '' : _money(existing.expectedIncomeMinorUnits),
    );
    final notes = TextEditingController(text: existing?.notes ?? '');
    String frequency = existing?.frequency ?? 'monthly';
    String currency =
        existing?.currencyCode ??
        (accounts.isEmpty ? 'PHP' : accounts.first.currencyCode);
    String? accountId = existing?.receivingAccountId;
    DateTime payday = existing?.paydayDate ?? DateTime.now();
    final key = GlobalKey<FormState>();
    final bool? save = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(
            existing == null ? 'Add payday schedule' : 'Edit payday schedule',
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Form(
                key: key,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Income source',
                      ),
                      validator: (String? v) => v == null || v.trim().isEmpty
                          ? 'Enter an income source.'
                          : null,
                    ),
                    TextFormField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Expected amount',
                      ),
                      validator: (String? v) {
                        try {
                          if ((parseMinorUnits(v ?? '') ?? 0) <= 0) {
                            return 'Enter an amount above zero.';
                          }
                        } catch (_) {
                          return 'Enter a valid amount.';
                        }
                        return null;
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: frequency,
                      decoration: const InputDecoration(labelText: 'Frequency'),
                      items: _frequencies.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (String? v) =>
                          setStateDialog(() => frequency = v ?? frequency),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('First payday'),
                      subtitle: Text(DateFormat.yMMMd().format(payday)),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: payday,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setStateDialog(() => payday = picked);
                          }
                        },
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: currency,
                      decoration: const InputDecoration(labelText: 'Currency'),
                      items:
                          accounts
                              .map((a) => a.currencyCode)
                              .toSet()
                              .map(
                                (String c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList()
                            ..addIfEmpty(currency),
                      onChanged: (String? value) =>
                          setStateDialog(() => currency = value ?? currency),
                    ),
                    DropdownButtonFormField<String?>(
                      initialValue: accountId,
                      decoration: const InputDecoration(
                        labelText: 'Receiving account (optional)',
                      ),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Choose when receiving'),
                        ),
                        ...accounts
                            .where(
                              (a) =>
                                  a.isActive &&
                                  a.archivedAt == null &&
                                  a.accountType != 'credit_card' &&
                                  a.currencyCode == currency,
                            )
                            .map(
                              (a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(a.name),
                              ),
                            ),
                      ],
                      onChanged: (String? v) => accountId = v,
                    ),
                    TextFormField(
                      controller: notes,
                      decoration: const InputDecoration(labelText: 'Notes'),
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
                if (key.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (save == true) {
      try {
        final repo = ref.read(financialRepositoryProvider);
        final int minor = parseMinorUnits(amount.text)!;
        if (existing == null) {
          await repo.createPaydaySchedule(
            CreatePaydayScheduleInput(
              name: name.text,
              paydayDate: payday,
              expectedIncomeMinorUnits: minor,
              frequency: frequency,
              currencyCode: currency,
              receivingAccountId: accountId,
              notes: notes.text,
            ),
          );
        } else {
          await repo.updatePaydaySchedule(
            UpdatePaydayScheduleInput(
              id: existing.id,
              name: name.text,
              paydayDate: payday,
              expectedIncomeMinorUnits: minor,
              frequency: frequency,
              currencyCode: currency,
              receivingAccountId: accountId,
              notes: notes.text,
            ),
          );
        }
      } catch (error) {
        if (!context.mounted) return;
        _message(context, 'Could not save payday schedule: $error');
      }
    }
    name.dispose();
    amount.dispose();
    notes.dispose();
  }

  Future<void> _editAllocation(
    BuildContext context,
    WidgetRef ref,
    PaydayScheduleEntry schedule,
    AllocationEntry? existing,
    List<BillEntry> bills,
    List<LoanInstallmentEntry> installments,
    List<LoanEntry> loans,
    List<SavingsGoalEntry> goals, {
    DateTime? initialDate,
  }) async {
    final amount = TextEditingController(
      text: existing == null ? '' : _money(existing.allocatedAmountMinorUnits),
    );
    final notes = TextEditingController(text: existing?.notes ?? '');
    String category = existing?.allocationCategory ?? 'custom';
    int priority = existing?.priority ?? 3;
    String? billId = existing?.relatedBillId;
    DateTime? billDueDate = existing?.relatedDueDate;
    String? installmentId = existing?.relatedInstallmentId;
    String? goalId = existing?.relatedSavingsGoalId;
    DateTime date = existing?.periodDate ?? initialDate ?? schedule.paydayDate;
    final key = GlobalKey<FormState>();
    final bool? save = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(existing == null ? 'Plan allocation' : 'Edit allocation'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Form(
                key: key,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: _categories
                          .map(
                            (String c) => DropdownMenuItem(
                              value: c,
                              child: Text(_label(c)),
                            ),
                          )
                          .toList(),
                      onChanged: (String? v) => setStateDialog(() {
                        category = v ?? category;
                        billId = null;
                        billDueDate = null;
                        installmentId = null;
                        goalId = null;
                      }),
                    ),
                    TextFormField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Amount'),
                      validator: (String? v) {
                        try {
                          if ((parseMinorUnits(v ?? '') ?? 0) <= 0) {
                            return 'Enter an amount above zero.';
                          }
                        } catch (_) {
                          return 'Enter a valid amount.';
                        }
                        return null;
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Assigned payday'),
                      subtitle: Text(DateFormat.yMMMd().format(date)),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setStateDialog(() => date = picked);
                          }
                        },
                      ),
                    ),
                    DropdownButtonFormField<int>(
                      initialValue: priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: const <int>[1, 2, 3, 4, 5]
                          .map(
                            (int p) => DropdownMenuItem(
                              value: p,
                              child: Text(
                                '$p${p == 1
                                    ? ' · highest'
                                    : p == 5
                                    ? ' · lowest'
                                    : ''}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (int? v) =>
                          setStateDialog(() => priority = v ?? priority),
                    ),
                    if (category == 'loan_installment')
                      DropdownButtonFormField<String?>(
                        initialValue: installmentId,
                        decoration: const InputDecoration(
                          labelText: 'Loan installment (optional)',
                        ),
                        items: <DropdownMenuItem<String?>>[
                          const DropdownMenuItem(
                            value: null,
                            child: Text('No linked installment'),
                          ),
                          ...installments
                              .where(
                                (i) =>
                                    i.status != 'paid' && i.status != 'settled',
                              )
                              .map((i) {
                                final LoanEntry? loan = loans
                                    .where((l) => l.id == i.loanId)
                                    .firstOrNull;
                                return DropdownMenuItem(
                                  value: i.id,
                                  child: Text(
                                    '${loan?.name ?? 'Loan'} · ${DateFormat.yMMMd().format(i.dueDate)}',
                                  ),
                                );
                              }),
                        ],
                        onChanged: (String? v) =>
                            setStateDialog(() => installmentId = v),
                      ),
                    if (category != 'loan_installment' && category != 'savings')
                      DropdownButtonFormField<String?>(
                        initialValue: billId,
                        decoration: const InputDecoration(
                          labelText: 'Bill occurrence (optional)',
                        ),
                        items: <DropdownMenuItem<String?>>[
                          const DropdownMenuItem(
                            value: null,
                            child: Text('No linked bill'),
                          ),
                          ...bills
                              .where((b) => b.isActive)
                              .map(
                                (b) => DropdownMenuItem(
                                  value: b.id,
                                  child: Text(b.name),
                                ),
                              ),
                        ],
                        onChanged: (String? v) => setStateDialog(() {
                          billId = v;
                          billDueDate = v == null
                              ? null
                              : bills
                                    .firstWhere((BillEntry b) => b.id == v)
                                    .dueDate;
                        }),
                      ),
                    if (billId != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Bill occurrence due date'),
                        subtitle: Text(
                          DateFormat.yMMMd().format(billDueDate ?? date),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_month),
                          onPressed: () async {
                            final DateTime current = billDueDate ?? date;
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: current,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setStateDialog(() => billDueDate = picked);
                            }
                          },
                        ),
                      ),
                    if (category == 'savings')
                      DropdownButtonFormField<String?>(
                        initialValue: goalId,
                        decoration: const InputDecoration(
                          labelText: 'Savings goal (optional)',
                        ),
                        items: <DropdownMenuItem<String?>>[
                          const DropdownMenuItem(
                            value: null,
                            child: Text('No linked goal'),
                          ),
                          ...goals
                              .where((g) => g.status == 'active')
                              .map(
                                (g) => DropdownMenuItem(
                                  value: g.id,
                                  child: Text(g.name),
                                ),
                              ),
                        ],
                        onChanged: (String? v) =>
                            setStateDialog(() => goalId = v),
                      ),
                    TextFormField(
                      controller: notes,
                      decoration: const InputDecoration(labelText: 'Notes'),
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
                if (key.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (save == true) {
      try {
        final repo = ref.read(financialRepositoryProvider);
        final int minor = parseMinorUnits(amount.text)!;
        if (existing == null) {
          await repo.createAllocation(
            CreateAllocationInput(
              paydayScheduleId: schedule.id,
              allocatedAmountMinorUnits: minor,
              allocationCategory: category,
              allocationKey: _uuid.v4(),
              relatedBillId: billId,
              relatedDueDate: billDueDate,
              relatedInstallmentId: installmentId,
              relatedSavingsGoalId: goalId,
              periodDate: date,
              priority: priority,
              notes: notes.text,
            ),
          );
        } else {
          await repo.updateAllocation(
            UpdateAllocationInput(
              id: existing.id,
              allocatedAmountMinorUnits: minor,
              allocationCategory: category,
              priority: priority,
              periodDate: date,
              relatedBillId: billId,
              relatedDueDate: billDueDate,
              relatedInstallmentId: installmentId,
              relatedSavingsGoalId: goalId,
              notes: notes.text,
            ),
          );
        }
      } catch (error) {
        if (!context.mounted) return;
        _message(context, 'Could not save allocation: $error');
      }
    }
    amount.dispose();
    notes.dispose();
  }

  Future<void> _linkReceipt(
    BuildContext context,
    WidgetRef ref,
    PaydayScheduleEntry schedule,
    List<IncomeEntry> incomes,
  ) async {
    final List<IncomeEntry> candidates = incomes
        .where(
          (IncomeEntry income) =>
              income.status == 'received' &&
              income.source.toLowerCase() == schedule.name.toLowerCase() &&
              income.currencyCode == schedule.currencyCode,
        )
        .toList();
    if (candidates.isEmpty) {
      _message(
        context,
        'No already-received income from "${schedule.name}" is available to link. Confirm it in Income first.',
      );
      return;
    }
    final IncomeEntry? selected = await showDialog<IncomeEntry>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Link received income'),
        children: candidates
            .map(
              (income) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, income),
                child: ListTile(
                  title: Text(
                    DateFormat.yMMMd().format(
                      income.actualReceivedAt ?? income.expectedDate,
                    ),
                  ),
                  subtitle: Text(income.source),
                  trailing: Text(
                    Money(
                      income.amountMinorUnits,
                      currencyCode: income.currencyCode,
                    ).format(),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (!context.mounted) return;
    if (selected == null) return;
    try {
      await ref
          .read(financialRepositoryProvider)
          .linkPaydayReceipt(schedule.id, selected.id);
    } catch (error) {
      if (!context.mounted) return;
      _message(context, 'Could not link income: $error');
    }
  }

  Future<void> _removeAllocation(
    BuildContext context,
    WidgetRef ref,
    AllocationEntry item,
  ) async {
    try {
      await ref.read(financialRepositoryProvider).deleteAllocation(item.id);
    } catch (error) {
      if (!context.mounted) return;
      _message(context, 'Could not remove allocation: $error');
    }
  }

  Future<void> _removeSchedule(
    BuildContext context,
    WidgetRef ref,
    PaydayScheduleEntry item,
  ) async {
    final bool? remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove schedule?'),
        content: const Text(
          'Linked allocations will be preserved and the schedule archived.',
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
    if (!context.mounted) return;
    if (remove == true) {
      await ref.read(financialRepositoryProvider).deletePaydaySchedule(item.id);
    }
  }

  static String _money(int minor) =>
      '${(minor ~/ 100)}.${(minor % 100).abs().toString().padLeft(2, '0')}';
  static String _label(String value) => value
      .split('_')
      .map(
        (String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}',
      )
      .join(' ');
  static String _allocationStatus(String status) => switch (status) {
    'completed' => 'Completed',
    'partial' => 'Partially fulfilled',
    'cancelled' => 'Cancelled',
    _ => 'Planned',
  };
  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  static void _message(BuildContext context, String message) =>
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
}

extension _DropdownListExtension<T> on List<DropdownMenuItem<T>> {
  void addIfEmpty(T value) {
    if (isEmpty) {
      add(DropdownMenuItem<T>(value: value, child: Text(value.toString())));
    }
  }
}
