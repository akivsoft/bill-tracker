import 'package:bill_tracker/features/notifications/domain/reminder_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('schedules enabled reminders once at the configured local time', () {
    final List<PlannedReminder> result = ReminderPlanner.plan(
      candidates: <ReminderCandidate>[
        ReminderCandidate(
          key: 'bill:rent:2026-12-01',
          title: 'Upcoming bill',
          body: 'Rent',
          category: 'bills',
          dueAt: DateTime(2026, 12, 1, 17),
        ),
        ReminderCandidate(
          key: 'loan:past',
          title: 'Overdue loan',
          body: 'Loan',
          category: 'loans',
          dueAt: DateTime(2026, 11, 1),
        ),
        ReminderCandidate(
          key: 'payday:disabled',
          title: 'Payday',
          body: 'Salary',
          category: 'paydays',
          dueAt: DateTime(2026, 12, 1),
        ),
      ],
      enabledCategories: const <String>{'bills', 'loans'},
      daysBefore: 1,
      hour: 8,
      minute: 30,
      now: DateTime(2026, 11, 20),
      alreadyScheduledKeys: const <String>{'loan:past'},
    );

    expect(result, hasLength(1));
    expect(result.single.key, 'bill:rent:2026-12-01');
    expect(result.single.at, DateTime(2026, 11, 30, 8, 30));
  });

  test('does not schedule reminders whose lead time is already past', () {
    final List<PlannedReminder> result = ReminderPlanner.plan(
      candidates: <ReminderCandidate>[
        ReminderCandidate(
          key: 'bill:due',
          title: 'Due',
          body: 'Bill',
          category: 'bills',
          dueAt: DateTime(2026, 11, 20),
        ),
      ],
      enabledCategories: const <String>{'bills'},
      daysBefore: 1,
      hour: 9,
      minute: 0,
      now: DateTime(2026, 11, 20, 10),
      alreadyScheduledKeys: const <String>{},
    );
    expect(result, isEmpty);
  });
}
