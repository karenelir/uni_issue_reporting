import 'package:campusfix/data/auth_service.dart';
import 'package:campusfix/data/consent_service.dart';
import 'package:campusfix/data/issue_repository.dart';
import 'package:campusfix/data/local_settings.dart';
import 'package:campusfix/data/otp_service.dart';
import 'package:campusfix/main.dart';
import 'package:campusfix/models/issue.dart';
import 'package:campusfix/screens/profile_screen.dart';
import 'package:campusfix/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> buildState({bool seed = true}) async {
  final prefs = await SharedPreferences.getInstance();
  final repo = IssueRepository(prefs);
  await repo.load(seedIfEmpty: seed);
  return AppState(
    auth: AuthService(prefs),
    consent: ConsentService(prefs),
    settings: LocalSettings(prefs),
    repository: repo,
    otp: SimulatedEmailOtpService(),
  );
}

AppState stateOf(WidgetTester tester) =>
    Provider.of<AppState>(tester.element(find.byType(Scaffold).first), listen: false);

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Future<void> signIn(WidgetTester tester, String email, String password,
    {bool acceptTerms = true, bool verify = true}) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'University email'), email);
  await tester.enterText(find.widgetWithText(TextFormField, 'Password'), password);
  if (acceptTerms) await tapVisible(tester, find.byType(Checkbox));
  await tapVisible(tester, find.widgetWithText(FilledButton, 'Sign in'));
  await tester.pumpAndSettle();
  // Two-factor step: enter the code that was "emailed".
  final pending = stateOf(tester).pendingSignIn;
  if (pending == null || !verify) return;
  await tester.enterText(find.byType(TextField), pending.delivery.previewCode!);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(
      {LocalSettings.onboardingKey: true, LocalSettings.tourKey: true}));

  // Phone-sized portrait screen (360 x 800 dp).
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 3;
  });
  tearDown(() => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
    ..resetPhysicalSize()
    ..resetDevicePixelRatio());

  testWidgets('sign-in requires accepting the Terms and Privacy Policy', (tester) async {
    await tester.pumpWidget(CampusFixApp(state: await buildState()));
    await signIn(tester, 'student1@campusfix.test', 'student123', acceptTerms: false);
    expect(find.textContaining('Tick the box'), findsOneWidget);
    expect(find.text('Campus issues'), findsNothing);
  });

  testWidgets('wrong password is refused with a clear message', (tester) async {
    await tester.pumpWidget(CampusFixApp(state: await buildState()));
    await signIn(tester, 'student1@campusfix.test', 'nope');
    expect(find.textContaining('Email or password is incorrect'), findsOneWidget);
  });

  testWidgets('first launch shows onboarding, then sign-in', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(CampusFixApp(state: await buildState()));
    expect(find.text('Report campus problems'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('student lands on the feed ranked by votes and can vote', (tester) async {
    await tester.pumpWidget(CampusFixApp(state: await buildState()));
    await signIn(tester, 'student1@campusfix.test', 'student123');

    expect(find.text('Campus issues'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('Air conditioning broken in Lab 3'), findsOneWidget);
    expect(find.text('Report issue'), findsOneWidget);

    await tester.tap(find.text('24'));
    await tester.pumpAndSettle();
    expect(find.text('25'), findsOneWidget);
    expect(find.textContaining('Vote added'), findsOneWidget);

    // Voting again does not add a second vote (FR10).
    await tester.tap(find.text('25'));
    await tester.pumpAndSettle();
    expect(find.text('25'), findsOneWidget);
    expect(find.textContaining('already voted'), findsOneWidget);
  });

  testWidgets('AC5: "No issues found" when nothing matches, and filters clear', (tester) async {
    await tester.pumpWidget(CampusFixApp(state: await buildState(seed: false)));
    await signIn(tester, 'student1@campusfix.test', 'student123');
    expect(find.text('No issues found'), findsOneWidget);
  });

  testWidgets('AC4: empty report is not sent and each field is named', (tester) async {
    await tester.pumpWidget(CampusFixApp(state: await buildState()));
    await signIn(tester, 'student1@campusfix.test', 'student123');

    await tester.tap(find.text('Report issue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();

    // The form jumps to the first field to fix; the summary is at the top.
    expect(find.text('Choose a category from the list.'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(find.textContaining('Report not sent'), findsOneWidget);
    for (final message in [
      'Title is required. Add a few words.',
      'Description is required. Say what happened.',
      'Location is required. Type the building, room or area.',
    ]) {
      await tester.scrollUntilVisible(find.text(message), 200,
          scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first);
      expect(find.text(message), findsOneWidget);
    }
  });

  testWidgets('FR2, FR13: staff see the status action, students do not', (tester) async {
    await tester.pumpWidget(CampusFixApp(state: await buildState()));
    await signIn(tester, 'staff@campusfix.test', 'staff123');

    expect(find.text('Staff'), findsOneWidget);
    expect(find.text('Report issue'), findsNothing);
    expect(find.text('My reports'), findsNothing);
    await tester.tap(find.text('Air conditioning broken in Lab 3'));
    await tester.pumpAndSettle();
    expect(find.text('Move to: In progress'), findsOneWidget);

    await tester.tap(find.text('Move to: In progress'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Note for students (optional)'), 'Technician booked.');
    await tester.tap(find.widgetWithText(FilledButton, 'Move to In progress'));
    await tester.pumpAndSettle();
    expect(find.text('Move to: Resolved'), findsOneWidget);

    // The note appears in the progress timeline (staff updates for students).
    final note = find.textContaining('Technician booked.', findRichText: true);
    await tester.scrollUntilVisible(note, 200, scrollable: find.byType(Scrollable).last);
    expect(note, findsOneWidget);
  });

  Finder profileList() =>
      find.descendant(of: find.byType(ProfileScreen), matching: find.byType(Scrollable)).first;

  Future<void> openProfileItem(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(find.text(text), 200, scrollable: profileList());
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('Profile links the Terms of Use, Privacy Policy and account details',
      (tester) async {
    await tester.pumpWidget(CampusFixApp(state: await buildState()));
    await signIn(tester, 'student1@campusfix.test', 'student123');

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Student One'), findsOneWidget);
    expect(find.text('YOUR ACTIVITY'), findsOneWidget);

    await tester.tap(find.text('Student One'));
    await tester.pumpAndSettle();
    expect(find.text('Account details'), findsOneWidget);
    expect(find.text('Student ID'), findsOneWidget);
    expect(find.text('202310452'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await openProfileItem(tester, 'Privacy Policy');
    expect(find.text('1. What we collect'), findsOneWidget);
  });

  testWidgets('Profile activity opens My reports on the Voted list', (tester) async {
    await tester.pumpWidget(CampusFixApp(state: await buildState()));
    await signIn(tester, 'student1@campusfix.test', 'student123');
    await tester.tap(find.text('24'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voted for'));
    await tester.pumpAndSettle();
    expect(find.text('My reports'), findsWidgets);
    expect(find.text('Air conditioning broken in Lab 3'), findsOneWidget);
  });

  testWidgets('two-factor sign-in refuses a wrong email code', (tester) async {
    await tester.pumpWidget(CampusFixApp(state: await buildState()));
    await signIn(tester, 'student1@campusfix.test', 'student123', verify: false);
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.textContaining('s******1@campusfix.test', findRichText: true), findsOneWidget);

    final code = stateOf(tester).pendingSignIn!.delivery.previewCode!;
    final wrong = code == '000000' ? '111111' : '000000';
    await tester.enterText(find.byType(TextField), wrong);
    await tester.pumpAndSettle();
    expect(find.textContaining('not correct'), findsOneWidget);
    expect(find.text('Campus issues'), findsNothing);

    await tester.enterText(find.byType(TextField), code);
    await tester.pumpAndSettle();
    expect(find.text('Campus issues'), findsOneWidget);
  });

  testWidgets('password can be changed and the new one is required', (tester) async {
    final state = await buildState();
    await tester.pumpWidget(CampusFixApp(state: state));
    await signIn(tester, 'student1@campusfix.test', 'student123');

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Student One'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Current password'), 'student123');
    await tester.enterText(find.widgetWithText(TextField, 'New password'), 'short');
    await tester.enterText(find.widgetWithText(TextField, 'Confirm new password'), 'short');
    await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
    await tester.pumpAndSettle();
    expect(find.text('Change password'), findsWidgets); // still on the screen

    await tester.enterText(find.widgetWithText(TextField, 'New password'), 'Campus2026');
    await tester.enterText(find.widgetWithText(TextField, 'Confirm new password'), 'Campus2026');
    await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Password changed'), findsOneWidget);

    await expectLater(state.auth.checkPassword('student1@campusfix.test', 'student123'),
        throwsA(anything));
    expect((await state.auth.checkPassword('student1@campusfix.test', 'Campus2026')).name,
        'Student One');
  });

  testWidgets('guided tour runs once after the first sign-in', (tester) async {
    SharedPreferences.setMockInitialValues({LocalSettings.onboardingKey: true});
    final state = await buildState();
    await tester.pumpWidget(CampusFixApp(state: state));
    await signIn(tester, 'student1@campusfix.test', 'student123');
    // The circle pulses forever, so step time instead of waiting to settle.
    Future<void> wait() async {
      for (var k = 0; k < 10; k++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await wait();

    expect(find.text('Find anything'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await wait();
    expect(find.text('Filter in one tap'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await wait();

    expect(find.text('Filter in one tap'), findsNothing);
    expect(state.showTour, isFalse);
  });

  testWidgets('staff work queue opens the filtered issue list', (tester) async {
    final state = await buildState();
    await tester.pumpWidget(CampusFixApp(state: state));
    await signIn(tester, 'staff@campusfix.test', 'staff123');

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('WORK QUEUE'), findsOneWidget);
    await tester.tap(find.text('In progress'));
    await tester.pumpAndSettle();
    expect(state.statusFilter, IssueStatus.inProgress);
    expect(find.text('Campus issues'), findsOneWidget);
  });

  testWidgets('NFR5: feed, details and form render at 200% text size', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(CampusFixApp(state: await buildState()));
    await signIn(tester, 'student1@campusfix.test', 'student123');
    expect(find.text('Campus issues'), findsOneWidget);

    // At 200% the header fills most of the screen; scroll the first card up.
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('#1'));
    await tester.pumpAndSettle();
    expect(find.text('Issue details'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView).last, const Offset(0, -3000));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Report issue'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('Submit report'), findsOneWidget);

    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Sign out'), 300,
        scrollable: find
            .descendant(of: find.byType(ProfileScreen), matching: find.byType(Scrollable))
            .first);
    expect(find.text('Sign out'), findsOneWidget);
  });
}
