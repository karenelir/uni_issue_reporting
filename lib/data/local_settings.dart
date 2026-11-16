import 'package:shared_preferences/shared_preferences.dart';

/// Small per-device settings: whether the intro pages and the guided tour of
/// the main screen were already shown.
class LocalSettings {
  LocalSettings(this._prefs);

  static const onboardingKey = 'onboarding_seen';
  static const tourKey = 'tour_seen';

  final SharedPreferences _prefs;

  bool get onboardingSeen => _prefs.getBool(onboardingKey) ?? false;

  Future<void> markOnboardingSeen() => _prefs.setBool(onboardingKey, true);

  bool get tourSeen => _prefs.getBool(tourKey) ?? false;

  Future<void> setTourSeen(bool value) => _prefs.setBool(tourKey, value);
}
