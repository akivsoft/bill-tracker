import 'package:bill_tracker/app/app.dart';
import 'package:bill_tracker/data/local/database/app_database.dart';
import 'package:bill_tracker/features/settings/data/repositories/local_user_preferences_repository.dart';
import 'package:bill_tracker/shared/providers/app_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'first launch can complete onboarding and skip optional setup steps',
    (WidgetTester tester) async {
      final AppDatabase database = AppDatabase(NativeDatabase.memory());
      await LocalUserPreferencesRepository(database).load();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const MyFinanceApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Manage your money'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Stay on top of payments'), findsOneWidget);
      await tester.tap(find.text('Skip').first);
      await tester.pumpAndSettle();
      expect(find.text('Your preferences'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('How often are you paid?'), findsOneWidget);
      await tester.tap(find.text('Skip this step'));
      await tester.pumpAndSettle();
      expect(find.text('Add your first account'), findsOneWidget);
      await tester.tap(find.text('Skip account'));
      await tester.pumpAndSettle();
      expect(find.text('You’re all set'), findsOneWidget);

      await tester.tap(find.text('Go to dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to MyFinance'), findsOneWidget);
      expect(await database.select(database.financialAccounts).get(), isEmpty);
      final prefs = await LocalUserPreferencesRepository(database).load();
      expect(prefs.onboardingComplete, isTrue);
      expect(prefs.setupComplete, isTrue);
      await _disposeApp(tester, database);
    },
  );

  testWidgets('bottom tabs preserve the More branch while switching sections', (
    WidgetTester tester,
  ) async {
    final AppDatabase database = AppDatabase(NativeDatabase.memory());
    final LocalUserPreferencesRepository preferences =
        LocalUserPreferencesRepository(database);
    await preferences.load();
    await preferences.setOnboardingComplete(true);
    await preferences.setSetupComplete(true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MyFinanceApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome to MyFinance'), findsOneWidget);

    NavigationBar navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    navigationBar.onDestinationSelected!(4);
    await tester.pumpAndSettle();
    expect(find.text('Manage your money'), findsOneWidget);

    await tester.ensureVisible(find.text('Income').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Income').first);
    await tester.pumpAndSettle();
    expect(find.text('No income records match this view.'), findsOneWidget);

    navigationBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    navigationBar.onDestinationSelected!(2);
    await tester.pumpAndSettle();
    expect(find.text('Wallets'), findsWidgets);

    navigationBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    navigationBar.onDestinationSelected!(4);
    await tester.pumpAndSettle();
    expect(find.text('No income records match this view.'), findsOneWidget);
    await _disposeApp(tester, database);
  });

  testWidgets('financial setup can create the first local account', (
    WidgetTester tester,
  ) async {
    final AppDatabase database = AppDatabase(NativeDatabase.memory());
    await LocalUserPreferencesRepository(database).load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MyFinanceApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip this step'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add account'));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byType(TextFormField).first, 'Cash wallet');
    await tester.ensureVisible(find.text('Save account'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Save account'));
    await tester.pumpAndSettle();

    final accounts = await database.select(database.financialAccounts).get();
    expect(accounts, hasLength(1));
    expect(accounts.single.name, 'Cash wallet');
    expect(accounts.single.currentBalanceMinorUnits, 0);
    expect(find.text('You’re all set'), findsOneWidget);
    await _disposeApp(tester, database);
  });

  testWidgets('saved dark theme is applied to the app shell', (
    WidgetTester tester,
  ) async {
    final AppDatabase database = AppDatabase(NativeDatabase.memory());
    final LocalUserPreferencesRepository preferences =
        LocalUserPreferencesRepository(database);
    await preferences.load();
    await preferences.setOnboardingComplete(true);
    await preferences.setSetupComplete(true);
    await preferences.setThemeMode('dark');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MyFinanceApp(),
      ),
    );
    await tester.pumpAndSettle();

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.themeMode, ThemeMode.dark);
    await _disposeApp(tester, database);
  });

  testWidgets('home layout fits a compact mobile viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final AppDatabase database = AppDatabase(NativeDatabase.memory());
    final LocalUserPreferencesRepository preferences =
        LocalUserPreferencesRepository(database);
    await preferences.load();
    await preferences.setOnboardingComplete(true);
    await preferences.setSetupComplete(true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MyFinanceApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Actual available money'), findsOneWidget);
    await _disposeApp(tester, database);
  });
}

Future<void> _disposeApp(WidgetTester tester, AppDatabase database) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
  await database.close();
}
