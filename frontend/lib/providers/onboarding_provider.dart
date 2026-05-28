import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingData {
  final String name;
  final String email;

  const OnboardingData({this.name = '', this.email = ''});

  OnboardingData copyWith({String? name, String? email}) => OnboardingData(
        name: name ?? this.name,
        email: email ?? this.email,
      );
}

class OnboardingNotifier extends StateNotifier<OnboardingData> {
  OnboardingNotifier() : super(const OnboardingData());

  void setNameEmail(String name, String email) {
    state = state.copyWith(name: name, email: email);
  }

  void reset() {
    state = const OnboardingData();
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingData>(
  (_) => OnboardingNotifier(),
);
