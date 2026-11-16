import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import 'exceptions.dart';
import 'test_accounts.dart';

/// Checks university credentials against the simulated accounts, keeps the
/// session between launches, and lets users change their password.
///
/// Sign-in has two steps: [checkPassword] here, then an email code from
/// [EmailOtpService]; [startSession] is only called once both pass.
class AuthService {
  AuthService(this._prefs, [this._accounts = testAccounts]);

  static const _sessionKey = 'session_user_id';
  static const minPasswordLength = 8;

  final SharedPreferences _prefs;
  final List<TestAccount> _accounts;

  AppUser? restoreSession() {
    final id = _prefs.getString(_sessionKey);
    if (id == null) return null;
    return _accountById(id)?.user;
  }

  /// First sign-in step: returns the account if the password is right.
  /// No session is started yet.
  Future<AppUser> checkPassword(String email, String password) async {
    final normalized = email.trim().toLowerCase();
    for (final account in _accounts) {
      if (account.user.email == normalized && _matches(account, password)) {
        return account.user;
      }
    }
    throw const InvalidCredentialsException();
  }

  /// Final sign-in step, after the email code was verified.
  Future<void> startSession(AppUser user) => _prefs.setString(_sessionKey, user.id);

  Future<void> signOut() => _prefs.remove(_sessionKey);

  /// Problems with [password] as a new password, in plain language; empty
  /// when it is acceptable.
  static List<String> passwordProblems(String password) => [
        if (password.length < minPasswordLength) 'At least $minPasswordLength characters',
        if (!RegExp('[A-Za-z]').hasMatch(password)) 'At least one letter',
        if (!RegExp('[0-9]').hasMatch(password)) 'At least one number',
      ];

  /// Changes the password after checking the current one. The new password
  /// is stored only as a salted hash.
  Future<void> changePassword(AppUser user, String current, String next) async {
    final account = _accountById(user.id);
    if (account == null || !_matches(account, current)) {
      throw const PasswordChangeException('Your current password is not correct.');
    }
    final problems = passwordProblems(next);
    if (problems.isNotEmpty) {
      throw PasswordChangeException('New password needs: ${problems.join(', ').toLowerCase()}.');
    }
    if (next == current) {
      throw const PasswordChangeException('Choose a password different from the current one.');
    }
    await _prefs.setString(_hashKey(user.id), _hash(user.id, next));
  }

  TestAccount? _accountById(String id) {
    for (final account in _accounts) {
      if (account.user.id == id) return account;
    }
    return null;
  }

  bool _matches(TestAccount account, String password) {
    final stored = _prefs.getString(_hashKey(account.user.id));
    return stored != null ? stored == _hash(account.user.id, password) : account.password == password;
  }

  static String _hashKey(String userId) => 'password_hash_$userId';

  static String _hash(String userId, String password) =>
      sha256.convert(utf8.encode('campusfix:$userId:$password')).toString();
}
