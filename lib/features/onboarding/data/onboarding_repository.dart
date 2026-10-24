import 'package:shared_preferences/shared_preferences.dart';

abstract interface class OnboardingRepository {
  Future<bool> isCompleted();
  Future<void> complete();
}

class PreferencesOnboardingRepository implements OnboardingRepository {
  PreferencesOnboardingRepository(this._preferences);

  static const completedKey = 'onboarding_completed_v1';
  final SharedPreferencesAsync _preferences;

  @override
  Future<bool> isCompleted() async =>
      await _preferences.getBool(completedKey) ?? false;

  @override
  Future<void> complete() => _preferences.setBool(completedKey, true);
}

/// Debug preview only: never reads or modifies persisted onboarding/auth state.
class PreviewOnboardingRepository implements OnboardingRepository {
  @override
  Future<bool> isCompleted() async => false;
  @override
  Future<void> complete() async {}
}
