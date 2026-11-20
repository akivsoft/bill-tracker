import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminder_planner.dart';

enum NotificationPermissionState {
  granted,
  denied,
  permanentlyDenied,
  unsupported,
}

final class NotificationDeviceState {
  const NotificationDeviceState({
    required this.permission,
    required this.exactAlarmsAllowed,
    this.shouldShowPermissionRationale = false,
  });

  final NotificationPermissionState permission;
  final bool exactAlarmsAllowed;
  final bool shouldShowPermissionRationale;
}

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
    this.calendarReminderAt,
    this.history = const <Map<String, Object?>>[],
  });
  final Set<String> enabledCategories;
  final int daysBefore;
  final int hour;
  final int minute;
  final DateTime? calendarReminderAt;
  final List<Map<String, Object?>> history;

  Map<String, Object?> toJson() => <String, Object?>{
    'enabled_categories': enabledCategories.toList()..sort(),
    'days_before': daysBefore,
    'hour': hour,
    'minute': minute,
    'calendar_reminder_at': calendarReminderAt?.toIso8601String(),
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
        calendarReminderAt: DateTime.tryParse(
          json['calendar_reminder_at'] as String? ?? '',
        ),
        history:
            (json['history'] as List<Object?>?)
                ?.whereType<Map<String, Object?>>()
                .toList(growable: false) ??
            const <Map<String, Object?>>[],
      );
}

final class LocalNotificationService {
  static final LocalNotificationService instance = LocalNotificationService();

  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const MethodChannel _platform = MethodChannel(
    'com.myfinance.billtracker/notifications',
  );
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  Future<void>? _initializing;
  String? _deviceTimeZoneId;
  void Function(String? payload)? _onNotificationTap;

  Future<void> initialize({
    void Function(String? payload)? onNotificationTap,
  }) async {
    if (onNotificationTap != null) _onNotificationTap = onNotificationTap;
    if (_initialized) return;
    final Future<void>? activeInitialization = _initializing;
    if (activeInitialization != null) {
      await activeInitialization;
      return;
    }
    final Future<void> initialization = _initialize();
    _initializing = initialization;
    try {
      await initialization;
    } catch (_) {
      if (identical(_initializing, initialization)) _initializing = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    tz_data.initializeTimeZones();
    await _refreshDeviceTimezone();
    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _onNotificationTap?.call(response.payload);
      },
    );
    _initialized = true;
    final NotificationAppLaunchDetails? launch = await _plugin
        .getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      _onNotificationTap?.call(launch?.notificationResponse?.payload);
    }
  }

  Future<NotificationDeviceState> deviceState() async {
    await initialize();
    if (Platform.isAndroid) {
      final Map<Object?, Object?>? state = await _platform
          .invokeMapMethod<Object?, Object?>('deviceState');
      return NotificationDeviceState(
        permission: state?['notificationsEnabled'] == true
            ? NotificationPermissionState.granted
            : state?['permanentlyDenied'] == true
            ? NotificationPermissionState.permanentlyDenied
            : NotificationPermissionState.denied,
        exactAlarmsAllowed: state?['exactAlarmAllowed'] == true,
        shouldShowPermissionRationale: state?['shouldShowRationale'] == true,
      );
    }
    if (Platform.isIOS) {
      final NotificationsEnabledOptions? status = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();
      return NotificationDeviceState(
        permission:
            status?.isEnabled == true || status?.isProvisionalEnabled == true
            ? NotificationPermissionState.granted
            : NotificationPermissionState.denied,
        exactAlarmsAllowed: true,
      );
    }
    return const NotificationDeviceState(
      permission: NotificationPermissionState.unsupported,
      exactAlarmsAllowed: false,
    );
  }

  Future<bool> requestPermission() async {
    await initialize();
    final NotificationDeviceState current = await deviceState();
    if (current.permission == NotificationPermissionState.granted) return true;
    if (current.permission == NotificationPermissionState.permanentlyDenied) {
      return false;
    }
    if (Platform.isAndroid) {
      await _platform.invokeMethod<void>('markNotificationPermissionRequested');
      final bool? granted = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return granted == true &&
          (await deviceState()).permission ==
              NotificationPermissionState.granted;
    }
    if (Platform.isIOS) {
      final bool? granted = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted == true;
    }
    return false;
  }

  Future<bool> requestExactAlarmAccess() async {
    if (!Platform.isAndroid) return true;
    if ((await deviceState()).exactAlarmsAllowed) return true;
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestExactAlarmsPermission();
    return (await deviceState()).exactAlarmsAllowed;
  }

  Future<void> openNotificationSettings() async {
    if (Platform.isAndroid) {
      await _platform.invokeMethod<void>('openNotificationSettings');
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.openAppNotificationSettings();
    }
  }

  Future<Set<String>> pendingKeys() async {
    await initialize();
    return (await _plugin.pendingNotificationRequests())
        .map((PendingNotificationRequest item) => item.payload)
        .whereType<String>()
        .toSet();
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
      calendarReminderAt: DateTime.tryParse(
        decoded['calendar_reminder_at'] as String? ?? '',
      ),
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
  }) async {
    await initialize();
    await _refreshDeviceTimezone();
    final NotificationDeviceState device = await deviceState();
    final List<PendingNotificationRequest> pending = await _plugin
        .pendingNotificationRequests();
    final List<ReminderCandidate> candidateList = candidates.toList();
    final List<Map<String, Object?>> history = <Map<String, Object?>>[
      ...preferences.history,
    ];
    final Map<String, ReminderCandidate> candidateByKey =
        <String, ReminderCandidate>{
          for (final ReminderCandidate candidate in candidateList)
            candidate.key: candidate,
        };
    final List<PlannedReminder> desired = ReminderPlanner.plan(
      candidates: candidateList,
      enabledCategories: preferences.enabledCategories,
      daysBefore: preferences.daysBefore,
      hour: preferences.hour,
      minute: preferences.minute,
      now: DateTime.now(),
      alreadyScheduledKeys: history
          .where((Map<String, Object?> item) => item['state'] == 'scheduled')
          .where((Map<String, Object?> item) {
            final DateTime? at = DateTime.tryParse(
              item['scheduled_at'] as String? ?? '',
            );
            return at != null &&
                at.isBefore(DateTime.now()) &&
                candidateByKey[item['key']]?.isOverdue == true;
          })
          .map((Map<String, Object?> item) => item['key'])
          .whereType<String>()
          .toSet(),
    );
    final Map<String, PlannedReminder> desiredByKey = <String, PlannedReminder>{
      for (final PlannedReminder reminder in desired) reminder.key: reminder,
    };
    final Set<String> activeKeys = <String>{};
    for (final PendingNotificationRequest request in pending) {
      final String? key = request.payload;
      final PlannedReminder? target = key == null ? null : desiredByKey[key];
      final Map<String, Object?>? recorded = key == null
          ? null
          : history.lastWhereOrNull(
              (Map<String, Object?> item) =>
                  item['key'] == key && item['state'] != 'cancelled',
            );
      final DateTime? recordedAt = DateTime.tryParse(
        recorded?['scheduled_at'] as String? ?? '',
      );
      final bool timeZoneChanged =
          recorded?['time_zone_id'] is String &&
          recorded!['time_zone_id'] != _deviceTimeZoneId;
      final bool outdatedMetadata =
          recorded == null || recorded['state'] != 'scheduled';
      final bool timeChanged =
          target != null &&
          recordedAt != null &&
          !recordedAt.toLocal().isAtSameMomentAs(target.at.toLocal());
      if (target == null ||
          outdatedMetadata ||
          timeChanged ||
          timeZoneChanged ||
          device.permission != NotificationPermissionState.granted) {
        await _plugin.cancel(id: request.id);
        if (key != null && recorded != null) {
          final int index = history.lastIndexWhere(
            (Map<String, Object?> item) => identical(item, recorded),
          );
          if (index >= 0) {
            history[index] = <String, Object?>{
              ...recorded,
              'state': 'cancelled',
            };
          }
        }
      } else if (key != null) {
        if (!activeKeys.add(key)) {
          await _plugin.cancel(id: request.id);
        }
      }
    }
    if (device.permission != NotificationPermissionState.granted) {
      await _saveHistory(preferences, history);
      throw StateError('Notification permission is disabled on this device.');
    }
    final List<PlannedReminder> planned = desired
        .where((PlannedReminder reminder) => !activeKeys.contains(reminder.key))
        .toList(growable: false);
    if (planned.isNotEmpty &&
        Platform.isAndroid &&
        !device.exactAlarmsAllowed) {
      await _saveHistory(preferences, history);
      throw StateError(
        'Allow Alarms and reminders in device settings to schedule exact-time reminders.',
      );
    }
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
    try {
      for (final PlannedReminder reminder in planned) {
        final ReminderCandidate candidate = candidateByKey[reminder.key]!;
        final tz.TZDateTime scheduled = tz.TZDateTime.from(
          reminder.at,
          tz.local,
        );
        await _plugin.zonedSchedule(
          id: reminder.id,
          title: candidate.title,
          body: candidate.body,
          scheduledDate: scheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: reminder.key,
        );
        history.add(<String, Object?>{
          'key': reminder.key,
          'title': candidate.title,
          'body': candidate.body,
          'category': candidate.category,
          'scheduled_at': reminder.at.toIso8601String(),
          'time_zone_id': _deviceTimeZoneId,
          'read': false,
          'state': 'scheduled',
        });
      }
    } catch (_) {
      await _saveHistory(preferences, history);
      rethrow;
    }
    await _saveHistory(preferences, history);
    return planned.length;
  }

  Future<void> _saveHistory(
    ReminderPreferences preferences,
    List<Map<String, Object?>> history,
  ) => savePreferences(
    ReminderPreferences(
      enabledCategories: preferences.enabledCategories,
      daysBefore: preferences.daysBefore,
      hour: preferences.hour,
      minute: preferences.minute,
      calendarReminderAt: preferences.calendarReminderAt,
      history: history,
    ),
  );

  Future<void> cancelCategory(String category) async {
    await initialize();
    final ReminderPreferences preferences = await loadPreferences();
    final List<Map<String, Object?>> history = <Map<String, Object?>>[
      ...preferences.history,
    ];
    final Map<String, Map<String, Object?>> latestByKey =
        <String, Map<String, Object?>>{
          for (final Map<String, Object?> item in history)
            if (item['key'] is String && item['category'] == category)
              item['key']! as String: item,
        };
    final List<PendingNotificationRequest> pending = await _plugin
        .pendingNotificationRequests();
    for (final PendingNotificationRequest request in pending) {
      final String? key = request.payload;
      if (key == null || !latestByKey.containsKey(key)) continue;
      await _plugin.cancel(id: request.id);
      final Map<String, Object?> record = latestByKey[key]!;
      final int index = history.lastIndexWhere(
        (Map<String, Object?> item) => identical(item, record),
      );
      if (index >= 0) {
        history[index] = <String, Object?>{...record, 'state': 'disabled'};
      }
    }
    await savePreferences(
      ReminderPreferences(
        enabledCategories: preferences.enabledCategories,
        daysBefore: preferences.daysBefore,
        hour: preferences.hour,
        minute: preferences.minute,
        calendarReminderAt: preferences.calendarReminderAt,
        history: history,
      ),
    );
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
        calendarReminderAt: current.calendarReminderAt,
        history: history,
      ),
    );
  }

  Future<File> _preferencesFile() async {
    final Directory directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return File('${directory.path}/reminder_preferences.json');
  }

  Future<void> _refreshDeviceTimezone() async {
    if (Platform.isAndroid) {
      final Map<Object?, Object?>? state = await _platform
          .invokeMapMethod<Object?, Object?>('deviceState');
      final String? zoneId = state?['timeZoneId'] as String?;
      if (zoneId != null) {
        _deviceTimeZoneId = zoneId;
        try {
          tz.setLocalLocation(tz.getLocation(zoneId));
          return;
        } on tz.LocationNotFoundException {
          // Fall back to the current fixed offset if the OS zone is not in tzdata.
        }
      }
    }
    final DateTime localNow = DateTime.now();
    _deviceTimeZoneId = localNow.timeZoneName;
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

extension _ReminderHistoryLookup on List<Map<String, Object?>> {
  Map<String, Object?>? lastWhereOrNull(
    bool Function(Map<String, Object?> item) test,
  ) {
    for (final Map<String, Object?> item in reversed) {
      if (test(item)) return item;
    }
    return null;
  }
}
