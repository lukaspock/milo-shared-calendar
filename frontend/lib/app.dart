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
import 'screens/onboarding/onboarding_email_screen.dart';
import 'screens/onboarding/onboarding_notifications_screen.dart';
import 'screens/onboarding/onboarding_password_screen.dart';
import 'screens/onboarding/onboarding_verify_screen.dart';
import 'screens/onboarding/onboarding_calendar_screen.dart';
import 'screens/onboarding/onboarding_avatar_screen.dart';
import 'screens/onboarding/onboarding_theme_screen.dart';
import 'screens/onboarding/onboarding_ready_screen.dart';
import 'screens/onboarding/web_onboarding_screen.dart';
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, _s) => const SplashScreen()),
    GoRoute(path: '/welcome', builder: (_, _s) => const WelcomeScreen()),
    GoRoute(path: '/login', builder: (_, _s) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, _s) => const RegisterScreen()),
    GoRoute(path: '/onboarding', redirect: (_, __) => '/onboarding/name'),
    // Step 1 — name + auth method choice
    GoRoute(
      path: '/onboarding/name',
      builder: (_, _s) => const OnboardingNameEmailScreen(),
    ),
    // Keep old path as alias so existing deep-links don't break
    GoRoute(
      path: '/onboarding/name-email',
      redirect: (_, __) => '/onboarding/name',
    ),
    // Step 2 (email path) — email address
    GoRoute(
      path: '/onboarding/email',
      builder: (_, _s) => const OnboardingEmailScreen(),
    ),
    // Step 3 (email path) — notification type choice
    GoRoute(
      path: '/onboarding/notifications',
      builder: (_, _s) => const OnboardingNotificationsScreen(),
    ),
    // Step 4 (email path) — password + registers account
    GoRoute(
      path: '/onboarding/password',
      builder: (_, _s) => const OnboardingPasswordScreen(),
    ),
    // Step 3b (email path) — verify inbox
    GoRoute(
      path: '/onboarding/verify',
      builder: (_, _s) => const OnboardingVerifyScreen(),
    ),
    // Step 4 (all paths) — Google Calendar connect
    GoRoute(
      path: '/onboarding/calendar',
      builder: (_, _s) => const OnboardingCalendarScreen(),
    ),
    // Step 6 — profile photo
    GoRoute(
      path: '/onboarding/avatar',
      builder: (_, _s) => const OnboardingAvatarScreen(),
    ),
    // Step 7 — appearance / theme picker
    GoRoute(
      path: '/onboarding/theme',
      builder: (_, _s) => const OnboardingThemeScreen(),
    ),
    // Final — celebration screen
    GoRoute(
      path: '/onboarding/ready',
      builder: (_, _s) => const OnboardingReadyScreen(),
    ),
    GoRoute(
      path: '/web-onboarding',
      builder: (_, _s) => const WebOnboardingScreen(),
    ),
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
          builder: (_, state) =>
              CreatePollScreen(calendarId: state.pathParameters['calendarId']!),
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

class MiloApp extends ConsumerStatefulWidget {
  const MiloApp({super.key});

  @override
  ConsumerState<MiloApp> createState() => _MiloAppState();
}

class _MiloAppState extends ConsumerState<MiloApp> {
  @override
  void initState() {
    super.initState();
    // Load the user's persisted theme choice as soon as the widget is mounted.
    // Runs asynchronously — shows ThemeMode.system on the first frame, then
    // switches to the saved choice once SharedPreferences resolves (no
    // perceptible flash in practice since the OS theme is usually correct).
    ref.read(themeProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    return MaterialApp.router(
      title: 'Shared Calendar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
