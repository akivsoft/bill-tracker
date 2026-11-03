final class ReminderCandidate {
  const ReminderCandidate({
    required this.key,
    required this.title,
    required this.body,
    required this.category,
    required this.dueAt,
    this.isOverdue = false,
  });

  final String key;
  final String title;
  final String body;
  final String category;
  final DateTime dueAt;
  final bool isOverdue;
}

final class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.key,
    required this.at,
  });
  final int id;
  final String key;
  final DateTime at;
}

abstract final class ReminderPlanner {
  static List<PlannedReminder> plan({
    required Iterable<ReminderCandidate> candidates,
    required Set<String> enabledCategories,
    required int daysBefore,
    required int hour,
    required int minute,
    required DateTime now,
    required Set<String> alreadyScheduledKeys,
  }) {
    final Set<int> usedIds = <int>{};
    final List<PlannedReminder> result = <PlannedReminder>[];
    for (final ReminderCandidate item in candidates) {
      if (!enabledCategories.contains(item.category) ||
          alreadyScheduledKeys.contains(item.key)) {
        continue;
      }
      final DateTime due = item.dueAt.toLocal();
      DateTime at = item.isOverdue
          ? now.add(const Duration(minutes: 1))
          : DateTime(due.year, due.month, due.day - daysBefore, hour, minute);
      if (at.isBefore(now)) continue;
      int id = _stableId(item.key);
      while (!usedIds.add(id)) {
        id = (id + 1) & 0x7fffffff;
      }
      result.add(PlannedReminder(id: id, key: item.key, at: at));
    }
    result.sort((a, b) => a.at.compareTo(b.at));
    return result;
  }

  static int _stableId(String key) {
    int hash = 0x811c9dc5;
    for (final int code in key.codeUnits) {
      hash = ((hash ^ code) * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
