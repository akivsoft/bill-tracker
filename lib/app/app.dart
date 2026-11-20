import 'dart:async';

import 'package:bill_tracker/app/router/app_router.dart';
import 'package:bill_tracker/app/router/route_names.dart';
import 'package:bill_tracker/app/theme/app_theme.dart';
import 'package:bill_tracker/features/notifications/data/local_notification_service.dart';
import 'package:bill_tracker/features/notifications/data/reminder_schedule_coordinator.dart';
import 'package:bill_tracker/features/dashboard/presentation/providers/financial_overview_providers.dart';
import 'package:bill_tracker/features/settings/presentation/providers/user_preferences_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MyFinanceApp extends ConsumerStatefulWidget {
  const MyFinanceApp({super.key});

  @override
  ConsumerState<MyFinanceApp> createState() => _MyFinanceAppState();
}

class _MyFinanceAppState extends ConsumerState<MyFinanceApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        ReminderScheduleCoordinator.synchronize(ref).catchError((Object error) {
          debugPrint('Could not refresh reminder schedules: $error');
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final WidgetRef ref = this.ref;
    final GoRouter router = ref.watch(appRouterProvider);
    void synchronizeSchedules() {
      unawaited(
        ReminderScheduleCoordinator.synchronize(ref).catchError((Object error) {
          debugPrint('Could not update reminder schedules: $error');
        }),
      );
    }

    ref.listen(billsOverviewProvider, (_, _) => synchronizeSchedules());
    ref.listen(billPaymentsOverviewProvider, (_, _) => synchronizeSchedules());
    ref.listen(loansOverviewProvider, (_, _) => synchronizeSchedules());
    ref.listen(installmentsOverviewProvider, (_, _) => synchronizeSchedules());
    ref.listen(
      walletManagementAccountsProvider,
      (_, _) => synchronizeSchedules(),
    );
    ref.listen(paydaySchedulesProvider, (_, _) => synchronizeSchedules());
    ref.listen(savingsGoalsOverviewProvider, (_, _) => synchronizeSchedules());
    unawaited(
      LocalNotificationService.instance
          .initialize(
            onNotificationTap: (String? payload) {
              if (payload != null) {
                unawaited(
                  LocalNotificationService.instance
                      .markRead(payload)
                      .catchError(
                        (Object error) => debugPrint(
                          'Could not update reminder history: $error',
                        ),
                      ),
                );
              }
              final String kind = payload?.split(':').first ?? '';
              final String path = switch (kind) {
                'bill' => RouteNames.billsPath,
                'loan' => RouteNames.loansPath,
                'card' => RouteNames.walletsPath,
                'payday' => RouteNames.moreModule('planner'),
                'savings' => RouteNames.moreModule('savings'),
                'calendar' => RouteNames.moreModule('calendar'),
                _ => RouteNames.moreModule('notifications'),
              };
              router.go(path);
            },
          )
          .catchError((Object error) {
            debugPrint('Notification initialization failed: $error');
          }),
    );
    final ThemeMode themeMode = ref
        .watch(userPreferencesProvider)
        .when(
          data: (preferences) => switch (preferences.themeMode) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          },
          loading: () => ThemeMode.system,
          error: (_, _) => ThemeMode.system,
        );

    return MaterialApp.router(
      title: 'MyFinance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      supportedLocales: const <Locale>[Locale('en', 'PH')],
      locale: const Locale('en', 'PH'),
    );
  }
}
