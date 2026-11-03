import 'dart:async';

import 'package:bill_tracker/app/config/supabase_bootstrap.dart';
import 'package:bill_tracker/features/authentication/data/supabase_authentication_gateway.dart';
import 'package:bill_tracker/features/authentication/domain/entities/auth_session.dart';
import 'package:bill_tracker/features/authentication/domain/repositories/authentication_gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

final Provider<AuthenticationGateway> authenticationGatewayProvider =
    Provider<AuthenticationGateway>((Ref ref) {
      if (!SupabaseBootstrap.isInitialized) {
        return const LocalAuthenticationGateway();
      }
      return SupabaseAuthenticationGateway(supabase.Supabase.instance.client);
    });

final NotifierProvider<AuthenticationController, AuthenticationState>
authenticationProvider =
    NotifierProvider<AuthenticationController, AuthenticationState>(
      AuthenticationController.new,
    );

class AuthenticationController extends Notifier<AuthenticationState> {
  late AuthenticationGateway _gateway;
  StreamSubscription<AuthSession>? _sessionSubscription;

  @override
  AuthenticationState build() {
    _gateway = ref.watch(authenticationGatewayProvider);
    _sessionSubscription?.cancel();
    _sessionSubscription = _gateway.sessionChanges.listen(_setSession);
    ref.onDispose(() => _sessionSubscription?.cancel());
    return _stateFor(_gateway.currentSession);
  }

  Future<void> signIn({required String email, required String password}) =>
      _perform(() => _gateway.signIn(email: email, password: password));

  Future<void> signUp({
    required String email,
    required String password,
  }) => _perform(
    () => _gateway.signUp(email: email, password: password),
    successNotice:
        'Your account is ready. Check your email if confirmation is required.',
  );

  Future<void> sendPasswordReset(String email) => _perform(
    () => _gateway.sendPasswordReset(email),
    successNotice: 'If an account uses that email, a reset link is on its way.',
  );

  Future<void> updatePassword(String password) => _perform(
    () => _gateway.updatePassword(password),
    successNotice: 'Your password has been updated.',
  );

  Future<void> signOut() => _perform(
    _gateway.signOut,
    successNotice: 'You are now using MyFinance in local-only mode.',
  );

  Future<void> useLocalOnly() async {
    if (state.isAuthenticated) {
      await signOut();
      return;
    }
    state = _stateFor(const AuthSession(isAuthenticated: false));
  }

  void clearMessages() =>
      state = state.copyWith(clearError: true, clearNotice: true);

  Future<void> _perform(
    Future<void> Function() action, {
    String? successNotice,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearNotice: true,
    );
    try {
      await action();
      final AuthSession session = _gateway.currentSession;
      final String? notice = successNotice == null
          ? null
          : session.isAuthenticated
          ? successNotice
          : successNotice.replaceFirst(
              'Your account is ready.',
              'Check your inbox to finish creating your account.',
            );
      state = _stateFor(session).copyWith(notice: notice);
    } on AuthFailure catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.message,
        clearNotice: true,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Something went wrong. Please try again.',
        clearNotice: true,
      );
    }
  }

  void _setSession(AuthSession session) {
    state = _stateFor(session);
  }

  AuthenticationState _stateFor(AuthSession session) => AuthenticationState(
    mode: session.isAuthenticated
        ? AuthenticationMode.supabase
        : AuthenticationMode.localOnly,
    isSupabaseAvailable: _gateway.isAvailable,
    isAuthenticated: session.isAuthenticated,
    email: session.email,
    isPasswordRecovery: session.isPasswordRecovery,
  );
}
