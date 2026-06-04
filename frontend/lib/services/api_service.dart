import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/poll.dart';
import '../models/reaction.dart';

// ── Cloudinary config ──────────────────────────────────────────────────────
// Unsigned preset — cloud name and preset name are safe to commit.
const _cloudinaryCloudName = 'dvlvgosxk';
const _cloudinaryUploadPreset = 'avatars';

const _apiHost = String.fromEnvironment(
  'API_HOST',
  defaultValue: 'api.milocalendar.tech',
);
const _isLocal = _apiHost == '127.0.0.1' || _apiHost == 'localhost';
const _baseUrl = _isLocal ? 'http://$_apiHost:3000' : 'https://$_apiHost';

class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;

  late final Dio _dio;

  ApiService._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('jwt_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          handler.next(error);
        },
      ),
    );
  }

  Dio get dio => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) => _dio.get<T>(path, queryParameters: queryParameters);

  Future<Response<T>> post<T>(String path, {dynamic data}) =>
      _dio.post<T>(path, data: data);

  Future<Response<T>> put<T>(String path, {dynamic data}) =>
      _dio.put<T>(path, data: data);

  Future<Response<T>> delete<T>(String path, {dynamic data}) =>
      _dio.delete<T>(path, data: data);

  Future<Response<T>> patch<T>(String path, {dynamic data}) =>
      _dio.patch<T>(path, data: data);

  // ── Cloudinary avatar upload ───────────────────────────────────────────────

  Future<String> uploadAvatarToCloudinary(File file) =>
      _uploadToCloudinary(file, folder: 'avatars');

  Future<String> uploadEventIconToCloudinary(File file) =>
      _uploadToCloudinary(file, folder: 'event_icons');

  /// Asks the backend to delete a Cloudinary asset. Fire-and-forget safe.
  Future<void> deleteAsset(String url) async {
    try {
      await delete('/assets', data: {'url': url});
    } catch (_) {
      // Best-effort — never block the caller
    }
  }

  Future<String> _uploadToCloudinary(File file, {required String folder}) async {
    try {
      final uploadDio = Dio();
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
        'upload_preset': _cloudinaryUploadPreset,
        'folder': folder,
      });
      final res = await uploadDio.post(
        'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload',
        data: formData,
      );
      final url = (res.data as Map<String, dynamic>)['secure_url'] as String?;
      if (url == null) throw CloudinaryUploadException('No secure_url in response');
      return url;
    } on DioException catch (e) {
      final body = e.response?.data;
      final errMap = body is Map ? body['error'] : null;
      final msg = (errMap is Map ? errMap['message'] : null) as String? ?? e.message ?? 'Unknown error';
      throw CloudinaryUploadException(msg.toString());
    } catch (e) {
      throw CloudinaryUploadException(e.toString());
    }
  }

  // ── Polls ──────────────────────────────────────────────────────────────────

  Future<EventPoll> createPoll({
    required String calendarId,
    required String title,
    String? description,
    required List<PollOptionInput> options,
    List<PollVoteOptionInput>? voteOptions,
  }) async {
    final res = await post('/calendars/$calendarId/polls', data: {
      'title': title,
      if (description != null && description.isNotEmpty) 'description': description,
      'options': options
          .map((o) => {
                'start_time': o.start.toUtc().toIso8601String(),
                'end_time': o.end.toUtc().toIso8601String(),
              })
          .toList(),
      if (voteOptions != null && voteOptions.length >= 2)
        'vote_options': voteOptions
            .map((o) => {'label': o.label, 'color': o.color})
            .toList(),
    });
    return EventPoll.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<EventPoll>> fetchPolls(String calendarId) async {
    final res = await get('/calendars/$calendarId/polls');
    return (res.data as List)
        .map((e) => EventPoll.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<EventPoll> fetchPoll(String pollId) async {
    final res = await get('/polls/$pollId');
    return EventPoll.fromJson(res.data as Map<String, dynamic>);
  }

  Future<EventPoll> votePoll({
    required String pollId,
    required String optionId,
    required String vote,
  }) async {
    final res = await post('/polls/$pollId/vote',
        data: {'option_id': optionId, 'vote': vote});
    return EventPoll.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> confirmPoll({
    required String pollId,
    required String optionId,
  }) async {
    final res =
        await post('/polls/$pollId/confirm', data: {'option_id': optionId});
    return res.data as Map<String, dynamic>;
  }

  Future<void> deletePoll(String pollId) async {
    await delete('/polls/$pollId');
  }

  // ── Reactions ──────────────────────────────────────────────────────────────

  Future<List<EventReaction>> fetchReactions(String eventId) async {
    final res = await get('/events/$eventId/reactions');
    return (res.data as List)
        .map((e) => EventReaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<EventReaction>> addReaction(String eventId, String emoji) async {
    final res = await post('/events/$eventId/reactions', data: {'emoji': emoji});
    return (res.data as List)
        .map((e) => EventReaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> removeReaction(String eventId, String emoji) async {
    await delete('/events/$eventId/reactions/${Uri.encodeComponent(emoji)}');
  }
}

class CloudinaryUploadException implements Exception {
  final String message;
  const CloudinaryUploadException(this.message);
  @override
  String toString() => 'CloudinaryUploadException: $message';
}
