import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_service.dart';

// Web Application client ID from Google Cloud Console.
// Used as clientId on web (required by google_sign_in_web) and as
// serverClientId on mobile/desktop (so the backend can verify ID tokens and
// exchange for Calendar refresh tokens).
const _kWebClientId =
    '583283682704-ru7t2guho8bd8p42gmi1u6c8ruq9mq3a.apps.googleusercontent.com';

// macOS OAuth client ID — must be passed explicitly as clientId on macOS,
// otherwise google_sign_in cannot initiate the OAuth flow (invalid_client).
const _kMacOSClientId =
    '583283682704-ethnu73r7o8rblkvra89qsibo0tlq7pp.apps.googleusercontent.com';

final _googleSignIn = GoogleSignIn(
  clientId: kIsWeb
      ? _kWebClientId
      : (defaultTargetPlatform == TargetPlatform.macOS
          ? _kMacOSClientId
          : null),
  serverClientId: kIsWeb ? null : _kWebClientId,
  scopes: ['email'],
);

class AuthService {
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;
  AuthService._();

  final _api = ApiService();

  static const _tokenKey = 'jwt_token';
  static const _userKey = 'current_user';

  /// In-memory cache of the current user, kept in sync with SharedPreferences.
  /// Lets synchronous callers (e.g. the WebSocket notification listener) read
  /// the current notification preference without awaiting storage.
  AppUser? cachedUser;

  Future<({String token, AppUser user})> register({
    required String email,
    required String password,
    required String name,
    NotificationType notificationType = NotificationType.email,
  }) async {
    final res = await _api.post('/auth/register', data: {
      'email': email,
      'password': password,
      'name': name,
      'notification_type': notificationType.apiValue,
    });
    final data = res.data as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    await _saveSession(token, user);
    return (token: token, user: user);
  }

  Future<({String token, AppUser user})> login({
    required String email,
    required String password,
  }) async {
    final res = await _api.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final data = res.data as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    await _saveSession(token, user);
    return (token: token, user: user);
  }

  Future<({String token, AppUser user})> signInWithGoogle() async {
    GoogleSignInAccount? googleUser;
    try {
      googleUser = await _googleSignIn.signIn();
    } catch (e) {
      // On web, google_sign_in_web calls the People API after OAuth to fetch
      // the user profile. If that API is disabled the call throws, but GIS
      // already set currentUser with the tokens we actually need.
      if (kIsWeb) {
        googleUser = _googleSignIn.currentUser;
      } else {
        rethrow;
      }
    }
    if (googleUser == null) throw Exception('Google sign-in cancelled');

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) throw Exception('No ID token from Google');

    final res = await _api.post('/auth/google', data: {'idToken': idToken});
    final data = res.data as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    await _saveSession(token, user);
    return (token: token, user: user);
  }

  Future<String> getGoogleCalendarConnectUrl() async {
    final res = await _api.post('/auth/google-calendar/connect');
    return (res.data as Map<String, dynamic>)['url'] as String;
  }

  /// Persists the user's preferred notification delivery method on the backend
  /// and returns the refreshed user.
  Future<AppUser> updateNotificationType(NotificationType type) async {
    await _api.put('/auth/notification-type',
        data: {'notification_type': type.apiValue});
    return refreshUser();
  }

  Future<void> _saveSession(String token, AppUser user) async {
    cachedUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, _encodeUser(user));
  }

  Future<AppUser?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    final user = _decodeUser(raw);
    cachedUser = user;
    return user;
  }

  Future<String?> getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> logout() async {
    cachedUser = null;
    try { await _googleSignIn.signOut(); } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<void> deleteAccount() async {
    await _api.delete('/users/me');
    cachedUser = null;
    try { await _googleSignIn.signOut(); } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<AppUser> refreshUser() async {
    final res = await _api.get('/auth/me');
    final user = AppUser.fromJson(res.data as Map<String, dynamic>);
    cachedUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, _encodeUser(user));
    return user;
  }

  Future<void> resendVerification() async {
    await _api.post('/auth/resend-verification');
  }

  Future<void> forgotPassword(String email) async {
    await _api.post('/auth/forgot-password', data: {'email': email});
  }

  // Pipe-separated encoding — fields must not contain '|'
  String _encodeUser(AppUser u) =>
      '${u.id}|${u.email}|${u.name}|${u.color}|${u.emailVerified}|${u.hasGoogleCalendar}|${u.notificationType.apiValue}';

  AppUser _decodeUser(String raw) {
    final p = raw.split('|');
    return AppUser(
      id: p[0],
      email: p[1],
      name: p[2],
      color: p[3],
      emailVerified: p.length > 4 ? p[4] == 'true' : false,
      hasGoogleCalendar: p.length > 5 ? p[5] == 'true' : false,
      notificationType:
          p.length > 6 ? NotificationType.fromApi(p[6]) : NotificationType.email,
    );
  }
}
