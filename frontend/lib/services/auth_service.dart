import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_service.dart';

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  // Simple CSV encoding to avoid adding json_serializable dep
  String _encodeUser(AppUser u) => '${u.id}|${u.email}|${u.name}|${u.color}';

  AppUser _decodeUser(String raw) {
    final parts = raw.split('|');
    return AppUser(id: parts[0], email: parts[1], name: parts[2], color: parts[3]);
  }
}
