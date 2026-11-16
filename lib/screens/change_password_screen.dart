import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/auth_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/feedback.dart';

/// Change password: current password, then the new one twice, with the rules
/// shown live so nothing has to be guessed (error prevention).
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  final _currentFocus = FocusNode();
  bool _show = false;
  bool _busy = false;
  bool _tried = false;
  String? _currentError;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    _currentFocus.dispose();
    super.dispose();
  }

  List<String> get _problems => AuthService.passwordProblems(_next.text);
  bool get _matches => _confirm.text.isNotEmpty && _confirm.text == _next.text;

  Future<void> _save() async {
    setState(() {
      _tried = true;
      _currentError = _current.text.isEmpty ? 'Enter your current password.' : null;
    });
    if (_current.text.isEmpty || _problems.isNotEmpty || !_matches) return;

    setState(() => _busy = true);
    try {
      await context.read<AppState>().changePassword(_current.text, _next.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      showMessage(context, 'Password changed. Use it next time you sign in.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _currentError = describeError(e));
      _currentFocus.requestFocus();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = [
      ('At least ${AuthService.minPasswordLength} characters', _next.text.length >= AuthService.minPasswordLength),
      ('At least one letter', RegExp('[A-Za-z]').hasMatch(_next.text)),
      ('At least one number', RegExp('[0-9]').hasMatch(_next.text)),
      ('Both new passwords match', _matches),
    ];

    InputDecoration field(String label, {String? error}) => InputDecoration(
          labelText: label,
          errorText: error,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            tooltip: _show ? 'Hide passwords' : 'Show passwords',
            icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => setState(() => _show = !_show),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _current,
            focusNode: _currentFocus,
            obscureText: !_show,
            autofillHints: const [AutofillHints.password],
            decoration: field('Current password', error: _currentError),
            onChanged: (_) => setState(() => _currentError = null),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _next,
            obscureText: !_show,
            autofillHints: const [AutofillHints.newPassword],
            decoration: field('New password'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirm,
            obscureText: !_show,
            autofillHints: const [AutofillHints.newPassword],
            decoration: field('Confirm new password'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your new password needs',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  for (final (text, ok) in rules)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Semantics(
                        label: '$text: ${ok ? 'done' : 'not yet'}',
                        excludeSemantics: true,
                        child: Row(
                          children: [
                            Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
                                size: 20,
                                color: ok
                                    ? const Color(0xFF1B6B35)
                                    : (_tried ? AppColors.error : AppColors.inkMuted)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(text)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Change password'),
          ),
        ],
      ),
    );
  }
}
