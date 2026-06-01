import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/local_notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadCalendarHues();
  // Initialize on-device notifications + the global WebSocket listener that
  // surfaces them. Safe no-op for users on email notifications.
  await LocalNotificationService().init();
  // ProviderScope (not UncontrolledProviderScope) is required here so that
  // ProviderScope.containerOf(context) works inside showModalBottomSheet
  // builders. UncontrolledProviderScope is not found by containerOf and
  // causes modal overlays to crash silently in release/web builds.
  runApp(const ProviderScope(child: SharedCalApp()));
}
