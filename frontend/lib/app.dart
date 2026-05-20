import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/event_detail_screen.dart';
import 'screens/create_poll_screen.dart';
import 'screens/poll_detail_screen.dart';
import 'theme/app_theme.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, _s) => const SplashScreen()),
    GoRoute(path: '/login', builder: (_, _s) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, _s) => const RegisterScreen()),
    GoRoute(path: '/home', builder: (_, _s) => const HomeScreen()),
    GoRoute(
      path: '/calendar/:calendarId',
      builder: (_, state) =>
          CalendarScreen(calendarId: state.pathParameters['calendarId']!),
      routes: [
        GoRoute(
          path: 'event/:eventId',
          builder: (_, state) => EventDetailScreen(
            calendarId: state.pathParameters['calendarId']!,
            eventId: state.pathParameters['eventId']!,
            extra: state.extra,
          ),
        ),
        GoRoute(
          path: 'polls/new',
          builder: (_, state) => CreatePollScreen(
            calendarId: state.pathParameters['calendarId']!,
          ),
        ),
        GoRoute(
          path: 'polls/:pollId',
          builder: (_, state) => PollDetailScreen(
            calendarId: state.pathParameters['calendarId']!,
            pollId: state.pathParameters['pollId']!,
            extra: state.extra,
          ),
        ),
      ],
    ),
  ],
);

class SharedCalApp extends ConsumerWidget {
  const SharedCalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SharedCal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
