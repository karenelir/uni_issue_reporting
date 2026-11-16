import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/spotlight_tour.dart';
import 'feed_screen.dart';
import 'my_issues_screen.dart';
import 'profile_screen.dart';
import 'report_form_screen.dart';

/// Main navigation after sign-in. Students get Issues, My reports and
/// Profile, plus the Report issue button; staff get Issues and Profile only,
/// since they do not report or vote (FR2).
///
/// On the first sign-in (and when replayed from Profile) a guided tour
/// circles each control with a short explanation.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  /// Which list My reports opens on; changing it rebuilds that tab.
  int _myReportsTab = 0;
  int _myReportsVersion = 0;

  bool _touring = false;

  void _openReportForm() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const ReportFormScreen(),
      fullscreenDialog: true,
    ));
  }

  Future<void> _runTour(bool isStaff) async {
    setState(() => _tab = 0);
    // Let the screen settle after sign-in or the intro pages.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    await showSpotlightTour(context, isStaff ? _staffSteps : _studentSteps);
    if (!mounted) return;
    await context.read<AppState>().finishTour();
    _touring = false;
  }

  static final _studentSteps = [
    TourStep(
      target: TourKeys.search,
      icon: Icons.search,
      title: 'Find anything',
      text: 'Search any issue, room or building on campus.',
    ),
    TourStep(
      target: TourKeys.filters,
      icon: Icons.tune,
      title: 'Filter in one tap',
      text: 'Sort by votes or date, or show a single status or category.',
    ),
    TourStep(
      target: TourKeys.firstCard,
      icon: Icons.view_agenda_outlined,
      title: 'Every report at a glance',
      text: 'Category, place, age and status. Tap a card for the full story.',
    ),
    TourStep(
      target: TourKeys.firstVote,
      icon: Icons.arrow_upward_rounded,
      title: 'Same problem? Vote!',
      text: 'One tap adds your voice. The most voted issues rise to the top.',
    ),
    TourStep(
      target: TourKeys.report,
      icon: Icons.add_a_photo_outlined,
      title: 'Spotted a problem?',
      text: 'Report it in under two minutes, with a photo if you like.',
    ),
    TourStep(
      target: TourKeys.myReportsTab,
      icon: Icons.assignment_outlined,
      title: 'Your reports, tracked',
      text: 'Follow everything you reported or voted for, step by step.',
    ),
    TourStep(
      target: TourKeys.profileTab,
      icon: Icons.person_outline,
      title: 'You, and help',
      text: 'Your account, password, privacy, and this tour again anytime.',
    ),
  ];

  static final _staffSteps = [
    TourStep(
      target: TourKeys.search,
      icon: Icons.search,
      title: 'Find anything',
      text: 'Search any issue, room or building on campus.',
    ),
    TourStep(
      target: TourKeys.filters,
      icon: Icons.tune,
      title: 'Focus your queue',
      text: 'Show only new, in review or in progress issues.',
    ),
    TourStep(
      target: TourKeys.firstCard,
      icon: Icons.construction_outlined,
      title: 'Move issues forward',
      text: 'Open an issue to change its status and leave a note students will see.',
    ),
    TourStep(
      target: TourKeys.firstVote,
      icon: Icons.how_to_vote_outlined,
      title: 'Votes show impact',
      text: 'How many students are affected. Urgent issues are marked in red.',
    ),
    TourStep(
      target: TourKeys.profileTab,
      icon: Icons.inbox_outlined,
      title: 'Your work queue',
      text: 'New, in review and in progress counts, one tap away.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isStaff = context.select<AppState, bool>((s) => s.user?.isStaff ?? false);
    final showTour = context.select<AppState, bool>((s) => s.showTour);
    if (showTour && !_touring) {
      _touring = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _runTour(isStaff));
    }

    final pages = <Widget>[
      const FeedScreen(),
      if (!isStaff)
        MyIssuesScreen(
          key: ValueKey(_myReportsVersion),
          onReport: _openReportForm,
          initialTab: _myReportsTab,
        ),
      ProfileScreen(
        onOpenMyReports: (subTab) => setState(() {
          _myReportsTab = subTab;
          _myReportsVersion++;
          _tab = 1;
        }),
        onOpenIssues: () => setState(() => _tab = 0),
      ),
    ];
    final destinations = <NavigationDestination>[
      NavigationDestination(
        key: TourKeys.issuesTab,
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
        label: 'Issues',
      ),
      if (!isStaff)
        NavigationDestination(
          key: TourKeys.myReportsTab,
          icon: const Icon(Icons.assignment_outlined),
          selectedIcon: const Icon(Icons.assignment),
          label: 'My reports',
        ),
      NavigationDestination(
        key: TourKeys.profileTab,
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: 'Profile',
      ),
    ];
    final tab = _tab.clamp(0, pages.length - 1);
    final showReport = !isStaff && tab < 2;

    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      floatingActionButton: showReport
          ? FloatingActionButton.extended(
              key: TourKeys.report,
              onPressed: _openReportForm,
              icon: const Icon(Icons.add),
              label: const Text('Report issue'),
              tooltip: 'Report a new issue',
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: destinations,
      ),
    );
  }
}
