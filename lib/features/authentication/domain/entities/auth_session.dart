enum AuthenticationMode { localOnly, supabase }

final class AuthSession {
  const AuthSession({
    required this.isAuthenticated,
    this.email,
    this.isPasswordRecovery = false,
  });

  final bool isAuthenticated;
  final String? email;
  final bool isPasswordRecovery;
}

final class AuthenticationState {
  const AuthenticationState({
    required this.mode,
    required this.isSupabaseAvailable,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.email,
    this.isPasswordRecovery = false,
    this.notice,
    this.errorMessage,
  });

  final AuthenticationMode mode;
  final bool isSupabaseAvailable;
  final bool isAuthenticated;
  final bool isLoading;
  final String? email;
  final bool isPasswordRecovery;
  final String? notice;
  final String? errorMessage;

  AuthenticationState copyWith({
    AuthenticationMode? mode,
    bool? isSupabaseAvailable,
    bool? isAuthenticated,
    bool? isLoading,
    String? email,
    bool? isPasswordRecovery,
    String? notice,
    String? errorMessage,
    bool clearNotice = false,
    bool clearError = false,
    bool clearEmail = false,
  }) => AuthenticationState(
    mode: mode ?? this.mode,
    isSupabaseAvailable: isSupabaseAvailable ?? this.isSupabaseAvailable,
    isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    isLoading: isLoading ?? this.isLoading,
    email: clearEmail ? null : email ?? this.email,
    isPasswordRecovery: isPasswordRecovery ?? this.isPasswordRecovery,
    notice: clearNotice ? null : notice ?? this.notice,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );
}

final class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
