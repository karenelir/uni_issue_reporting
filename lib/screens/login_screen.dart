import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/test_accounts.dart';
import '../models/app_user.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/feedback.dart';
import 'legal_screen.dart';

/// Screen 1: one sign-in screen for students and staff (FR1, FR2).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  late bool _acceptedTerms = context.read<AppState>().consent.hasAcceptedCurrent;
  bool _showTermsError = false;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  late final _termsTap = TapGestureRecognizer()
    ..onTap = () => _openLegal(LegalDocument.terms);
  late final _privacyTap = TapGestureRecognizer()
    ..onTap = () => _openLegal(LegalDocument.privacy);

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  void _openLegal(LegalDocument doc) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => LegalScreen(document: doc)));
  }

  Future<void> _signIn() async {
    setState(() => _error = null);
    final fieldsValid = _formKey.currentState!.validate();
    setState(() => _showTermsError = !_acceptedTerms);
    if (!fieldsValid) {
      // Return the cursor to the first field that needs fixing.
      (_email.text.trim().isEmpty || !_email.text.contains('@') ? _emailFocus : _passwordFocus)
          .requestFocus();
      return;
    }
    if (!_acceptedTerms) return;

    setState(() => _busy = true);
    try {
      await context
          .read<AppState>()
          .signIn(_email.text, _password.text, acceptedTerms: _acceptedTerms);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = describeError(e));
      _passwordFocus.requestFocus();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fillTestAccount(TestAccount account) {
    setState(() {
      _email.text = account.user.email;
      _password.text = account.password;
      _error = null;
    });
    _formKey.currentState?.validate();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _BrandHeader(),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Welcome back',
                            style: textTheme.headlineSmall
                                ?.copyWith(color: AppColors.ink, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        const Text('Sign in with your university account',
                            style: TextStyle(fontSize: 15, color: AppColors.inkMuted)),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _email,
                          focusNode: _emailFocus,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'University email',
                            hintText: 'name@university.edu',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return 'Enter your university email.';
                            if (!value.contains('@')) {
                              return 'This does not look like an email. It should contain @.';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _password,
                          focusNode: _passwordFocus,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _obscure ? 'Show password' : 'Hide password',
                              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Enter your password.' : null,
                          onFieldSubmitted: (_) => _signIn(),
                        ),
                        const SizedBox(height: 12),
                        _TermsCheckbox(
                          value: _acceptedTerms,
                          showError: _showTermsError,
                          termsTap: _termsTap,
                          privacyTap: _privacyTap,
                          onChanged: (v) => setState(() {
                            _acceptedTerms = v;
                            if (v) _showTermsError = false;
                          }),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          _ErrorBanner(_error!),
                        ],
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _busy ? null : _signIn,
                          child: _busy
                              ? const SizedBox(
                                  width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                              : const Text('Sign in'),
                        ),
                        const SizedBox(height: 24),
                        _TestAccountsHelp(onPick: _fillTestAccount),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Brand area at the top of the sign-in screen.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brand, AppColors.brandDark],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 36),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.handyman_rounded, size: 44, color: AppColors.brand),
              ),
              const SizedBox(height: 16),
              const Text('CampusFix',
                  style: TextStyle(
                      fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 4),
              const Text('Report it. Vote on it. Follow it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Color(0xFFE0F2EF))),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({
    required this.value,
    required this.showError,
    required this.termsTap,
    required this.privacyTap,
    required this.onChanged,
  });

  final bool value;
  final bool showError;
  final GestureRecognizer termsTap;
  final GestureRecognizer privacyTap;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    const linkStyle = TextStyle(
      color: AppColors.brand,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              semanticLabel: 'I agree to the Terms of Use and the Privacy Policy',
              isError: showError,
              onChanged: (v) => onChanged(v ?? false),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'I have read and agree to the '),
                    TextSpan(text: 'Terms of Use', style: linkStyle, recognizer: termsTap),
                    const TextSpan(text: ' and the '),
                    TextSpan(text: 'Privacy Policy', style: linkStyle, recognizer: privacyTap),
                    const TextSpan(text: '.'),
                  ]),
                  style: const TextStyle(fontSize: 15, color: AppColors.ink),
                ),
              ),
            ),
          ],
        ),
        if (showError)
          const Padding(
            padding: EdgeInsets.only(left: 12, top: 2),
            child: Text(
              'Tick the box to accept the Terms of Use and Privacy Policy.',
              style: TextStyle(color: AppColors.error, fontSize: 14),
            ),
          ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(color: AppColors.ink, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The prototype runs on simulated accounts only (Section 9.2). Listing them
/// lets testers pick one instead of remembering it.
class _TestAccountsHelp extends StatelessWidget {
  const _TestAccountsHelp({required this.onPick});

  final ValueChanged<TestAccount> onPick;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warningContainer,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.info_outline, color: AppColors.onWarningContainer),
          title: const Text('Test accounts (prototype)',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.onWarningContainer)),
          subtitle: const Text('Tap one to fill in the form',
              style: TextStyle(color: AppColors.onWarningContainer)),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          children: [
            for (final account in testAccounts)
              ListTile(
                leading: Icon(account.user.role == UserRole.staff
                    ? Icons.badge_outlined
                    : Icons.school_outlined),
                title: Text(account.user.role == UserRole.staff ? 'Staff' : account.user.name),
                subtitle: Text(account.user.email),
                onTap: () => onPick(account),
              ),
          ],
        ),
      ),
    );
  }
}
