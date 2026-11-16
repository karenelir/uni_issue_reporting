import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/otp_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/feedback.dart';

/// Second sign-in step: the 6-digit code emailed to the university address
/// (two-factor authentication).
class VerifyCodeScreen extends StatefulWidget {
  const VerifyCodeScreen({super.key});

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  static const _resendDelay = 30;

  final _code = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  String? _error;
  int _resendIn = _resendDelay;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _resendIn = _resendDelay);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != EmailOtpService.codeLength) {
      setState(() => _error = 'Enter the ${EmailOtpService.codeLength}-digit code from the email.');
      _focus.requestFocus();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppState>().verifySignInCode(code);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = describeError(e));
      _code.clear();
      _focus.requestFocus();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      await context.read<AppState>().resendSignInCode();
      if (!mounted) return;
      _code.clear();
      setState(() => _error = null);
      _startCountdown();
      showMessage(context, 'A new code was sent.');
    } catch (e) {
      if (mounted) showMessage(context, describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pending = state.pendingSignIn;
    if (pending == null) return const Scaffold();
    final delivery = pending.delivery;
    final minutes = EmailOtpService.validity.inMinutes;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) state.cancelSignIn();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          leading: IconButton(
            tooltip: 'Back to sign in',
            icon: const Icon(Icons.arrow_back),
            onPressed: state.cancelSignIn,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mark_email_read_outlined,
                            size: 44, color: AppColors.brand),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Check your email',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'We sent a 6-digit code to '),
                        TextSpan(
                            text: delivery.maskedEmail,
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                        TextSpan(text: '. It expires in $minutes minutes.'),
                      ]),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15.5, color: AppColors.inkMuted, height: 1.4),
                    ),
                    if (delivery.previewCode != null) ...[
                      const SizedBox(height: 16),
                      _PrototypeNotice(code: delivery.previewCode!),
                    ],
                    const SizedBox(height: 24),
                    TextField(
                      controller: _code,
                      focusNode: _focus,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: EmailOtpService.codeLength,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 12),
                      decoration: InputDecoration(
                        labelText: 'Verification code',
                        hintText: '000000',
                        counterText: '',
                        errorText: _error,
                      ),
                      onChanged: (v) {
                        if (_error != null) setState(() => _error = null);
                        if (v.length == EmailOtpService.codeLength) _verify();
                      },
                      onSubmitted: (_) => _verify(),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _verify,
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text('Verify and sign in'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _resendIn > 0 ? null : _resend,
                      child: Text(_resendIn > 0
                          ? 'Resend code in $_resendIn s'
                          : 'Resend code'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Did not get it? Check your spam folder. Never share this code with anyone.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.5, color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// No mail server is connected in the prototype, so the code is shown here.
class _PrototypeNotice extends StatelessWidget {
  const _PrototypeNotice({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined, color: AppColors.onWarningContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Prototype: no email server is connected. Your code is '),
                TextSpan(
                    text: code,
                    style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2)),
              ]),
              style: const TextStyle(color: AppColors.onWarningContainer),
            ),
          ),
        ],
      ),
    );
  }
}
