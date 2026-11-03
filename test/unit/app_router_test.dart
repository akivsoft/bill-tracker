import 'package:bill_tracker/app/router/app_router.dart';
import 'package:bill_tracker/app/router/route_names.dart';
import 'package:bill_tracker/features/authentication/domain/entities/auth_session.dart';
import 'package:bill_tracker/features/settings/domain/entities/user_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const AuthenticationState localAuth = AuthenticationState(
    mode: AuthenticationMode.localOnly,
    isSupabaseAvailable: false,
  );

  test('first launch is routed to onboarding', () {
    final String? redirect = resolveAppRedirect(
      location: RouteNames.splashPath,
      preferences: AsyncData<UserPreferences>(_preferences()),
      authentication: localAuth,
    );
    expect(redirect, RouteNames.onboardingPath);
  });

  test('loading local preferences keeps the splash visible', () {
    final String? redirect = resolveAppRedirect(
      location: RouteNames.homePath,
      preferences: const AsyncLoading<UserPreferences>(),
      authentication: localAuth,
    );
    expect(redirect, RouteNames.splashPath);
  });

  test('completed introduction with unfinished setup goes to setup', () {
    final String? redirect = resolveAppRedirect(
      location: RouteNames.homePath,
      preferences: AsyncData<UserPreferences>(
        _preferences(onboardingComplete: true),
      ),
      authentication: localAuth,
    );
    expect(redirect, RouteNames.setupPath);
  });

  test('local-only users reach home after setup without authentication', () {
    final String? redirect = resolveAppRedirect(
      location: RouteNames.setupPath,
      preferences: AsyncData<UserPreferences>(
        _preferences(onboardingComplete: true, setupComplete: true),
      ),
      authentication: localAuth,
    );
    expect(redirect, RouteNames.homePath);
  });

  test('password recovery opens the reset screen', () {
    final String? redirect = resolveAppRedirect(
      location: RouteNames.authenticationPath,
      preferences: AsyncData<UserPreferences>(
        _preferences(onboardingComplete: true, setupComplete: true),
      ),
      authentication: const AuthenticationState(
        mode: AuthenticationMode.supabase,
        isSupabaseAvailable: true,
        isAuthenticated: true,
        isPasswordRecovery: true,
      ),
    );
    expect(redirect, RouteNames.resetPasswordPath);
  });

  test('authenticated users leaving sign-in are returned home', () {
    final String? redirect = resolveAppRedirect(
      location: RouteNames.authenticationPath,
      preferences: AsyncData<UserPreferences>(
        _preferences(onboardingComplete: true, setupComplete: true),
      ),
      authentication: const AuthenticationState(
        mode: AuthenticationMode.supabase,
        isSupabaseAvailable: true,
        isAuthenticated: true,
      ),
    );
    expect(redirect, RouteNames.homePath);
  });

  test(
    'local users may open optional authentication without being forced there',
    () {
      final String? redirect = resolveAppRedirect(
        location: RouteNames.authenticationPath,
        preferences: AsyncData<UserPreferences>(
          _preferences(onboardingComplete: true, setupComplete: true),
        ),
        authentication: localAuth,
      );
      expect(redirect, isNull);
    },
  );
}

UserPreferences _preferences({
  bool onboardingComplete = false,
  bool setupComplete = false,
}) => UserPreferences(
  onboardingComplete: onboardingComplete,
  setupComplete: setupComplete,
  countryCode: 'PH',
  currencyCode: 'PHP',
  firstDayOfWeek: DateTime.monday,
  dateFormat: 'MM/dd/yyyy',
  themeMode: 'system',
  languageCode: 'en',
);
