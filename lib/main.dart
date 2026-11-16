import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/auth_service.dart';
import 'data/consent_service.dart';
import 'data/issue_repository.dart';
import 'data/local_settings.dart';
import 'data/otp_service.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/verify_code_screen.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait only, on both Android and iOS (NFR12).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final prefs = await SharedPreferences.getInstance();
  final repository = IssueRepository(prefs);
  await repository.load();

  runApp(CampusFixApp(
    state: AppState(
      auth: AuthService(prefs),
      consent: ConsentService(prefs),
      settings: LocalSettings(prefs),
      repository: repository,
      otp: EmailOtpService.fromEnvironment(),
    ),
  ));
}

class CampusFixApp extends StatefulWidget {
  const CampusFixApp({super.key, required this.state});

  final AppState state;

  @override
  State<CampusFixApp> createState() => _CampusFixAppState();
}

class _CampusFixAppState extends State<CampusFixApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final _clearMessages = _ClearMessagesObserver(_messengerKey);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.state,
      child: MaterialApp(
        title: 'CampusFix',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        scaffoldMessengerKey: _messengerKey,
        navigatorObservers: [_clearMessages],
        // Sign-in is required before anything else (FR1); the account
        // decides what is shown afterwards (FR2).
        home: Selector<AppState, (bool, bool, bool)>(
          selector: (_, s) => (s.showOnboarding, s.user != null, s.pendingSignIn != null),
          builder: (context, gate, _) => switch (gate) {
            (true, _, _) => OnboardingScreen(onDone: context.read<AppState>().finishOnboarding),
            (_, true, _) => const HomeShell(),
            (_, _, true) => const VerifyCodeScreen(),
            _ => const LoginScreen(),
          },
        ),
      ),
    );
  }
}

/// Clears bottom messages when the screen changes, so feedback about one
/// screen never covers controls on the next.
class _ClearMessagesObserver extends NavigatorObserver {
  _ClearMessagesObserver(this._messengerKey);

  final GlobalKey<ScaffoldMessengerState> _messengerKey;

  void _clear() => _messengerKey.currentState?.clearSnackBars();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _clear();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _clear();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _clear();
}
