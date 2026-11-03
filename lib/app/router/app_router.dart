import 'package:bill_tracker/app/router/navigation_shell.dart';
import 'package:bill_tracker/app/router/route_names.dart';
import 'package:bill_tracker/features/authentication/domain/entities/auth_session.dart';
import 'package:bill_tracker/features/authentication/presentation/providers/authentication_provider.dart';
import 'package:bill_tracker/features/authentication/presentation/screens/authentication_screen.dart';
import 'package:bill_tracker/features/bills/presentation/screens/bills_screen.dart';
import 'package:bill_tracker/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:bill_tracker/features/dashboard/presentation/screens/home_screen.dart';
import 'package:bill_tracker/features/expenses/presentation/screens/expenses_screen.dart';
import 'package:bill_tracker/features/income/presentation/screens/income_screen.dart';
import 'package:bill_tracker/features/loans/presentation/screens/loans_screen.dart';
import 'package:bill_tracker/features/more/presentation/screens/more_screen.dart';
import 'package:bill_tracker/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:bill_tracker/features/onboarding/presentation/screens/financial_setup_screen.dart';
import 'package:bill_tracker/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:bill_tracker/features/onboarding/presentation/screens/splash_screen.dart';
import 'package:bill_tracker/features/planner/presentation/screens/planner_screen.dart';
import 'package:bill_tracker/features/reports/presentation/screens/reports_screen.dart';
import 'package:bill_tracker/features/savings/presentation/screens/savings_screen.dart';
import 'package:bill_tracker/features/settings/domain/entities/user_preferences.dart';
import 'package:bill_tracker/features/settings/presentation/providers/user_preferences_provider.dart';
import 'package:bill_tracker/features/settings/presentation/screens/settings_screen.dart';
import 'package:bill_tracker/features/shared/presentation/screens/module_placeholder_screen.dart';
import 'package:bill_tracker/features/transactions/presentation/screens/transactions_screen.dart';
import 'package:bill_tracker/features/wallets/presentation/screens/wallets_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final GoRouter router = createAppRouter(
    readPreferences: () => ref.read(userPreferencesProvider),
    readAuthentication: () => ref.read(authenticationProvider),
  );
  ref.listen(userPreferencesProvider, (_, _) => router.refresh());
  ref.listen(authenticationProvider, (_, _) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
});

GoRouter createAppRouter({
  required AsyncValue<UserPreferences> Function() readPreferences,
  required AuthenticationState Function() readAuthentication,
}) => GoRouter(
  initialLocation: RouteNames.splashPath,
  redirect: (BuildContext context, GoRouterState state) => resolveAppRedirect(
    location: state.matchedLocation,
    preferences: readPreferences(),
    authentication: readAuthentication(),
  ),
  routes: <RouteBase>[
    GoRoute(
      path: RouteNames.splashPath,
      name: RouteNames.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: RouteNames.onboardingPath,
      name: RouteNames.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: RouteNames.setupPath,
      name: RouteNames.setup,
      builder: (context, state) => const FinancialSetupScreen(),
    ),
    GoRoute(
      path: RouteNames.authenticationPath,
      name: RouteNames.authentication,
      builder: (context, state) =>
          const AuthenticationScreen(flow: AuthFlow.signIn),
    ),
    GoRoute(
      path: RouteNames.forgotPasswordPath,
      name: RouteNames.forgotPassword,
      builder: (context, state) =>
          const AuthenticationScreen(flow: AuthFlow.forgotPassword),
    ),
    GoRoute(
      path: RouteNames.resetPasswordPath,
      name: RouteNames.resetPassword,
      builder: (context, state) => const ResetPasswordScreen(),
    ),
    GoRoute(
      path: RouteNames.authCallbackPath,
      builder: (context, state) => const _AuthCallbackScreen(),
    ),
    GoRoute(
      path: RouteNames.startupErrorPath,
      name: RouteNames.startupError,
      builder: (context, state) => const _StartupErrorScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppNavigationShell(navigationShell: navigationShell),
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: RouteNames.homePath,
              name: RouteNames.home,
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: RouteNames.billsPath,
              name: RouteNames.bills,
              builder: (context, state) => const BillsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: RouteNames.walletsPath,
              name: RouteNames.wallets,
              builder: (context, state) => const WalletsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: RouteNames.loansPath,
              name: RouteNames.loans,
              builder: (context, state) => const LoansScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: RouteNames.morePath,
              name: RouteNames.more,
              builder: (context, state) => const MoreScreen(),
              routes: <RouteBase>[
                GoRoute(
                  path: 'income',
                  builder: (context, state) => const IncomeScreen(),
                ),
                GoRoute(
                  path: 'expenses',
                  builder: (context, state) => const ExpensesScreen(),
                ),
                GoRoute(
                  path: 'planner',
                  builder: (context, state) => const PlannerScreen(),
                ),
                GoRoute(
                  path: 'calendar',
                  builder: (context, state) => const CalendarScreen(),
                ),
                GoRoute(
                  path: 'savings',
                  builder: (context, state) => const SavingsScreen(),
                ),
                GoRoute(
                  path: 'reports',
                  builder: (context, state) => const ReportsScreen(),
                ),
                GoRoute(
                  path: 'transactions',
                  builder: (context, state) => const TransactionsScreen(),
                ),
                GoRoute(
                  path: 'notifications',
                  builder: (context, state) => const NotificationsScreen(),
                ),
                GoRoute(
                  path: 'settings',
                  builder: (context, state) => const SettingsScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => ModulePlaceholderScreen(
    title: 'Page not found',
    description: state.error?.toString() ?? 'This page is not available.',
    icon: Icons.search_off_rounded,
  ),
);

String? resolveAppRedirect({
  required String location,
  required AsyncValue<UserPreferences> preferences,
  required AuthenticationState authentication,
}) {
  if (preferences.isLoading) {
    return location == RouteNames.splashPath ? null : RouteNames.splashPath;
  }
  if (preferences.hasError) {
    return location == RouteNames.startupErrorPath
        ? null
        : RouteNames.startupErrorPath;
  }

  final UserPreferences value = preferences.requireValue;
  if (!value.onboardingComplete) {
    return location == RouteNames.onboardingPath
        ? null
        : RouteNames.onboardingPath;
  }
  if (!value.setupComplete) {
    return location == RouteNames.setupPath ? null : RouteNames.setupPath;
  }

  if (authentication.isPasswordRecovery &&
      location != RouteNames.resetPasswordPath) {
    return RouteNames.resetPasswordPath;
  }
  if (!authentication.isPasswordRecovery &&
      location == RouteNames.resetPasswordPath) {
    return RouteNames.authenticationPath;
  }
  if (authentication.isAuthenticated &&
      (location == RouteNames.authenticationPath ||
          location == RouteNames.forgotPasswordPath)) {
    return RouteNames.homePath;
  }
  if (location == RouteNames.splashPath ||
      location == RouteNames.onboardingPath ||
      location == RouteNames.setupPath ||
      location == RouteNames.authCallbackPath) {
    return RouteNames.homePath;
  }
  return null;
}

class _StartupErrorScreen extends ConsumerWidget {
  const _StartupErrorScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.storage_rounded, size: 48),
              const SizedBox(height: 16),
              Text(
                'Your local data could not be opened.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  ref.invalidate(userPreferencesProvider);
                  context.go(RouteNames.splashPath);
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AuthCallbackScreen extends StatelessWidget {
  const _AuthCallbackScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
