import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminder_planner.dart';

final class ReminderPreferences {
  const ReminderPreferences({
    this.enabledCategories = const <String>{
      'bills',
      'loans',
      'credit_cards',
      'paydays',
    },
    this.daysBefore = 1,
    this.hour = 9,
    this.minute = 0,
    this.history = const <Map<String, Object?>>[],
  });
  final Set<String> enabledCategories;
  final int daysBefore;
  final int hour;
  final int minute;
  final List<Map<String, Object?>> history;

  Map<String, Object?> toJson() => <String, Object?>{
    'enabled_categories': enabledCategories.toList()..sort(),
    'days_before': daysBefore,
    'hour': hour,
    'minute': minute,
    'history': history,
  };

  factory ReminderPreferences.fromJson(Map<String, Object?> json) =>
      ReminderPreferences(
        enabledCategories:
            (json['enabled_categories'] as List<Object?>?)
                ?.whereType<String>()
                .toSet() ??
            const <String>{},
        daysBefore: (json['days_before'] as int?)?.clamp(0, 30) ?? 1,
        hour: (json['hour'] as int?)?.clamp(0, 23) ?? 9,
        minute: (json['minute'] as int?)?.clamp(0, 59) ?? 0,
        history:
            (json['history'] as List<Object?>?)
                ?.whereType<Map<String, Object?>>()
                .toList(growable: false) ??
            const <Map<String, Object?>>[],
      );
}

final class LocalNotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    _refreshDeviceTimezone();
    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    final bool? android = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    final bool? ios = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return android ?? ios ?? true;
  }

  Future<ReminderPreferences> loadPreferences() async {
    final File file = await _preferencesFile();
    if (!await file.exists()) return const ReminderPreferences();
    final Object? decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, Object?>) return const ReminderPreferences();
    final List<Object?> history = decoded['history'] is List<Object?>
        ? decoded['history']! as List<Object?>
        : const <Object?>[];
    return ReminderPreferences(
      enabledCategories:
          (decoded['enabled_categories'] as List<Object?>?)
              ?.whereType<String>()
              .toSet() ??
          const <String>{},
      daysBefore: (decoded['days_before'] as int?)?.clamp(0, 30) ?? 1,
      hour: (decoded['hour'] as int?)?.clamp(0, 23) ?? 9,
      minute: (decoded['minute'] as int?)?.clamp(0, 59) ?? 0,
      history: history.whereType<Map<String, Object?>>().toList(
        growable: false,
      ),
    );
  }

  Future<void> savePreferences(ReminderPreferences preferences) async {
    final File file = await _preferencesFile();
    await file.writeAsString(jsonEncode(preferences.toJson()), flush: true);
  }

  Future<int> schedule({
    required Iterable<ReminderCandidate> candidates,
    required ReminderPreferences preferences,
    bool permissionAlreadyGranted = false,
  }) async {
    await initialize();
    _refreshDeviceTimezone();
    final bool permitted =
        permissionAlreadyGranted || await requestPermission();
    if (!permitted) return 0;
    final List<PendingNotificationRequest> pending = await _plugin
        .pendingNotificationRequests();
    final Set<String> knownKeys = preferences.history
        .map((item) => item['key'])
        .whereType<String>()
        .toSet();
    final Set<int> pendingIds = pending.map((item) => item.id).toSet();
    final List<PlannedReminder> planned = ReminderPlanner.plan(
      candidates: candidates,
      enabledCategories: preferences.enabledCategories,
      daysBefore: preferences.daysBefore,
      hour: preferences.hour,
      minute: preferences.minute,
      now: DateTime.now(),
      alreadyScheduledKeys: knownKeys,
    ).where((item) => !pendingIds.contains(item.id)).toList();
    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        'myfinance_reminders',
        'MyFinance reminders',
        channelDescription: 'Upcoming bills, repayments, and payday reminders.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );
    final Map<String, ReminderCandidate> byKey = <String, ReminderCandidate>{
      for (final ReminderCandidate item in candidates) item.key: item,
    };
    final List<Map<String, Object?>> history = <Map<String, Object?>>[
      ...preferences.history,
    ];
    for (final PlannedReminder reminder in planned) {
      final ReminderCandidate candidate = byKey[reminder.key]!;
      final tz.TZDateTime scheduled = tz.TZDateTime.from(reminder.at, tz.local);
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: candidate.title,
        body: candidate.body,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: reminder.key,
      );
      history.add(<String, Object?>{
        'key': reminder.key,
        'title': candidate.title,
        'body': candidate.body,
        'category': candidate.category,
        'scheduled_at': reminder.at.toIso8601String(),
        'read': false,
      });
    }
    await savePreferences(
      ReminderPreferences(
        enabledCategories: preferences.enabledCategories,
        daysBefore: preferences.daysBefore,
        hour: preferences.hour,
        minute: preferences.minute,
        history: history,
      ),
    );
    return planned.length;
  }

  Future<void> markRead(String key) async {
    final ReminderPreferences current = await loadPreferences();
    final List<Map<String, Object?>> history = current.history
        .map(
          (item) => item['key'] == key
              ? <String, Object?>{...item, 'read': true}
              : item,
        )
        .toList(growable: false);
    await savePreferences(
      ReminderPreferences(
        enabledCategories: current.enabledCategories,
        daysBefore: current.daysBefore,
        hour: current.hour,
        minute: current.minute,
        history: history,
      ),
    );
  }

  Future<File> _preferencesFile() async {
    final Directory directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return File('${directory.path}/reminder_preferences.json');
  }

  void _refreshDeviceTimezone() {
    final DateTime localNow = DateTime.now();
    tz.setLocalLocation(
      tz.Location(
        'device-local',
        <int>[-8640000000000000],
        const <int>[0],
        <tz.TimeZone>[
          tz.TimeZone(
            localNow.timeZoneOffset,
            isDst: false,
            abbreviation: localNow.timeZoneName,
          ),
        ],
      ),
    );
  }
}
