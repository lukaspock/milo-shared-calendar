import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_service.dart';

// Web Application client ID from Google Cloud Console.
// The serverClientId enables serverAuthCode so our backend can get
// a refresh token and sync to Google Calendar.
const _kServerClientId =
    '583283682704-ru7t2guho8bd8p42gmi1u6c8ruq9mq3a.apps.googleusercontent.com';

final _googleSignIn = GoogleSignIn(
  serverClientId: _kServerClientId,
  scopes: [
    'email',
    'https://www.googleapis.com/auth/calendar',
  ],
);

class AuthService {
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;
  AuthService._();

  final _api = ApiService();

  static const _tokenKey = 'jwt_token';
  static const _userKey = 'current_user';

  Future<({String token, AppUser user})> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final res = await _api.post('/auth/register', data: {
      'email': email,
      'password': password,
      'name': name,
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
    final googleUser = await _googleSignIn.signIn();
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

  Future<void> _saveSession(String token, AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, _encodeUser(user));
  }

  Future<AppUser?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    return _decodeUser(raw);
  }

  Future<String?> getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> logout() async {
    try { await _googleSignIn.signOut(); } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<void> deleteAccount() async {
    await _api.delete('/users/me');
    try { await _googleSignIn.signOut(); } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<AppUser> refreshUser() async {
    final res = await _api.get('/auth/me');
    final user = AppUser.fromJson(res.data as Map<String, dynamic>);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, _encodeUser(user));
    return user;
  }

  Future<void> resendVerification() async {
    await _api.post('/auth/resend-verification');
  }

  // Pipe-separated encoding — fields must not contain '|'
  String _encodeUser(AppUser u) =>
      '${u.id}|${u.email}|${u.name}|${u.color}|${u.emailVerified}|${u.hasGoogleCalendar}';

  AppUser _decodeUser(String raw) {
    final p = raw.split('|');
    return AppUser(
      id: p[0],
      email: p[1],
      name: p[2],
      color: p[3],
      emailVerified: p.length > 4 ? p[4] == 'true' : false,
      hasGoogleCalendar: p.length > 5 ? p[5] == 'true' : false,
    );
  }
}
