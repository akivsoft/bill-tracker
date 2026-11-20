import 'package:bill_tracker/app/theme/app_spacing.dart';
import 'package:bill_tracker/core/utils/app_date_picker.dart';
import 'package:bill_tracker/features/notifications/data/local_notification_service.dart';
import 'package:bill_tracker/features/notifications/data/reminder_schedule_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with WidgetsBindingObserver {
  final LocalNotificationService _service = LocalNotificationService.instance;
  ReminderPreferences _preferences = const ReminderPreferences();
  NotificationDeviceState? _deviceState;
  Set<String> _pendingKeys = <String>{};
  bool _loading = true;
  bool _permissionBusy = false;
  bool _scheduleBusy = false;
  String? _message;

  static const Map<String, String> _categories = <String, String>{
    'bills': 'Bills and recurring payments',
    'loans': 'Loan installments',
    'credit_cards': 'Credit card due dates',
    'paydays': 'Expected payday',
    'savings': 'Savings targets',
    'calendar': 'Calendar reminder',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Widget _permissionCard() {
    final NotificationDeviceState? device = _deviceState;
    final NotificationPermissionState permission =
        device?.permission ?? NotificationPermissionState.denied;
    final bool granted = permission == NotificationPermissionState.granted;
    final bool permanent =
        permission == NotificationPermissionState.permanentlyDenied;
    final String status = switch (permission) {
      NotificationPermissionState.granted =>
        'Notifications are allowed on this device.',
      NotificationPermissionState.permanentlyDenied =>
        'Notification permission is blocked. Enable it in device settings.',
      NotificationPermissionState.unsupported =>
        'Notifications are not supported on this device.',
      NotificationPermissionState.denied =>
        'Device permission is off. Enable notifications to receive reminders.',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Device notification access',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xSmall),
            Text(status),
            if (granted && device?.exactAlarmsAllowed == false) ...<Widget>[
              const SizedBox(height: AppSpacing.xSmall),
              const Text(
                'Exact-time delivery also needs Alarms and reminders access on this Android device.',
              ),
            ],
            const SizedBox(height: AppSpacing.small),
            if (!granted &&
                permission != NotificationPermissionState.unsupported)
              FilledButton.icon(
                onPressed: _permissionBusy ? null : _enableNotifications,
                icon: const Icon(Icons.notifications_active_outlined),
                label: Text(
                  permanent
                      ? 'Open notification settings'
                      : 'Enable notifications',
                ),
              )
            else if (granted && device?.exactAlarmsAllowed == false)
              OutlinedButton.icon(
                onPressed: _permissionBusy
                    ? null
                    : () => _ensureNotificationAccess(requireExactAlarms: true),
                icon: const Icon(Icons.alarm),
                label: const Text('Allow exact-time reminders'),
              ),
          ],
        ),
      ),
    );
  }

  Future<bool> _ensureNotificationAccess({
    bool requireExactAlarms = false,
  }) async {
    NotificationDeviceState state = await _service.deviceState();
    if (!mounted) return false;
    if (state.permission == NotificationPermissionState.unsupported) {
      if (mounted) {
        setState(
          () => _message = 'Notifications are not supported on this device.',
        );
      }
      return false;
    }
    if (state.permission == NotificationPermissionState.permanentlyDenied) {
      final bool? openSettings = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Enable notifications in settings'),
          content: const Text(
            'Notification permission was previously denied. Open this app’s notification settings and allow notifications, then return here.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
      if (openSettings == true) {
        await _service.openNotificationSettings();
        if (mounted) await _refreshDeviceState();
      }
      return false;
    }
    if (state.permission != NotificationPermissionState.granted) {
      final bool? continueRequest = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Allow bill and loan reminders?'),
          content: const Text(
            'MyFinance can send local reminders for bills, loan installments, expected income, and the calendar reminder you choose. Reminders do not record payments or change balances.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (continueRequest != true || !mounted) return false;
      final bool granted = await _service.requestPermission();
      if (!mounted) return false;
      state = await _service.deviceState();
      if (mounted) setState(() => _deviceState = state);
      if (!granted) {
        if (mounted) {
          setState(
            () => _message =
                state.permission ==
                    NotificationPermissionState.permanentlyDenied
                ? 'Permission is blocked. Use Open notification settings to enable it.'
                : 'Notification permission was denied. You can enable it later in device settings.',
          );
        }
        return false;
      }
    }
    if (requireExactAlarms && !state.exactAlarmsAllowed) {
      if (!mounted) return false;
      final bool? continueRequest = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Allow exact reminder times?'),
          content: const Text(
            'Android requires Alarms and reminders access to deliver notifications at the selected time, including while the device is idle.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (continueRequest != true || !mounted) return false;
      final bool allowed = await _service.requestExactAlarmAccess();
      if (!mounted) return false;
      state = await _service.deviceState();
      if (mounted) setState(() => _deviceState = state);
      if (!allowed) {
        if (mounted) {
          setState(
            () => _message =
                'Exact alarms are not enabled. Allow Alarms and reminders in device settings, then try again.',
          );
        }
        return false;
      }
    }
    return true;
  }

  Future<void> _enableNotifications() async {
    setState(() => _permissionBusy = true);
    try {
      final bool allowed = await _ensureNotificationAccess();
      if (allowed && mounted) {
        await ReminderScheduleCoordinator.synchronize(ref);
        final Set<String> pending = await _service.pendingKeys();
        if (mounted) {
          setState(() {
            _pendingKeys = pending;
            _message =
                'Notification permission is enabled. ${pending.length} reminder${pending.length == 1 ? '' : 's'} currently scheduled.';
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = 'Could not request notification permission: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _permissionBusy = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshDeviceState();
  }

  Future<void> _load() async {
    try {
      final ReminderPreferences preferences = await _service.loadPreferences();
      final NotificationDeviceState deviceState = await _service.deviceState();
      final Set<String> pendingKeys = await _service.pendingKeys();
      if (mounted) {
        setState(() {
          _preferences = preferences;
          _deviceState = deviceState;
          _pendingKeys = pendingKeys;
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

  Future<void> _refreshDeviceState() async {
    try {
      final NotificationDeviceState state = await _service.deviceState();
      final Set<String> pending = await _service.pendingKeys();
      if (mounted) {
        setState(() {
          _deviceState = state;
          _pendingKeys = pending;
        });
        await ReminderScheduleCoordinator.synchronize(ref);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = 'Could not check notification access: $error',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                _permissionCard(),
                const SizedBox(height: AppSpacing.small),
                Card(
                  child: Column(
                    children: <Widget>[
                      for (final MapEntry<String, String> entry
                          in _categories.entries)
                        SwitchListTile(
                          secondary: Icon(
                            entry.key == 'calendar'
                                ? Icons.calendar_month_outlined
                                : Icons.notifications_outlined,
                          ),
                          title: Text(entry.value),
                          value: _preferences.enabledCategories.contains(
                            entry.key,
                          ),
                          onChanged: _permissionBusy
                              ? null
                              : (enabled) => _toggle(entry.key, enabled),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.small),
                OutlinedButton.icon(
                  onPressed: _chooseCalendarReminder,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    _preferences.calendarReminderAt == null
                        ? 'Choose calendar reminder date and time'
                        : 'Calendar reminder · ${DateFormat.yMMMd().add_jm().format(_preferences.calendarReminderAt!.toLocal())}',
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
                  onPressed: _scheduleBusy || _permissionBusy
                      ? null
                      : _schedule,
                  icon: _scheduleBusy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.notifications_active_outlined),
                  label: const Text('Schedule or update reminders'),
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
                            trailing: _pendingKeys.contains(item['key'])
                                ? const Text('Scheduled')
                                : item['state'] == 'disabled' ||
                                      item['state'] == 'cancelled'
                                ? const Text('Disabled')
                                : item['read'] == true
                                ? const Text('Read')
                                : const Text('Sent or no longer scheduled'),
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
    DateTime? calendarReminderAt,
  }) => ReminderPreferences(
    enabledCategories: categories ?? _preferences.enabledCategories,
    daysBefore: daysBefore ?? _preferences.daysBefore,
    hour: hour ?? _preferences.hour,
    minute: minute ?? _preferences.minute,
    calendarReminderAt: calendarReminderAt ?? _preferences.calendarReminderAt,
    history: _preferences.history,
  );

  Future<void> _save(ReminderPreferences value) async {
    try {
      await _service.savePreferences(value);
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = 'Could not save reminder preferences: $error',
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _preferences = value;
      _message = 'Reminder preferences saved on this device.';
    });
    try {
      await ReminderScheduleCoordinator.synchronize(ref);
      final Set<String> pending = await _service.pendingKeys();
      if (mounted) setState(() => _pendingKeys = pending);
    } catch (error) {
      if (mounted) {
        setState(
          () => _message =
              'Preferences were saved, but reminder schedules could not be updated: $error',
        );
      }
    }
  }

  Future<void> _toggle(String category, bool enabled) async {
    final NotificationDeviceState current = await _service.deviceState();
    if (!mounted) return;
    if (enabled && current.permission != NotificationPermissionState.granted) {
      setState(() => _permissionBusy = true);
      final bool access;
      try {
        access = await _ensureNotificationAccess();
      } catch (error) {
        if (mounted) {
          setState(
            () =>
                _message = 'Could not request notification permission: $error',
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _permissionBusy = false);
      }
      if (!access) return;
    }
    final Set<String> categories = <String>{..._preferences.enabledCategories};
    if (enabled) {
      categories.add(category);
    } else {
      categories.remove(category);
    }
    await _save(_copy(categories: categories));
    if (!enabled) {
      if (mounted) {
        setState(
          () => _message =
              '${_categories[category]} reminders disabled and pending schedules updated.',
        );
      }
    }
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

  Future<void> _chooseCalendarReminder() async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime saved =
        _preferences.calendarReminderAt ?? now.add(const Duration(days: 1));
    final DateTime initial = saved.isBefore(today) ? today : saved;
    final DateTime? date = await showAppDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final DateTime scheduled = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    await _save(_copy(calendarReminderAt: scheduled));
  }

  Future<void> _schedule() async {
    if (_scheduleBusy) return;
    setState(() => _scheduleBusy = true);
    try {
      final bool allowed = await _ensureNotificationAccess();
      if (!allowed || !mounted) return;
      final bool hasReminders =
          await ReminderScheduleCoordinator.hasSchedulableReminders(ref);
      if (!mounted) return;
      if (hasReminders) {
        final bool exactAlarmsAllowed = await _ensureNotificationAccess(
          requireExactAlarms: true,
        );
        if (!exactAlarmsAllowed || !mounted) return;
      }
      await ReminderScheduleCoordinator.synchronize(ref);
      final Set<String> pending = await _service.pendingKeys();
      await _load();
      if (mounted) {
        setState(() {
          _pendingKeys = pending;
          _message =
              'Reminder schedules updated. ${pending.length} reminder${pending.length == 1 ? '' : 's'} currently scheduled.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Could not schedule reminders: $error');
      }
    } finally {
      if (mounted) setState(() => _scheduleBusy = false);
    }
  }
}
