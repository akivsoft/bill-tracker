import 'package:bill_tracker/app/router/route_names.dart';
import 'package:bill_tracker/app/theme/app_spacing.dart';
import 'package:bill_tracker/core/utils/money.dart';
import 'package:bill_tracker/features/bills/domain/services/bill_schedule_calculator.dart';
import 'package:bill_tracker/features/dashboard/presentation/providers/financial_overview_providers.dart';
import 'package:bill_tracker/features/planner/domain/services/payday_schedule_calculator.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

enum _CalendarKind { income, bill, loan, credit, savings }

enum _CalendarView { month, week, day, agenda }

class _CalendarEvent {
  const _CalendarEvent({
    required this.title,
    required this.date,
    required this.amount,
    required this.currency,
    required this.kind,
    required this.status,
    required this.detail,
    required this.route,
  });
  final String title;
  final DateTime date;
  final int amount;
  final String currency;
  final _CalendarKind kind;
  final String status;
  final String detail;
  final String route;
}

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focus = DateTime.now();
  DateTime? _selectedDate;
  DateTimeRange? _customRange;
  _CalendarView _view = _CalendarView.month;

  @override
  Widget build(BuildContext context) {
    final bills =
        ref.watch(billsOverviewProvider).asData?.value ?? const <BillEntry>[];
    final billPayments =
        ref.watch(billPaymentsOverviewProvider).asData?.value ??
        const <BillPaymentEntry>[];
    final income =
        ref.watch(incomeOverviewProvider).asData?.value ??
        const <IncomeEntry>[];
    final installments =
        ref.watch(installmentsOverviewProvider).asData?.value ??
        const <LoanInstallmentEntry>[];
    final loans =
        ref.watch(loansOverviewProvider).asData?.value ?? const <LoanEntry>[];
    final accounts =
        ref.watch(walletManagementAccountsProvider).asData?.value ??
        const <FinancialAccount>[];
    final goals =
        ref.watch(savingsGoalsOverviewProvider).asData?.value ??
        const <SavingsGoalEntry>[];
    final paydays =
        ref.watch(paydaySchedulesProvider).asData?.value ??
        const <PaydayScheduleEntry>[];
    final DateTimeRange range = _range();
    final List<_CalendarEvent> events = _events(
      range: range,
      bills: bills,
      billPayments: billPayments,
      income: income,
      installments: installments,
      loans: loans,
      accounts: accounts,
      goals: goals,
      paydays: paydays,
    )..sort((_CalendarEvent a, _CalendarEvent b) => a.date.compareTo(b.date));
    final DateTime selected =
        _selectedDate ?? DateTime(_focus.year, _focus.month, _focus.day);
    final List<_CalendarEvent> visible = _view == _CalendarView.day
        ? events.where((e) => _sameDay(e.date, selected)).toList()
        : _view == _CalendarView.week
        ? events
              .where(
                (e) =>
                    !e.date.isBefore(range.start) && !e.date.isAfter(range.end),
              )
              .toList()
        : _view == _CalendarView.month && _selectedDate != null
        ? events.where((e) => _sameDay(e.date, selected)).toList()
        : events;
    final int expectedIncome = events
        .where((e) => e.kind == _CalendarKind.income && e.status == 'Expected')
        .fold<int>(0, (s, e) => s + e.amount);
    final int planned = events
        .where(
          (e) =>
              e.kind != _CalendarKind.income &&
              e.status != 'Paid' &&
              e.status != 'Received',
        )
        .fold<int>(0, (s, e) => s + e.amount);
    final String currency = accounts.isEmpty
        ? 'PHP'
        : accounts.first.currencyCode;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial calendar'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Previous period',
            onPressed: () => _move(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Next period',
            onPressed: () => _move(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.medium),
        children: <Widget>[
          DropdownButtonFormField<_CalendarView>(
            initialValue: _view,
            decoration: const InputDecoration(labelText: 'Calendar view'),
            items: const <DropdownMenuItem<_CalendarView>>[
              DropdownMenuItem(
                value: _CalendarView.month,
                child: Text('Monthly'),
              ),
              DropdownMenuItem(
                value: _CalendarView.week,
                child: Text('Weekly'),
              ),
              DropdownMenuItem(value: _CalendarView.day, child: Text('Daily')),
              DropdownMenuItem(
                value: _CalendarView.agenda,
                child: Text('Agenda'),
              ),
            ],
            onChanged: (v) => setState(() {
              _view = v ?? _view;
              _selectedDate = null;
            }),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _rangeTitle(range),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton.icon(
                onPressed: _chooseRange,
                icon: const Icon(Icons.date_range),
                label: const Text('Custom'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _legend(context, _CalendarKind.income, 'Income'),
              _legend(context, _CalendarKind.bill, 'Bills'),
              _legend(context, _CalendarKind.loan, 'Loans'),
              _legend(context, _CalendarKind.credit, 'Credit card'),
              _legend(context, _CalendarKind.savings, 'Savings'),
            ],
          ),
          const SizedBox(height: AppSpacing.small),
          if (_view == _CalendarView.month) _monthDays(events, range),
          if (_view == _CalendarView.week) _weekDays(events, range),
          if (_view == _CalendarView.day) _dayStrip(events),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.medium),
              child: Wrap(
                spacing: 24,
                runSpacing: 8,
                children: <Widget>[
                  _metric('Expected income', expectedIncome, currency),
                  _metric('Upcoming commitments', planned, currency),
                  _metric(
                    'Forecast remaining',
                    expectedIncome - planned,
                    currency,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            _view == _CalendarView.day
                ? 'Events · ${DateFormat.yMMMd().format(selected)}'
                : 'Agenda',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (visible.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No financial events in this period.'),
              ),
            ),
          ...visible.map(
            (event) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _color(
                    context,
                    event.kind,
                  ).withValues(alpha: .15),
                  child: Icon(
                    _icon(event.kind),
                    color: _color(context, event.kind),
                  ),
                ),
                title: Text(event.title),
                subtitle: Text(
                  '${DateFormat.yMMMd().format(event.date)} · ${event.detail} · ${event.status}',
                ),
                trailing: Text(
                  Money(event.amount, currencyCode: event.currency).format(),
                  textAlign: TextAlign.end,
                ),
                onTap: () => _openEvent(event),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          Text(
            'Recurring events are projected from their existing records and schedules. Calendar views do not create duplicate bills or installments.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  List<_CalendarEvent> _events({
    required DateTimeRange range,
    required List<BillEntry> bills,
    required List<BillPaymentEntry> billPayments,
    required List<IncomeEntry> income,
    required List<LoanInstallmentEntry> installments,
    required List<LoanEntry> loans,
    required List<FinancialAccount> accounts,
    required List<SavingsGoalEntry> goals,
    required List<PaydayScheduleEntry> paydays,
  }) {
    final List<_CalendarEvent> result = <_CalendarEvent>[];
    for (final BillEntry bill in bills.where((b) => b.isActive)) {
      for (final DateTime date in BillScheduleCalculator.occurrences(
        anchor: bill.dueDate,
        frequency: bill.frequency,
        start: bill.frequency == 'one_time' ? bill.dueDate : range.start,
        end: range.end,
      )) {
        final BillOccurrence occurrence = BillOccurrence(
          bill: bill,
          dueDate: date,
        );
        final BillOccurrenceStatus status = occurrence.status(
          billPayments,
          DateTime.now(),
        );
        result.add(
          _CalendarEvent(
            title: bill.name,
            date: date,
            amount: bill.amountMinorUnits,
            currency: bill.currencyCode,
            kind: _CalendarKind.bill,
            status: _billStatus(status),
            detail: 'Bill',
            route: RouteNames.billsPath,
          ),
        );
      }
    }
    for (final IncomeEntry item in income.where(
      (i) => i.status == 'expected' || i.status == 'received',
    )) {
      if (item.status == 'received') {
        final DateTime date = item.actualReceivedAt ?? item.expectedDate;
        final bool matchedPayday = paydays.any(
          (PaydayScheduleEntry p) =>
              p.name.toLowerCase() == item.source.toLowerCase() &&
              p.currencyCode == item.currencyCode &&
              PaydayScheduleCalculator.occurrences(
                anchor: p.paydayDate,
                frequency: p.frequency,
                start: date,
                end: date,
              ).isNotEmpty,
        );
        if (_within(date, range) && !matchedPayday) {
          result.add(
            _CalendarEvent(
              title: item.source,
              date: date,
              amount: item.amountMinorUnits,
              currency: item.currencyCode,
              kind: _CalendarKind.income,
              status: 'Received',
              detail: 'Income',
              route: RouteNames.moreModule('income'),
            ),
          );
        }
      } else {
        final String frequency = item.frequency == 'one_time'
            ? 'irregular'
            : item.frequency == 'annual'
            ? 'yearly'
            : item.frequency;
        for (final DateTime date in PaydayScheduleCalculator.occurrences(
          anchor: item.expectedDate,
          frequency: frequency,
          start: range.start,
          end: range.end,
        )) {
          final bool matchedPayday = paydays.any(
            (PaydayScheduleEntry p) =>
                p.name.toLowerCase() == item.source.toLowerCase() &&
                p.currencyCode == item.currencyCode &&
                PaydayScheduleCalculator.occurrences(
                  anchor: p.paydayDate,
                  frequency: p.frequency,
                  start: date,
                  end: date,
                ).isNotEmpty,
          );
          if (!matchedPayday) {
            result.add(
              _CalendarEvent(
                title: item.source,
                date: date,
                amount: item.amountMinorUnits,
                currency: item.currencyCode,
                kind: _CalendarKind.income,
                status: 'Expected',
                detail: 'Expected income',
                route: RouteNames.moreModule('income'),
              ),
            );
          }
        }
      }
    }
    for (final PaydayScheduleEntry payday in paydays.where((p) => p.isActive)) {
      for (final DateTime date in PaydayScheduleCalculator.occurrences(
        anchor: payday.paydayDate,
        frequency: payday.frequency,
        start: range.start,
        end: range.end,
      )) {
        final IncomeEntry? linkedIncome = income
            .where(
              (IncomeEntry item) =>
                  item.status == 'received' &&
                  item.source.toLowerCase() == payday.name.toLowerCase() &&
                  item.currencyCode == payday.currencyCode &&
                  _sameDay(item.actualReceivedAt ?? item.expectedDate, date),
            )
            .firstOrNull;
        final bool received =
            linkedIncome != null ||
            (payday.status == 'received' &&
                payday.actualReceivedAt != null &&
                _sameDay(date, payday.actualReceivedAt!));
        result.add(
          _CalendarEvent(
            title: payday.name,
            date: date,
            amount: received
                ? linkedIncome?.amountMinorUnits ??
                      payday.actualIncomeMinorUnits
                : payday.expectedIncomeMinorUnits,
            currency: payday.currencyCode,
            kind: _CalendarKind.income,
            status: received ? 'Received' : 'Expected',
            detail: 'Payday',
            route: RouteNames.moreModule('planner'),
          ),
        );
      }
    }
    for (final LoanInstallmentEntry item in installments.where(
      (i) => i.status != 'settled',
    )) {
      final LoanEntry? loan = loans
          .where((l) => l.id == item.loanId)
          .firstOrNull;
      if (loan != null && _within(item.dueDate, range)) {
        result.add(
          _CalendarEvent(
            title: loan.name,
            date: item.dueDate,
            amount: (item.scheduledMinorUnits - item.paidMinorUnits).clamp(
              0,
              item.scheduledMinorUnits,
            ),
            currency: loan.currencyCode,
            kind: _CalendarKind.loan,
            status: item.status == 'paid'
                ? 'Paid'
                : item.dueDate.isBefore(DateTime.now())
                ? 'Overdue'
                : item.status == 'partial'
                ? 'Partially paid'
                : 'Upcoming',
            detail: 'Loan installment ${item.installmentNumber}',
            route: RouteNames.loansPath,
          ),
        );
      }
    }
    for (final FinancialAccount account in accounts.where(
      (a) =>
          a.isActive &&
          a.archivedAt == null &&
          a.accountType == 'credit_card' &&
          a.paymentDueDate != null,
    )) {
      final DateTime anchor = account.paymentDueDate!;
      for (final DateTime date in BillScheduleCalculator.occurrences(
        anchor: anchor,
        frequency: 'monthly',
        start: range.start,
        end: range.end,
      )) {
        result.add(
          _CalendarEvent(
            title: '${account.name} payment due',
            date: date,
            amount: account.outstandingCreditMinorUnits == 0
                ? 0
                : account.minimumPaymentMinorUnits,
            currency: account.currencyCode,
            kind: _CalendarKind.credit,
            status: account.outstandingCreditMinorUnits == 0
                ? 'Paid'
                : _sameDay(date, DateTime.now())
                ? 'Due today'
                : date.isBefore(DateTime.now())
                ? 'Overdue'
                : 'Upcoming',
            detail: 'Credit card minimum payment',
            route: RouteNames.walletAccount(account.id),
          ),
        );
      }
    }
    for (final SavingsGoalEntry goal in goals.where(
      (g) => g.status == 'active' && g.targetDate != null,
    )) {
      if (_within(goal.targetDate!, range)) {
        result.add(
          _CalendarEvent(
            title: goal.name,
            date: goal.targetDate!,
            amount: (goal.targetAmountMinorUnits - goal.currentAmountMinorUnits)
                .clamp(0, goal.targetAmountMinorUnits),
            currency: goal.currencyCode,
            kind: _CalendarKind.savings,
            status: 'Target date',
            detail: 'Savings goal',
            route: RouteNames.moreModule('savings'),
          ),
        );
      }
    }
    return result;
  }

  Widget _monthDays(List<_CalendarEvent> events, DateTimeRange range) {
    final int days = DateTime(_focus.year, _focus.month + 1, 0).day;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List<Widget>.generate(days, (i) {
        final DateTime date = DateTime(_focus.year, _focus.month, i + 1);
        final int count = events.where((e) => _sameDay(e.date, date)).length;
        return ChoiceChip(
          label: Text('${date.day}${count == 0 ? '' : ' · $count'}'),
          selected: _selectedDate != null && _sameDay(_selectedDate!, date),
          onSelected: (_) => setState(() => _selectedDate = date),
        );
      }),
    );
  }

  Widget _weekDays(List<_CalendarEvent> events, DateTimeRange range) => Wrap(
    spacing: 6,
    children: List<Widget>.generate(7, (i) {
      final DateTime date = range.start.add(Duration(days: i));
      final int count = events.where((e) => _sameDay(e.date, date)).length;
      return ChoiceChip(
        label: Text(
          '${DateFormat.E().format(date)} ${date.day}${count == 0 ? '' : ' · $count'}',
        ),
        selected: _selectedDate != null && _sameDay(_selectedDate!, date),
        onSelected: (_) => setState(() => _selectedDate = date),
      );
    }),
  );

  Widget _dayStrip(List<_CalendarEvent> events) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: <Widget>[
      IconButton(
        onPressed: () => setState(() {
          _focus = _focus.subtract(const Duration(days: 1));
          _selectedDate = _focus;
        }),
        icon: const Icon(Icons.chevron_left),
      ),
      Text(DateFormat.yMMMMEEEEd().format(_selectedDate ?? _focus)),
      IconButton(
        onPressed: () => setState(() {
          _focus = _focus.add(const Duration(days: 1));
          _selectedDate = _focus;
        }),
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );

  DateTimeRange _range() {
    if (_customRange != null) return _customRange!;
    switch (_view) {
      case _CalendarView.month:
        return DateTimeRange(
          start: DateTime(_focus.year, _focus.month),
          end: DateTime(_focus.year, _focus.month + 1, 0),
        );
      case _CalendarView.week:
        final DateTime day = _selectedDate ?? _focus;
        final int offset = day.weekday - DateTime.monday;
        final DateTime start = DateTime(day.year, day.month, day.day - offset);
        return DateTimeRange(
          start: start,
          end: start.add(const Duration(days: 6)),
        );
      case _CalendarView.day:
        final DateTime day = _selectedDate ?? _focus;
        return DateTimeRange(
          start: DateTime(day.year, day.month, day.day),
          end: DateTime(day.year, day.month, day.day),
        );
      case _CalendarView.agenda:
        return DateTimeRange(
          start: DateTime(_focus.year, _focus.month),
          end: DateTime(_focus.year, _focus.month + 1, 0),
        );
    }
  }

  Future<void> _chooseRange() async {
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _customRange,
    );
    if (range != null) {
      setState(() {
        _customRange = range;
        _view = _CalendarView.agenda;
      });
    }
  }

  void _move(int direction) => setState(() {
    _customRange = null;
    switch (_view) {
      case _CalendarView.day:
        _focus = _focus.add(Duration(days: direction));
      case _CalendarView.week:
        _focus = _focus.add(Duration(days: 7 * direction));
      case _CalendarView.month:
      case _CalendarView.agenda:
        _focus = DateTime(_focus.year, _focus.month + direction, 1);
    }
    _selectedDate = _focus;
  });

  void _openEvent(_CalendarEvent event) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ListTile(
                leading: Icon(
                  _icon(event.kind),
                  color: _color(context, event.kind),
                ),
                title: Text(event.title),
                subtitle: Text(event.detail),
              ),
              Text(DateFormat.yMMMMEEEEd().format(event.date)),
              Text(Money(event.amount, currencyCode: event.currency).format()),
              Text('Status: ${event.status}'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go(event.route);
                },
                child: const Text('Open related module'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legend(BuildContext context, _CalendarKind kind, String label) =>
      Chip(
        avatar: Icon(_icon(kind), size: 16, color: _color(context, kind)),
        label: Text(label),
      );
  Widget _metric(String title, int value, String currency) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(title, style: Theme.of(context).textTheme.bodySmall),
      Text(
        Money(value, currencyCode: currency).format(),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ],
  );
  Color _color(BuildContext context, _CalendarKind kind) => switch (kind) {
    _CalendarKind.income => Colors.green,
    _CalendarKind.bill => Theme.of(context).colorScheme.primary,
    _CalendarKind.loan => Colors.deepOrange,
    _CalendarKind.credit => Colors.purple,
    _CalendarKind.savings => Colors.teal,
  };
  IconData _icon(_CalendarKind kind) => switch (kind) {
    _CalendarKind.income => Icons.south_west,
    _CalendarKind.bill => Icons.receipt_long,
    _CalendarKind.loan => Icons.account_balance,
    _CalendarKind.credit => Icons.credit_card,
    _CalendarKind.savings => Icons.savings,
  };
  String _billStatus(BillOccurrenceStatus status) => switch (status) {
    BillOccurrenceStatus.upcoming => 'Upcoming',
    BillOccurrenceStatus.unpaid => 'Unpaid',
    BillOccurrenceStatus.partiallyPaid => 'Partially paid',
    BillOccurrenceStatus.paid => 'Paid',
    BillOccurrenceStatus.overdue => 'Overdue',
    BillOccurrenceStatus.skipped => 'Skipped',
    BillOccurrenceStatus.cancelled => 'Inactive',
  };
  String _rangeTitle(DateTimeRange range) => _customRange != null
      ? '${DateFormat.yMMMd().format(range.start)} – ${DateFormat.yMMMd().format(range.end)}'
      : switch (_view) {
          _CalendarView.month ||
          _CalendarView.agenda => DateFormat.yMMMM().format(_focus),
          _CalendarView.week =>
            '${DateFormat.MMMd().format(range.start)} – ${DateFormat.MMMd().format(range.end)}',
          _CalendarView.day => DateFormat.yMMMd().format(range.start),
        };
  static bool _within(DateTime date, DateTimeRange range) =>
      !DateTime(date.year, date.month, date.day).isBefore(
        DateTime(range.start.year, range.start.month, range.start.day),
      ) &&
      !DateTime(
        date.year,
        date.month,
        date.day,
      ).isAfter(DateTime(range.end.year, range.end.month, range.end.day));
  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
