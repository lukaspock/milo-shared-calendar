import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final AppUser? user;
  final String? error;
  /// True immediately after a new account is created (Google or email).
  /// Used to route new users through onboarding instead of straight to /home.
  final bool isNewUser;

  const AuthState({
    required this.status,
    this.user,
    this.error,
    this.isNewUser = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    String? error,
    bool? isNewUser,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: error,
        isNewUser: isNewUser ?? this.isNewUser,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(status: AuthStatus.loading)) {
    _init();
  }

  final _authService = AuthService();

  Future<void> _init() async {
    final user = await _authService.getStoredUser();
    if (user != null) {
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final result = await _authService.login(email: email, password: password);
      state = AuthState(status: AuthStatus.authenticated, user: result.user);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: _parseError(e),
      );
    }
  }

  Future<void> register(String email, String password, String name) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final result = await _authService.register(
          email: email, password: password, name: name);
      state = AuthState(status: AuthStatus.authenticated, user: result.user);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: _parseError(e),
      );
    }
  }

  Future<void> googleSignIn() async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final result = await _authService.signInWithGoogle();
      state = AuthState(
        status: AuthStatus.authenticated,
        user: result.user,
        isNewUser: result.isNew,
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: e.toString().contains('cancelled') ? null : _parseError(e),
      );
    }
  }

  /// Tries to register first; if the email is already taken (409) it falls
  /// back to login with the same credentials.  Sets [isNewUser] accordingly.
  Future<void> loginOrRegister(
      String email, String password, String name) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final result = await _authService.register(
          email: email, password: password, name: name);
      state = AuthState(
        status: AuthStatus.authenticated,
        user: result.user,
        isNewUser: true,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        // Account already exists — log in instead
        try {
          final result =
              await _authService.login(email: email, password: password);
          state = AuthState(
            status: AuthStatus.authenticated,
            user: result.user,
            isNewUser: false,
          );
        } catch (loginErr) {
          state = AuthState(
            status: AuthStatus.unauthenticated,
            error: _parseError(loginErr),
          );
        }
      } else {
        state = AuthState(
          status: AuthStatus.unauthenticated,
          error: _parseError(e),
        );
      }
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<bool> deleteAccount() async {
    try {
      await _authService.deleteAccount();
      state = const AuthState(status: AuthStatus.unauthenticated);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> refreshUser() async {
    try {
      final user = await _authService.refreshUser();
      state = state.copyWith(user: user);
    } catch (_) {}
  }

  Future<bool> resendVerification() async {
    try {
      await _authService.resendVerification();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getGoogleCalendarConnectUrl() async {
    try {
      return await _authService.getGoogleCalendarConnectUrl();
    } catch (_) {
      return null;
    }
  }

  String _parseError(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (status == 400) return 'Invalid input. Check your details.';
      if (status == 401) return 'Invalid email or password.';
      if (status == 409) return 'Email already registered.';
      if (status == 404) return 'Server resource not found.';
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'Cannot reach server. Is the backend running?';
      }
    }
    return 'Error: ${e.toString()}';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (_) => AuthNotifier(),
);
