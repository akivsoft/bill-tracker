import 'dart:async';

import 'package:bill_tracker/features/authentication/domain/entities/auth_session.dart';
import 'package:bill_tracker/features/authentication/domain/repositories/authentication_gateway.dart';
import 'package:bill_tracker/features/authentication/presentation/providers/authentication_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local-only access is available without Supabase', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        authenticationGatewayProvider.overrideWithValue(
          _FakeAuthenticationGateway(isAvailable: false),
        ),
      ],
    );
    addTearDown(container.dispose);

    final AuthenticationState state = container.read(authenticationProvider);
    expect(state.mode, AuthenticationMode.localOnly);
    expect(state.isAuthenticated, isFalse);
    expect(state.isSupabaseAvailable, isFalse);
  });

  test(
    'sign in updates authentication state and session survives controller recreation',
    () async {
      final _FakeAuthenticationGateway gateway = _FakeAuthenticationGateway();
      final ProviderContainer firstContainer = ProviderContainer(
        overrides: [authenticationGatewayProvider.overrideWithValue(gateway)],
      );

      await firstContainer
          .read(authenticationProvider.notifier)
          .signIn(email: 'person@example.com', password: 'validpass1');
      expect(
        firstContainer.read(authenticationProvider).mode,
        AuthenticationMode.supabase,
      );
      expect(
        firstContainer.read(authenticationProvider).email,
        'person@example.com',
      );
      firstContainer.dispose();

      final ProviderContainer restoredContainer = ProviderContainer(
        overrides: [authenticationGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(() {
        restoredContainer.dispose();
        gateway.close();
      });
      expect(
        restoredContainer.read(authenticationProvider).isAuthenticated,
        isTrue,
      );
    },
  );

  test(
    'logout returns to local-only mode and leaves the local app available',
    () async {
      final _FakeAuthenticationGateway gateway = _FakeAuthenticationGateway();
      final ProviderContainer container = ProviderContainer(
        overrides: [authenticationGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(() {
        container.dispose();
        gateway.close();
      });

      final AuthenticationController controller = container.read(
        authenticationProvider.notifier,
      );
      await controller.signIn(
        email: 'person@example.com',
        password: 'validpass1',
      );
      await controller.signOut();

      expect(
        container.read(authenticationProvider).mode,
        AuthenticationMode.localOnly,
      );
      expect(container.read(authenticationProvider).isAuthenticated, isFalse);
      expect(gateway.currentSession.isAuthenticated, isFalse);
    },
  );

  test(
    'authentication failures are exposed as a recoverable message',
    () async {
      final _FakeAuthenticationGateway gateway = _FakeAuthenticationGateway()
        ..failureMessage = 'That email and password do not match.';
      final ProviderContainer container = ProviderContainer(
        overrides: [authenticationGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(() {
        container.dispose();
        gateway.close();
      });

      await container
          .read(authenticationProvider.notifier)
          .signIn(email: 'person@example.com', password: 'wrongpass1');

      expect(container.read(authenticationProvider).isAuthenticated, isFalse);
      expect(
        container.read(authenticationProvider).errorMessage,
        'That email and password do not match.',
      );
    },
  );

  test('password reset reports a neutral success message', () async {
    final _FakeAuthenticationGateway gateway = _FakeAuthenticationGateway();
    final ProviderContainer container = ProviderContainer(
      overrides: [authenticationGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(() {
      container.dispose();
      gateway.close();
    });

    await container
        .read(authenticationProvider.notifier)
        .sendPasswordReset('person@example.com');

    expect(
      container.read(authenticationProvider).notice,
      'If an account uses that email, a reset link is on its way.',
    );
  });
}

class _FakeAuthenticationGateway implements AuthenticationGateway {
  _FakeAuthenticationGateway({
    this.isAvailable = true,
    AuthSession? initialSession,
  }) : _session = initialSession ?? const AuthSession(isAuthenticated: false);

  @override
  final bool isAvailable;
  final StreamController<AuthSession> _changes =
      StreamController<AuthSession>.broadcast();
  AuthSession _session;
  String? failureMessage;

  @override
  AuthSession get currentSession => _session;

  @override
  Stream<AuthSession> get sessionChanges => _changes.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    _checkFailure();
    _setSession(AuthSession(isAuthenticated: true, email: email));
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    _checkFailure();
    _setSession(AuthSession(isAuthenticated: true, email: email));
  }

  @override
  Future<void> sendPasswordReset(String email) async => _checkFailure();

  @override
  Future<void> updatePassword(String password) async => _checkFailure();

  @override
  Future<void> signOut() async =>
      _setSession(const AuthSession(isAuthenticated: false));

  void _setSession(AuthSession session) {
    _session = session;
    if (!_changes.isClosed) _changes.add(session);
  }

  void _checkFailure() {
    if (failureMessage != null) throw AuthFailure(failureMessage!);
  }

  Future<void> close() => _changes.close();
}
