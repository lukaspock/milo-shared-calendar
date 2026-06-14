import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../models/event_photo.dart';
import '../models/poll.dart';
import '../models/reaction.dart';
import '../models/rsvp.dart';

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

  Future<String> uploadAvatarToCloudinary(XFile file) =>
      _uploadToCloudinary(file, folder: 'avatars');

  Future<String> uploadEventIconToCloudinary(XFile file) =>
      _uploadToCloudinary(file, folder: 'event_icons');

  Future<String> uploadEventPhotoToCloudinary(XFile file) =>
      _uploadToCloudinary(file, folder: 'event_photos');

  /// Asks the backend to delete a Cloudinary asset. Fire-and-forget safe.
  Future<void> deleteAsset(String url) async {
    try {
      await post('/assets/delete', data: {'url': url});
    } catch (_) {
      // Best-effort — never block the caller
    }
  }

  Future<String> _uploadToCloudinary(
    XFile file, {
    required String folder,
  }) async {
    try {
      final uploadDio = Dio();
      final bytes = await file.readAsBytes();
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: file.name),
        'upload_preset': _cloudinaryUploadPreset,
        'folder': folder,
      });
      final res = await uploadDio.post(
        'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload',
        data: formData,
      );
      final url = (res.data as Map<String, dynamic>)['secure_url'] as String?;
      if (url == null) {
        throw CloudinaryUploadException('No secure_url in response');
      }
      return url;
    } on DioException catch (e) {
      final body = e.response?.data;
      final errMap = body is Map ? body['error'] : null;
      final msg =
          (errMap is Map ? errMap['message'] : null) as String? ??
          e.message ??
          'Unknown error';
      throw CloudinaryUploadException(msg.toString());
    } catch (e) {
      throw CloudinaryUploadException(e.toString());
    }
  }

  // ── Event photos ──────────────────────────────────────────────────────────

  Future<EventPhoto> addEventPhoto(String eventId, String photoUrl) async {
    final res = await post(
      '/events/$eventId/photos',
      data: {'photo_url': photoUrl},
    );
    return EventPhoto.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<EventPhoto>> getCalendarPhotos(String calendarId) async {
    final res = await get('/calendars/$calendarId/photos');
    return (res.data as List)
        .map((e) => EventPhoto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteEventPhoto(String eventId, String photoId) async {
    await delete('/events/$eventId/photos/$photoId');
  }

  // ── Polls ──────────────────────────────────────────────────────────────────

  Future<EventPoll> createPoll({
    required String calendarId,
    required String title,
    String? description,
    required List<PollOptionInput> options,
    List<PollVoteOptionInput>? voteOptions,
    String? icon,
    String? color,
  }) async {
    final res = await post(
      '/calendars/$calendarId/polls',
      data: {
        'title': title,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
        'options': options
            .map(
              (o) => {
                'start_time': o.start.toUtc().toIso8601String(),
                'end_time': o.end.toUtc().toIso8601String(),
              },
            )
            .toList(),
        if (voteOptions != null && voteOptions.length >= 2)
          'vote_options': voteOptions
              .map((o) => {'label': o.label, 'color': o.color})
              .toList(),
      },
    );
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
    final res = await post(
      '/polls/$pollId/vote',
      data: {'option_id': optionId, 'vote': vote},
    );
    return EventPoll.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> confirmPoll({
    required String pollId,
    required String optionId,
  }) async {
    final res = await post(
      '/polls/$pollId/confirm',
      data: {'option_id': optionId},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<EventPoll> addPollOption({
    required String pollId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final res = await post(
      '/polls/$pollId/options',
      data: {
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime.toUtc().toIso8601String(),
      },
    );
    return EventPoll.fromJson(res.data as Map<String, dynamic>);
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
    final res = await post(
      '/events/$eventId/reactions',
      data: {'emoji': emoji},
    );
    return (res.data as List)
        .map((e) => EventReaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> removeReaction(String eventId, String emoji) async {
    await delete('/events/$eventId/reactions/${Uri.encodeComponent(emoji)}');
  }

  // ── Chat ───────────────────────────────────────────────────────────────────

  Future<List<ChatMessage>> getChatMessages(
    String calendarId, {
    String? before,
  }) async {
    final query = before != null
        ? '?before=${Uri.encodeComponent(before)}'
        : '';
    final resp = await _dio.get<List<dynamic>>(
      '/calendars/$calendarId/messages$query',
    );
    return (resp.data as List)
        .map((j) => ChatMessage.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessage> sendChatMessage(String calendarId, String content) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/calendars/$calendarId/messages',
      data: {'content': content},
    );
    return ChatMessage.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> deleteChatMessage(String calendarId, String messageId) async {
    await _dio.delete<void>('/calendars/$calendarId/messages/$messageId');
  }

  // ── RSVPs ──────────────────────────────────────────────────────────────────

  Future<Map<String, RsvpSummary>> getCalendarRsvps(String calendarId) async {
    final res = await get<Map<String, dynamic>>('/calendars/$calendarId/rsvps');
    final data = res.data as Map<String, dynamic>;
    return data.map(
      (k, v) => MapEntry(k, RsvpSummary.fromJson(v as Map<String, dynamic>)),
    );
  }

  Future<EventRsvpDetail> getRsvpDetail(String eventId) async {
    final res = await get<Map<String, dynamic>>('/events/$eventId/rsvps');
    return EventRsvpDetail.fromJson(res.data as Map<String, dynamic>);
  }

  Future<EventRsvpDetail> setRsvp(String eventId, String status) async {
    final res = await post<Map<String, dynamic>>(
      '/events/$eventId/rsvp',
      data: {'status': status},
    );
    return EventRsvpDetail.fromJson(res.data as Map<String, dynamic>);
  }

  Future<EventRsvpDetail> deleteRsvp(String eventId) async {
    final res = await delete<Map<String, dynamic>>('/events/$eventId/rsvp');
    return EventRsvpDetail.fromJson(res.data as Map<String, dynamic>);
  }
}

class CloudinaryUploadException implements Exception {
  final String message;
  const CloudinaryUploadException(this.message);
  @override
  String toString() => 'CloudinaryUploadException: $message';
}
