import 'package:bill_tracker/features/dashboard/presentation/providers/financial_overview_providers.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/reminder_candidate_builder.dart';
import '../domain/reminder_planner.dart';
import 'local_notification_service.dart';

abstract final class ReminderScheduleCoordinator {
  static Future<void> _queue = Future<void>.value();

  static Future<void> synchronize(WidgetRef ref) {
    final _ReminderSnapshot? snapshot = _snapshot(ref);
    if (snapshot == null) return Future<void>.value();
    final Future<void> next = _queue
        .catchError((Object _) {})
        .then((_) => _synchronize(snapshot));
    _queue = next.catchError((Object _) {});
    return next;
  }

  static _ReminderSnapshot? _snapshot(WidgetRef ref) {
    final bills = ref.read(billsOverviewProvider).asData?.value;
    final payments = ref.read(billPaymentsOverviewProvider).asData?.value;
    final loans = ref.read(loansOverviewProvider).asData?.value;
    final installments = ref.read(installmentsOverviewProvider).asData?.value;
    final accounts = ref.read(walletManagementAccountsProvider).asData?.value;
    final paydays = ref.read(paydaySchedulesProvider).asData?.value;
    final goals = ref.read(savingsGoalsOverviewProvider).asData?.value;
    if (bills == null ||
        payments == null ||
        loans == null ||
        installments == null ||
        accounts == null ||
        paydays == null ||
        goals == null) {
      return null;
    }
    return _ReminderSnapshot(
      bills: bills,
      payments: payments,
      loans: loans,
      installments: installments,
      accounts: accounts,
      paydays: paydays,
      goals: goals,
    );
  }

  static Future<void> _synchronize(_ReminderSnapshot snapshot) async {
    final LocalNotificationService service = LocalNotificationService.instance;
    final ReminderPreferences preferences = await service.loadPreferences();
    final NotificationDeviceState device = await service.deviceState();
    if (device.permission != NotificationPermissionState.granted ||
        !device.exactAlarmsAllowed) {
      return;
    }
    final DateTime now = DateTime.now();
    final candidates = ReminderCandidateBuilder.build(
      bills: snapshot.bills,
      payments: snapshot.payments,
      loans: snapshot.loans,
      installments: snapshot.installments,
      accounts: snapshot.accounts,
      paydays: snapshot.paydays,
      goals: snapshot.goals,
      now: now,
      calendarReminderAt: preferences.calendarReminderAt,
    );
    await service.schedule(candidates: candidates, preferences: preferences);
  }

  static Future<bool> hasSchedulableReminders(WidgetRef ref) async {
    final _ReminderSnapshot? snapshot = _snapshot(ref);
    if (snapshot == null) return false;
    final ReminderPreferences preferences = await LocalNotificationService.instance.loadPreferences();
    final DateTime now = DateTime.now();
    final List<ReminderCandidate> candidates = ReminderCandidateBuilder.build(
      bills: snapshot.bills,
      payments: snapshot.payments,
      loans: snapshot.loans,
      installments: snapshot.installments,
      accounts: snapshot.accounts,
      paydays: snapshot.paydays,
      goals: snapshot.goals,
      now: now,
      calendarReminderAt: preferences.calendarReminderAt,
    );
    return ReminderPlanner.plan(
      candidates: candidates,
      enabledCategories: preferences.enabledCategories,
      daysBefore: preferences.daysBefore,
      hour: preferences.hour,
      minute: preferences.minute,
      now: now,
      alreadyScheduledKeys: const <String>{},
    ).isNotEmpty;
  }
}

final class _ReminderSnapshot {
  const _ReminderSnapshot({
    required this.bills,
    required this.payments,
    required this.loans,
    required this.installments,
    required this.accounts,
    required this.paydays,
    required this.goals,
  });

  final List<BillEntry> bills;
  final List<BillPaymentEntry> payments;
  final List<LoanEntry> loans;
  final List<LoanInstallmentEntry> installments;
  final List<FinancialAccount> accounts;
  final List<PaydayScheduleEntry> paydays;
  final List<SavingsGoalEntry> goals;
}
