import 'package:campusfix/data/exceptions.dart';
import 'package:campusfix/data/otp_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const email = 'student1@campusfix.test';

  test('a sent code verifies once and hides the email', () async {
    final otp = SimulatedEmailOtpService();
    final delivery = await otp.sendCode(email);
    expect(delivery.previewCode, hasLength(6));
    expect(delivery.maskedEmail, 's******1@campusfix.test');
    await otp.verifyCode(email, delivery.previewCode!);
    // A used code cannot be reused.
    await expectLater(otp.verifyCode(email, delivery.previewCode!),
        throwsA(isA<VerificationException>()));
  });

  test('codes expire after 10 minutes', () async {
    var now = DateTime(2026, 11, 12, 10);
    final otp = SimulatedEmailOtpService(clock: () => now);
    final code = (await otp.sendCode(email)).previewCode!;
    now = now.add(const Duration(minutes: 11));
    await expectLater(otp.verifyCode(email, code),
        throwsA(isA<VerificationException>().having((e) => e.message, 'message', contains('expired'))));
  });

  test('after 5 wrong codes even the right one is refused', () async {
    final otp = SimulatedEmailOtpService();
    final code = (await otp.sendCode(email)).previewCode!;
    final wrong = code == '000000' ? '111111' : '000000';
    for (var i = 0; i < EmailOtpService.maxAttempts; i++) {
      await expectLater(otp.verifyCode(email, wrong), throwsA(isA<VerificationException>()));
    }
    await expectLater(otp.verifyCode(email, code), throwsA(isA<VerificationException>()));
  });
}
