import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'exceptions.dart';

/// Result of sending a sign-in code by email.
class OtpDelivery {
  const OtpDelivery({required this.maskedEmail, required this.expiresAt, this.previewCode});

  /// e.g. "s******1@campusfix.test", safe to show on screen.
  final String maskedEmail;
  final DateTime expiresAt;

  /// Only set by [SimulatedEmailOtpService], which has no mail server: the
  /// prototype shows the code on screen instead of emailing it.
  final String? previewCode;
}

/// Two-factor authentication by email: after the password is checked, a
/// 6-digit code is emailed to the university address and must be entered
/// to finish signing in.
abstract class EmailOtpService {
  static const codeLength = 6;
  static const validity = Duration(minutes: 10);
  static const maxAttempts = 5;

  /// Uses the HTTP API when the app is built with
  /// `--dart-define=OTP_API_URL=https://...`, otherwise the simulation.
  factory EmailOtpService.fromEnvironment() {
    const url = String.fromEnvironment('OTP_API_URL');
    return url.isEmpty ? SimulatedEmailOtpService() : HttpEmailOtpService(Uri.parse(url));
  }

  Future<OtpDelivery> sendCode(String email);

  /// Throws [VerificationException] when the code is wrong or expired.
  Future<void> verifyCode(String email, String code);
}

String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 1) return email;
  final name = email.substring(0, at);
  final hidden = name.length <= 2 ? '*' : '*' * (name.length - 2);
  return '${name[0]}$hidden${name[name.length - 1]}${email.substring(at)}';
}

/// Client for a real email-code API. Expected contract:
///
/// * `POST {base}/otp/send` with `{"email": "..."}` sends the code and
///   answers `200 {"expiresInSeconds": 600}`.
/// * `POST {base}/otp/verify` with `{"email": "...", "code": "123456"}`
///   answers `200 {"valid": true}`, or `{"valid": false, "message": "..."}`.
///
/// The server generates, stores, emails and rate-limits the codes; the app
/// never sees them.
class HttpEmailOtpService implements EmailOtpService {
  HttpEmailOtpService(this.baseUrl, {http.Client? client}) : _client = client ?? http.Client();

  final Uri baseUrl;
  final http.Client _client;

  @override
  Future<OtpDelivery> sendCode(String email) async {
    final body = await _post('otp/send', {'email': email},
        failure: 'We could not send the code. Check your connection and try again.');
    final seconds = (body['expiresInSeconds'] as num?)?.toInt() ??
        EmailOtpService.validity.inSeconds;
    return OtpDelivery(
      maskedEmail: maskEmail(email),
      expiresAt: DateTime.now().add(Duration(seconds: seconds)),
    );
  }

  @override
  Future<void> verifyCode(String email, String code) async {
    final body = await _post('otp/verify', {'email': email, 'code': code},
        failure: 'We could not check the code. Check your connection and try again.');
    if (body['valid'] != true) {
      throw VerificationException(
          body['message'] as String? ?? 'That code is not correct. Check the email and try again.');
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, String> data,
      {required String failure}) async {
    try {
      final response = await _client
          .post(baseUrl.resolve(path),
              headers: {'Content-Type': 'application/json'}, body: jsonEncode(data))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw VerificationException(failure);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on VerificationException {
      rethrow;
    } catch (_) {
      throw VerificationException(failure);
    }
  }
}

/// Stand-in used until a mail server is connected. It follows the same rules
/// as a real service: random 6-digit codes, 10 minute expiry, 5 attempts.
class SimulatedEmailOtpService implements EmailOtpService {
  SimulatedEmailOtpService({Random? random, DateTime Function()? clock})
      : _random = random ?? Random.secure(),
        _now = clock ?? DateTime.now;

  final Random _random;
  final DateTime Function() _now;
  final _pending = <String, ({String code, DateTime expiresAt, int attempts})>{};

  @override
  Future<OtpDelivery> sendCode(String email) async {
    final code = List.generate(EmailOtpService.codeLength, (_) => _random.nextInt(10)).join();
    final expiresAt = _now().add(EmailOtpService.validity);
    _pending[email] = (code: code, expiresAt: expiresAt, attempts: 0);
    return OtpDelivery(maskedEmail: maskEmail(email), expiresAt: expiresAt, previewCode: code);
  }

  @override
  Future<void> verifyCode(String email, String code) async {
    final entry = _pending[email];
    if (entry == null) {
      throw const VerificationException('Ask for a new code to continue.');
    }
    if (_now().isAfter(entry.expiresAt)) {
      _pending.remove(email);
      throw const VerificationException('This code has expired. Tap Resend code.');
    }
    if (entry.attempts >= EmailOtpService.maxAttempts) {
      _pending.remove(email);
      throw const VerificationException('Too many wrong codes. Tap Resend code for a new one.');
    }
    if (code.trim() != entry.code) {
      _pending[email] = (code: entry.code, expiresAt: entry.expiresAt, attempts: entry.attempts + 1);
      throw const VerificationException('That code is not correct. Check the email and try again.');
    }
    _pending.remove(email);
  }
}
