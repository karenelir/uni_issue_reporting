import 'package:shared_preferences/shared_preferences.dart';

/// Remembers whether the Terms of Use and Privacy Policy were accepted on
/// this device. Raising [currentVersion] asks everyone to accept again.
class ConsentService {
  ConsentService(this._prefs);

  static const currentVersion = 1;
  static const _versionKey = 'terms_accepted_version';
  static const _dateKey = 'terms_accepted_at';

  final SharedPreferences _prefs;

  bool get hasAcceptedCurrent => (_prefs.getInt(_versionKey) ?? 0) >= currentVersion;

  DateTime? get acceptedAt {
    final raw = _prefs.getString(_dateKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> accept() async {
    await _prefs.setInt(_versionKey, currentVersion);
    await _prefs.setString(_dateKey, DateTime.now().toIso8601String());
  }

  Future<void> withdraw() async {
    await _prefs.remove(_versionKey);
    await _prefs.remove(_dateKey);
  }
}
