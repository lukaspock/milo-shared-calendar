import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/event_detail_screen.dart';
import 'screens/create_poll_screen.dart';
import 'screens/poll_detail_screen.dart';
import 'screens/onboarding/onboarding_name_email_screen.dart';
import 'screens/onboarding/onboarding_password_screen.dart';
import 'screens/onboarding/onboarding_verify_screen.dart';
import 'screens/onboarding/onboarding_calendar_screen.dart';
import 'screens/onboarding/onboarding_ready_screen.dart';
import 'theme/app_theme.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, _s) => const SplashScreen()),
    GoRoute(path: '/welcome', builder: (_, _s) => const WelcomeScreen()),
    GoRoute(path: '/login', builder: (_, _s) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, _s) => const RegisterScreen()),
    GoRoute(
      path: '/onboarding',
      redirect: (_, __) => '/onboarding/name-email',
    ),
    GoRoute(
        path: '/onboarding/name-email',
        builder: (_, _s) => const OnboardingNameEmailScreen()),
    GoRoute(
        path: '/onboarding/password',
        builder: (_, _s) => const OnboardingPasswordScreen()),
    GoRoute(
        path: '/onboarding/verify',
        builder: (_, _s) => const OnboardingVerifyScreen()),
    GoRoute(
        path: '/onboarding/calendar',
        builder: (_, _s) => const OnboardingCalendarScreen()),
    GoRoute(
        path: '/onboarding/ready',
        builder: (_, _s) => const OnboardingReadyScreen()),
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
