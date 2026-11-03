import 'package:bill_tracker/app/config/environment.dart';
import 'package:bill_tracker/features/authentication/domain/entities/auth_session.dart';
import 'package:bill_tracker/features/authentication/domain/repositories/authentication_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class SupabaseAuthenticationGateway implements AuthenticationGateway {
  SupabaseAuthenticationGateway(this._client);

  final supabase.SupabaseClient _client;

  @override
  bool get isAvailable => true;

  @override
  AuthSession get currentSession => _session(_client.auth.currentSession);

  @override
  Stream<AuthSession> get sessionChanges => _client.auth.onAuthStateChange.map(
    (supabase.AuthState change) => AuthSession(
      isAuthenticated: change.session != null,
      email: change.session?.user.email,
      isPasswordRecovery:
          change.event == supabase.AuthChangeEvent.passwordRecovery,
    ),
  );

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(
        () => _client.auth.signInWithPassword(email: email, password: password),
      );

  @override
  Future<void> signUp({required String email, required String password}) =>
      _guard(
        () => _client.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: AppEnvironment.authRedirectUrl,
        ),
      );

  @override
  Future<void> sendPasswordReset(String email) => _guard(
    () => _client.auth.resetPasswordForEmail(
      email,
      redirectTo: AppEnvironment.authRedirectUrl,
    ),
  );

  @override
  Future<void> updatePassword(String password) => _guard(
    () => _client.auth.updateUser(supabase.UserAttributes(password: password)),
  );

  @override
  Future<void> signOut() =>
      _guard(() => _client.auth.signOut(scope: supabase.SignOutScope.local));

  Future<void> _guard(Future<Object?> Function() action) async {
    try {
      await action();
    } on supabase.AuthException catch (error) {
      throw AuthFailure(_friendlyMessage(error.message));
    } catch (error) {
      throw const AuthFailure(
        'We could not complete that request. Check your connection and try again.',
      );
    }
  }

  String _friendlyMessage(String message) {
    final String normalized = message.toLowerCase();
    if (normalized.contains('invalid login credentials')) {
      return 'That email and password do not match.';
    }
    if (normalized.contains('already registered')) {
      return 'An account already exists for this email.';
    }
    if (normalized.contains('email not confirmed')) {
      return 'Confirm your email from the link we sent, then sign in.';
    }
    if (normalized.contains('rate limit') || normalized.contains('too many')) {
      return 'Too many attempts. Wait a moment and try again.';
    }
    return message;
  }

  AuthSession _session(supabase.Session? session) =>
      AuthSession(isAuthenticated: session != null, email: session?.user.email);
}

class LocalAuthenticationGateway implements AuthenticationGateway {
  const LocalAuthenticationGateway();

  @override
  bool get isAvailable => false;

  @override
  AuthSession get currentSession => const AuthSession(isAuthenticated: false);

  @override
  Stream<AuthSession> get sessionChanges => const Stream<AuthSession>.empty();

  @override
  Future<void> signIn({required String email, required String password}) =>
      _unavailable();

  @override
  Future<void> signUp({required String email, required String password}) =>
      _unavailable();

  @override
  Future<void> sendPasswordReset(String email) => _unavailable();

  @override
  Future<void> updatePassword(String password) => _unavailable();

  @override
  Future<void> signOut() async {}

  Future<void> _unavailable() => throw const AuthFailure(
    'Online account access is not configured. You can keep using MyFinance locally.',
  );
}
