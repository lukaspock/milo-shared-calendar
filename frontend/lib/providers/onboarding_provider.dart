import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';

class OnboardingData {
  final String name;
  final String email;
  final NotificationType notificationType;

  const OnboardingData({
    this.name = '',
    this.email = '',
    this.notificationType = NotificationType.push,
  });

  OnboardingData copyWith({
    String? name,
    String? email,
    NotificationType? notificationType,
  }) =>
      OnboardingData(
        name: name ?? this.name,
        email: email ?? this.email,
        notificationType: notificationType ?? this.notificationType,
      );
}

class OnboardingNotifier extends StateNotifier<OnboardingData> {
  OnboardingNotifier() : super(const OnboardingData());

  void setNameEmail(String name, String email) {
    state = state.copyWith(name: name, email: email);
  }

  void setNotificationType(NotificationType type) {
    state = state.copyWith(notificationType: type);
  }

  void reset() {
    state = const OnboardingData();
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingData>(
  (_) => OnboardingNotifier(),
);
