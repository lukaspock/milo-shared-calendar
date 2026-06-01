import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'providers/theme_provider.dart';
import 'services/local_notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadCalendarHues();
  // Initialize on-device notifications + the global WebSocket listener that
  // surfaces them. Safe no-op for users on email notifications.
  await LocalNotificationService().init();

  // Load persisted theme before first frame so there's no flash of wrong theme.
  final container = ProviderContainer();
  await container.read(themeProvider.notifier).load();

  runApp(UncontrolledProviderScope(
    container: container,
    child: const SharedCalApp(),
  ));
}
