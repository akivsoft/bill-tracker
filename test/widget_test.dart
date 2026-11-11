import 'dart:async';

import 'package:bill_tracker/app/app.dart';
import 'package:bill_tracker/data/local/database/app_database.dart';
import 'package:bill_tracker/data/local/datasources/local_financial_data_source.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_commands.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:bill_tracker/features/transactions/domain/repositories/financial_repository.dart';
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

    final Finder loanProgressCard = find
        .ancestor(
          of: find.text('Loan repayment progress'),
          matching: find.byType(Card),
        )
        .first;
    final Finder savingsProgressCard = find
        .ancestor(
          of: find.text('Savings progress'),
          matching: find.byType(Card),
        )
        .first;
    expect(
      tester.getTopLeft(savingsProgressCard).dy -
          tester.getBottomLeft(loanProgressCard).dy,
      greaterThanOrEqualTo(8),
    );

    for (final Size size in <Size>[
      const Size(320, 640),
      const Size(390, 844),
      const Size(600, 960),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text('Your money, bills, and commitments in one place.'),
        findsOneWidget,
      );
    }
    await _disposeApp(tester, database);
  });

  testWidgets(
    'bill category picker scrolls through 20 custom and all built-in categories',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final AppDatabase database = AppDatabase(NativeDatabase.memory());
      final LocalUserPreferencesRepository preferences =
          LocalUserPreferencesRepository(database);
      await preferences.load();
      await preferences.setOnboardingComplete(true);
      await preferences.setSetupComplete(true);
      final LocalFinancialDataSource dataSource = LocalFinancialDataSource(
        database,
      );
      for (int index = 1; index <= 20; index++) {
        await dataSource.createCategory(
          CreateCategoryInput(
            name: 'Stress Category $index',
            categoryType: 'bill',
          ),
        );
      }
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const MyFinanceApp(),
        ),
      );
      await tester.pumpAndSettle();

      NavigationBar navigationBar = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      navigationBar.onDestinationSelected!(1);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final Size size in <Size>[
        const Size(320, 640),
        const Size(390, 844),
        const Size(600, 960),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextFormField).first);
      await tester.pump();
      await tester.tap(find.byType(TextFormField).at(1));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Create bill category'));
      await tester.tap(find.text('Create bill category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(find.text('Please enter a category name.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Create bill category'));
      await tester.tap(find.text('Create bill category'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).last,
        'My Custom Category',
      );
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(find.text('My Custom Category'), findsOneWidget);
      await tester.tap(find.text('My Custom Category'));
      await tester.pumpAndSettle();
      expect(find.text('Choose bill category'), findsOneWidget);
      expect(find.text('My Custom Category'), findsNWidgets(2));
      expect(find.text('Remove'), findsWidgets);
      final Finder removeCategoryButton = find.byTooltip(
        'Remove My Custom Category',
      );
      expect(removeCategoryButton, findsOneWidget);
      await tester.tap(removeCategoryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();
      expect(find.text('My Custom Category'), findsNothing);
      final archivedCategory = await (database.select(
        database.categories,
      )..where((row) => row.name.equals('My Custom Category'))).getSingle();
      expect(archivedCategory.archivedAt, isNotNull);

      await tester.scrollUntilVisible(
        find.text('Stress Category 20'),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Stress Category 20'), findsOneWidget);
      for (final String builtIn in <String>[
        'Electricity',
        'Family allowance',
        'Groceries',
        'Insurance',
        'Internet',
        'Other',
        'Phone',
        'Rent',
        'School fees',
        'Subscriptions',
        'Transportation',
        'Water',
      ]) {
        await tester.scrollUntilVisible(
          find.text(builtIn),
          120,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text(builtIn), findsOneWidget);
      }
      expect(find.text('Remove'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(find.text('Other / none'), findsOneWidget);
      expect(
        find.text('That category was removed. Choose another category.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _disposeApp(tester, database);
    },
  );

  testWidgets('category picker refreshes after the bill form opens', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
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

    NavigationBar navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    navigationBar.onDestinationSelected!(1);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await LocalFinancialDataSource(database).createCategory(
      CreateCategoryInput(
        name: 'Created after form opened',
        categoryType: 'bill',
      ),
    );
    await tester.tapAt(tester.getCenter(find.text('Category').last));
    await tester.pumpAndSettle();
    expect(find.text('Choose bill category'), findsOneWidget);
    expect(find.text('Created after form opened'), findsOneWidget);
    await tester.tap(find.text('Created after form opened'));
    await tester.pumpAndSettle();
    expect(find.text('Created after form opened'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Created after form opened'));
    await tester.pumpAndSettle();
    expect(find.text('Choose bill category'), findsOneWidget);
    final Finder selectedCategoryTile = find.ancestor(
      of: find.text('Created after form opened').last,
      matching: find.byType(ListTile),
    ).first;
    expect(
      find.descendant(
        of: selectedCategoryTile,
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    await _disposeApp(tester, database);
  });

  testWidgets(
    'category picker shows loading, error, and empty recovery states',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final AppDatabase database = AppDatabase(NativeDatabase.memory());
      final StreamController<List<CategoryEntry>> categoryEvents =
          StreamController<List<CategoryEntry>>.broadcast();
      final LocalUserPreferencesRepository preferences =
          LocalUserPreferencesRepository(database);
      await preferences.load();
      await preferences.setOnboardingComplete(true);
      await preferences.setSetupComplete(true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            financialRepositoryProvider.overrideWithValue(
              _CategoryStreamRepository(categoryEvents.stream),
            ),
          ],
          child: const MyFinanceApp(),
        ),
      );
      await tester.pumpAndSettle();

      NavigationBar navigationBar = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      navigationBar.onDestinationSelected!(1);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .ancestor(
              of: find.text('Category').last,
              matching: find.byType(InkWell),
            )
            .first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Loading categories…'), findsOneWidget);
      expect(find.text('Create bill category'), findsNWidgets(2));

      categoryEvents.addError(StateError('Category storage unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('Categories could not be loaded.'), findsOneWidget);
      expect(find.text('Retry'), findsWidgets);

      await tester.tap(find.text('Retry').last);
      await tester.pump();
      categoryEvents.add(const <CategoryEntry>[]);
      await tester.pumpAndSettle();
      expect(find.text('No bill categories available.'), findsOneWidget);
      expect(find.text('Create bill category'), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      await categoryEvents.close();
      await _disposeApp(tester, database);
    },
  );

  testWidgets('loan overview and More expenses fit a compact viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final AppDatabase database = AppDatabase(NativeDatabase.memory());
    final LocalUserPreferencesRepository preferences =
        LocalUserPreferencesRepository(database);
    await preferences.load();
    await preferences.setOnboardingComplete(true);
    await preferences.setSetupComplete(true);
    final LocalFinancialDataSource dataSource = LocalFinancialDataSource(
      database,
    );
    await dataSource.createLoan(
      CreateLoanInput(
        name: 'Long term loan with a deliberately long name for narrow screens',
        providerName: 'A lender with a very long provider name',
        principalMinorUnits: 9876543210000,
        openedAt: DateTime.now(),
      ),
    );
    await dataSource.createExpense(
      CreateExpenseInput(
        title:
            'A very long expense title that should wrap instead of overflowing',
        amountMinorUnits: 9876543210000,
        occurredAt: DateTime.now(),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MyFinanceApp(),
      ),
    );
    await tester.pumpAndSettle();

    NavigationBar navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    navigationBar.onDestinationSelected!(3);
    await tester.pumpAndSettle();
    expect(find.text('Loan overview'), findsOneWidget);
    expect(find.text('Active loans'), findsWidgets);
    expect(find.text('Overdue installments'), findsOneWidget);
    expect(find.text('Upcoming installments'), findsOneWidget);
    expect(find.text('Fully paid'), findsOneWidget);
    expect(find.text('Amount repaid'), findsNothing);
    for (final Size size in <Size>[
      const Size(320, 640),
      const Size(390, 844),
      const Size(600, 960),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final Offset active = tester.getTopLeft(find.text('Active loans').last);
      final Offset overdue = tester.getTopLeft(
        find.text('Overdue installments'),
      );
      final Offset upcoming = tester.getTopLeft(
        find.text('Upcoming installments'),
      );
      final Offset paid = tester.getTopLeft(find.text('Fully paid'));
      expect((active.dy - overdue.dy).abs(), lessThan(1));
      expect((upcoming.dy - paid.dy).abs(), lessThan(1));
      expect(upcoming.dy, greaterThan(active.dy));
    }

    navigationBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    navigationBar.onDestinationSelected!(4);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Expenses').first);
    await tester.tap(find.text('Expenses').first);
    await tester.pumpAndSettle();
    expect(find.text('Recorded spending this month'), findsOneWidget);
    for (final Size size in <Size>[
      const Size(320, 640),
      const Size(390, 844),
      const Size(600, 960),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Recorded spending this month'), findsOneWidget);
    }
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _disposeApp(tester, database);
  });

  testWidgets('Home disclosure sections stay independent across navigation', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
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

    await tester.tap(find.byTooltip('Collapse Savings progress'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Expand Savings progress'), findsOneWidget);
    expect(find.byTooltip('Collapse Loan repayment progress'), findsOneWidget);

    NavigationBar navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    navigationBar.onDestinationSelected!(4);
    await tester.pumpAndSettle();
    navigationBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    navigationBar.onDestinationSelected!(0);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Expand Savings progress'), findsOneWidget);
    expect(find.byTooltip('Collapse Loan repayment progress'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _disposeApp(tester, database);
  });
}

Future<void> _disposeApp(WidgetTester tester, AppDatabase database) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
  await database.close();
}

class _CategoryStreamRepository implements FinancialRepository {
  const _CategoryStreamRepository(this.categoryStream);

  final Stream<List<CategoryEntry>> categoryStream;

  @override
  Stream<List<CategoryEntry>> watchCategories({
    String? categoryType,
    bool includeArchived = false,
  }) => categoryStream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
