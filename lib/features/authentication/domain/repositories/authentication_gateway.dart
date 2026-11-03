import 'package:bill_tracker/features/authentication/domain/entities/auth_session.dart';

abstract interface class AuthenticationGateway {
  bool get isAvailable;
  AuthSession get currentSession;
  Stream<AuthSession> get sessionChanges;

  Future<void> signIn({required String email, required String password});
  Future<void> signUp({required String email, required String password});
  Future<void> sendPasswordReset(String email);
  Future<void> updatePassword(String password);
  Future<void> signOut();
}
