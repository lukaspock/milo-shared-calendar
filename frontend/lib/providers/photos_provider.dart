import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_photo.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

class PhotosNotifier extends StateNotifier<AsyncValue<List<EventPhoto>>> {
  PhotosNotifier(this.calendarId) : super(const AsyncValue.loading()) {
    fetch();
    _listenToWebSocket();
  }

  final String calendarId;
  final _api = ApiService();
  final _ws = WebSocketService();

  Future<void> fetch() async {
    try {
      final photos = await _api.getCalendarPhotos(calendarId);
      state = AsyncValue.data(photos);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _listenToWebSocket() {
    _ws.addListener(_onWsMessage);
    _ws.subscribeToCalendar(calendarId);
  }

  void _onWsMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    if (type == 'photo_added') {
      final photoData = msg['photo'] as Map<String, dynamic>?;
      if (photoData == null) return;
      if (photoData['calendar_id'] != calendarId) return;
      final photo = EventPhoto.fromJson(photoData);
      state.whenData((list) {
        if (list.any((p) => p.id == photo.id)) return;
        state = AsyncValue.data([photo, ...list]);
      });
    } else if (type == 'photo_deleted') {
      final photoId = msg['photo_id'] as String?;
      final cal = msg['calendar_id'] as String?;
      if (photoId == null || cal != calendarId) return;
      state.whenData((list) {
        state = AsyncValue.data(list.where((p) => p.id != photoId).toList());
      });
    }
  }

  Future<bool> addPhoto(String eventId, XFile imageFile) async {
    try {
      final url = await _api.uploadEventPhotoToCloudinary(imageFile);
      await _api.addEventPhoto(eventId, url);
      // Immediately refresh so the uploader sees their photo without waiting for WS
      await fetch();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deletePhoto(String eventId, String photoId) async {
    try {
      await _api.deleteEventPhoto(eventId, photoId);
      state.whenData((list) {
        state = AsyncValue.data(list.where((p) => p.id != photoId).toList());
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _ws.removeListener(_onWsMessage);
    super.dispose();
  }
}

final photosProvider =
    StateNotifierProvider.family<
      PhotosNotifier,
      AsyncValue<List<EventPhoto>>,
      String
    >((_, calendarId) => PhotosNotifier(calendarId));
