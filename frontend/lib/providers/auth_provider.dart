import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/cache_service.dart';

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final AppUser? user;
  final String? error;

  const AuthState({required this.status, this.user, this.error});

  AuthState copyWith({AuthStatus? status, AppUser? user, String? error}) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: error,
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

  Future<void> register(
    String email,
    String password,
    String name, {
    NotificationType notificationType = NotificationType.email,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final result = await _authService.register(
          email: email,
          password: password,
          name: name,
          notificationType: notificationType);
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
      state = AuthState(status: AuthStatus.authenticated, user: result.user);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: e.toString().contains('cancelled') ? null : _parseError(e),
      );
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    await CacheService().clearAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<bool> deleteAccount() async {
    try {
      await _authService.deleteAccount();
      await CacheService().clearAll();
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

  /// Updates how the user is notified about new events ('email' vs on-device push).
  /// Optimistically updates local state, then persists to the backend.
  Future<bool> updateNotificationType(NotificationType type) async {
    final previous = state.user;
    if (previous != null) {
      state = state.copyWith(user: previous.copyWith(notificationType: type));
    }
    try {
      final user = await _authService.updateNotificationType(type);
      state = state.copyWith(user: user);
      return true;
    } catch (_) {
      if (previous != null) state = state.copyWith(user: previous);
      return false;
    }
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
