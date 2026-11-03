import 'package:bill_tracker/app/theme/app_spacing.dart';
import 'package:bill_tracker/features/bills/domain/services/bill_schedule_calculator.dart';
import 'package:bill_tracker/features/dashboard/presentation/providers/financial_overview_providers.dart';
import 'package:bill_tracker/features/notifications/data/local_notification_service.dart';
import 'package:bill_tracker/features/notifications/domain/reminder_planner.dart';
import 'package:bill_tracker/features/planner/domain/services/payday_schedule_calculator.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final LocalNotificationService _service = LocalNotificationService();
  ReminderPreferences _preferences = const ReminderPreferences();
  bool _loading = true;
  String? _message;

  static const Map<String, String> _categories = <String, String>{
    'bills': 'Bills and recurring payments',
    'loans': 'Loan installments',
    'credit_cards': 'Credit card due dates',
    'paydays': 'Expected payday',
    'savings': 'Savings targets',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ReminderPreferences preferences = await _service.loadPreferences();
      if (mounted) {
        setState(() {
          _preferences = preferences;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = 'Reminder preferences could not be loaded: $error';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<BillEntry> bills =
        ref.watch(billsOverviewProvider).asData?.value ?? const <BillEntry>[];
    final List<BillPaymentEntry> payments =
        ref.watch(billPaymentsOverviewProvider).asData?.value ??
        const <BillPaymentEntry>[];
    final List<LoanEntry> loans =
        ref.watch(loansOverviewProvider).asData?.value ?? const <LoanEntry>[];
    final List<LoanInstallmentEntry> installments =
        ref.watch(installmentsOverviewProvider).asData?.value ??
        const <LoanInstallmentEntry>[];
    final List<FinancialAccount> accounts =
        ref.watch(walletManagementAccountsProvider).asData?.value ??
        const <FinancialAccount>[];
    final List<PaydayScheduleEntry> paydays =
        ref.watch(paydaySchedulesProvider).asData?.value ??
        const <PaydayScheduleEntry>[];
    final List<SavingsGoalEntry> goals =
        ref.watch(savingsGoalsOverviewProvider).asData?.value ??
        const <SavingsGoalEntry>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications and reminders')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.medium),
              children: <Widget>[
                const Text(
                  'Reminders are local to this device. They never record payments or change balances. Your operating system may suppress notifications based on device settings.',
                ),
                const SizedBox(height: AppSpacing.medium),
                Card(
                  child: Column(
                    children: <Widget>[
                      for (final MapEntry<String, String> entry
                          in _categories.entries)
                        SwitchListTile(
                          title: Text(entry.value),
                          value: _preferences.enabledCategories.contains(
                            entry.key,
                          ),
                          onChanged: (enabled) => _toggle(entry.key, enabled),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.small),
                DropdownButtonFormField<int>(
                  initialValue: _preferences.daysBefore,
                  decoration: const InputDecoration(
                    labelText: 'Reminder timing',
                  ),
                  items: const <DropdownMenuItem<int>>[
                    DropdownMenuItem(value: 0, child: Text('On due date')),
                    DropdownMenuItem(value: 1, child: Text('1 day before')),
                    DropdownMenuItem(value: 3, child: Text('3 days before')),
                    DropdownMenuItem(value: 7, child: Text('1 week before')),
                  ],
                  onChanged: (value) {
                    if (value != null) _save(_copy(daysBefore: value));
                  },
                ),
                const SizedBox(height: AppSpacing.small),
                OutlinedButton.icon(
                  onPressed: _chooseTime,
                  icon: const Icon(Icons.access_time),
                  label: Text(
                    'Preferred time · ${TimeOfDay(hour: _preferences.hour, minute: _preferences.minute).format(context)}',
                  ),
                ),
                const SizedBox(height: AppSpacing.small),
                FilledButton.icon(
                  onPressed: () => _schedule(
                    bills: bills,
                    payments: payments,
                    loans: loans,
                    installments: installments,
                    accounts: accounts,
                    paydays: paydays,
                    goals: goals,
                  ),
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text(
                    'Request permission and schedule reminders',
                  ),
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_message!),
                  ),
                const SizedBox(height: AppSpacing.large),
                Text(
                  'Reminder history',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.small),
                if (_preferences.history.isEmpty)
                  const Card(
                    child: ListTile(title: Text('No reminders scheduled yet.')),
                  )
                else
                  Card(
                    child: Column(
                      children: <Widget>[
                        for (final Map<String, Object?> item
                            in _preferences.history.reversed.take(50))
                          ListTile(
                            leading: Icon(
                              item['read'] == true
                                  ? Icons.notifications_none
                                  : Icons.notifications_active_outlined,
                            ),
                            title: Text(item['title'] as String? ?? 'Reminder'),
                            subtitle: Text(
                              'Scheduled ${DateFormat.yMMMd().add_jm().format(DateTime.tryParse(item['scheduled_at'] as String? ?? '')?.toLocal() ?? DateTime.now())}',
                            ),
                            trailing: item['read'] == true
                                ? const Text('Read')
                                : TextButton(
                                    onPressed: () =>
                                        _markRead(item['key'] as String? ?? ''),
                                    child: const Text('Mark read'),
                                  ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  ReminderPreferences _copy({
    Set<String>? categories,
    int? daysBefore,
    int? hour,
    int? minute,
  }) => ReminderPreferences(
    enabledCategories: categories ?? _preferences.enabledCategories,
    daysBefore: daysBefore ?? _preferences.daysBefore,
    hour: hour ?? _preferences.hour,
    minute: minute ?? _preferences.minute,
    history: _preferences.history,
  );

  Future<void> _save(ReminderPreferences value) async {
    await _service.savePreferences(value);
    if (mounted) {
      setState(() {
        _preferences = value;
        _message = 'Reminder preferences saved on this device.';
      });
    }
  }

  Future<void> _toggle(String category, bool enabled) async {
    final Set<String> categories = <String>{..._preferences.enabledCategories};
    if (enabled) {
      categories.add(category);
    } else {
      categories.remove(category);
    }
    await _save(_copy(categories: categories));
  }

  Future<void> _chooseTime() async {
    final TimeOfDay? value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _preferences.hour,
        minute: _preferences.minute,
      ),
    );
    if (value != null) {
      await _save(_copy(hour: value.hour, minute: value.minute));
    }
  }

  Future<void> _markRead(String key) async {
    await _service.markRead(key);
    await _load();
  }

  Future<void> _schedule({
    required List<BillEntry> bills,
    required List<BillPaymentEntry> payments,
    required List<LoanEntry> loans,
    required List<LoanInstallmentEntry> installments,
    required List<FinancialAccount> accounts,
    required List<PaydayScheduleEntry> paydays,
    required List<SavingsGoalEntry> goals,
  }) async {
    try {
      final bool allowed = await _service.requestPermission();
      if (!allowed) {
        setState(
          () => _message =
              'Notification permission was not granted. Change it in device settings to receive reminders.',
        );
        return;
      }
      final DateTime now = DateTime.now();
      final DateTime horizon = now.add(const Duration(days: 120));
      final List<ReminderCandidate> candidates = <ReminderCandidate>[];
      for (final BillEntry bill in bills.where((item) => item.isActive)) {
        final List<DateTime> dates = BillScheduleCalculator.occurrences(
          anchor: bill.dueDate,
          frequency: bill.frequency,
          start: DateTime(now.year, now.month, now.day),
          end: horizon,
        );
        for (final DateTime due in dates) {
          final BillOccurrence occurrence = BillOccurrence(
            bill: bill,
            dueDate: due,
          );
          final BillOccurrenceStatus status = occurrence.status(payments, now);
          if (status == BillOccurrenceStatus.paid ||
              status == BillOccurrenceStatus.skipped ||
              status == BillOccurrenceStatus.cancelled) {
            continue;
          }
          candidates.add(
            ReminderCandidate(
              key: 'bill:${bill.id}:${DateFormat('yyyy-MM-dd').format(due)}',
              title: status == BillOccurrenceStatus.overdue
                  ? 'Overdue bill'
                  : 'Upcoming bill',
              body: status == BillOccurrenceStatus.overdue
                  ? 'An overdue bill needs review in MyFinance.'
                  : 'A bill payment is coming up. Open MyFinance to review.',
              category: 'bills',
              dueAt: due,
              isOverdue: status == BillOccurrenceStatus.overdue,
            ),
          );
        }
        if (bill.frequency == 'one_time' && bill.dueDate.isBefore(now)) {
          final BillOccurrence occurrence = BillOccurrence(
            bill: bill,
            dueDate: bill.dueDate,
          );
          if (occurrence.status(payments, now) ==
              BillOccurrenceStatus.overdue) {
            candidates.add(
              ReminderCandidate(
                key:
                    'bill:${bill.id}:${DateFormat('yyyy-MM-dd').format(bill.dueDate)}',
                title: 'Overdue bill',
                body: 'An overdue bill needs review in MyFinance.',
                category: 'bills',
                dueAt: now,
                isOverdue: true,
              ),
            );
          }
        }
      }
      final Set<String> activeLoans = loans
          .where(
            (item) =>
                item.archivedAt == null &&
                item.status != 'paid' &&
                item.status != 'cancelled',
          )
          .map((item) => item.id)
          .toSet();
      final Map<String, LoanEntry> loanById = <String, LoanEntry>{
        for (final LoanEntry loan in loans) loan.id: loan,
      };
      for (final LoanInstallmentEntry item in installments.where(
        (row) =>
            activeLoans.contains(row.loanId) &&
            row.status != 'paid' &&
            row.status != 'settled',
      )) {
        final LoanEntry? loan = loanById[item.loanId];
        if (loan == null) continue;
        final bool overdue = item.dueDate.isBefore(
          DateTime(now.year, now.month, now.day),
        );
        candidates.add(
          ReminderCandidate(
            key:
                'loan:${item.id}:${DateFormat('yyyy-MM-dd').format(item.dueDate)}',
            title: overdue
                ? 'Overdue loan installment'
                : 'Upcoming loan installment',
            body: overdue
                ? 'An overdue installment needs review in MyFinance.'
                : 'A loan installment is coming up. Open MyFinance to review.',
            category: 'loans',
            dueAt: overdue ? now : item.dueDate,
            isOverdue: overdue,
          ),
        );
      }
      for (final FinancialAccount account in accounts.where(
        (item) =>
            item.isActive &&
            item.accountType == 'credit_card' &&
            item.paymentDueDate != null,
      )) {
        final DateTime due = account.paymentDueDate!;
        final DateTime nextDue =
            DateTime(
              now.year,
              due.month,
              due.day,
            ).isBefore(DateTime(now.year, now.month, now.day))
            ? DateTime(now.year + 1, due.month, due.day)
            : DateTime(now.year, due.month, due.day);
        candidates.add(
          ReminderCandidate(
            key:
                'card:${account.id}:${DateFormat('yyyy-MM-dd').format(nextDue)}',
            title: 'Credit card payment due',
            body:
                'A credit card payment is coming up. Open MyFinance to review.',
            category: 'credit_cards',
            dueAt: nextDue,
          ),
        );
      }
      for (final PaydayScheduleEntry payday in paydays.where(
        (item) => item.isActive && item.status != 'received',
      )) {
        for (final DateTime date in PaydayScheduleCalculator.occurrences(
          anchor: payday.paydayDate,
          frequency: payday.frequency,
          start: now,
          end: horizon,
        )) {
          candidates.add(
            ReminderCandidate(
              key:
                  'payday:${payday.id}:${DateFormat('yyyy-MM-dd').format(date)}',
              title: 'Expected payday',
              body:
                  'An expected income date is coming up. Open MyFinance to review.',
              category: 'paydays',
              dueAt: date,
            ),
          );
        }
      }
      for (final SavingsGoalEntry goal in goals.where(
        (item) =>
            item.status == 'active' &&
            item.targetDate != null &&
            item.contributionSchedule != null,
      )) {
        if (!goal.targetDate!.isBefore(now) &&
            !goal.targetDate!.isAfter(horizon)) {
          candidates.add(
            ReminderCandidate(
              key:
                  'savings:${goal.id}:${DateFormat('yyyy-MM-dd').format(goal.targetDate!)}',
              title: 'Savings goal reminder',
              body:
                  'A configured savings target date is coming up. Open MyFinance to review.',
              category: 'savings',
              dueAt: goal.targetDate!,
            ),
          );
        }
      }
      final int count = await _service.schedule(
        candidates: candidates,
        preferences: _preferences,
        permissionAlreadyGranted: true,
      );
      await _load();
      if (mounted) {
        setState(
          () => _message =
              '$count new reminder${count == 1 ? '' : 's'} scheduled. Existing reminders were not duplicated.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Could not schedule reminders: $error');
      }
    }
  }
}
