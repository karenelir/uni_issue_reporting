import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/consent_service.dart';
import '../models/app_user.dart';
import '../models/issue.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/feedback.dart';
import '../widgets/format.dart';
import '../widgets/status_widgets.dart';
import 'account_details_screen.dart';
import 'legal_screen.dart';
import 'onboarding_screen.dart';

/// Profile tab, laid out like the account pages of common reporting apps:
/// who you are, your activity at a glance, then grouped settings, help,
/// privacy and sign out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.onOpenMyReports, required this.onOpenIssues});

  /// Opens the My reports tab on its Reported (0) or Voted (1) list.
  final ValueChanged<int> onOpenMyReports;

  /// Opens the Issues tab (after a filter was set).
  final VoidCallback onOpenIssues;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _ProfileHeader(user: user),
          const SizedBox(height: 12),
          if (user.isStaff)
            _StaffStats(state: state, onOpenIssues: onOpenIssues)
          else
            _StudentStats(state: state, onOpenMyReports: onOpenMyReports),
          _Section(
            title: 'Help and support',
            tiles: [
              _Tile(
                icon: Icons.slideshow_outlined,
                title: 'How CampusFix works',
                subtitle: 'Report, vote and follow issues',
                onTap: () => _replayIntro(context),
              ),
              _Tile(
                icon: Icons.timeline_rounded,
                title: 'What the statuses mean',
                onTap: () => showStatusHelp(context),
              ),
              _Tile(
                icon: Icons.support_agent_outlined,
                title: 'Contact support',
                subtitle: 'Problems with the app or your account',
                onTap: () => _showSupport(context),
              ),
              _Tile(
                icon: Icons.emergency_outlined,
                iconColor: AppColors.error,
                title: 'Emergencies and safety hazards',
                subtitle: 'Do not wait for the app',
                onTap: () => _showEmergency(context),
              ),
            ],
          ),
          _Section(
            title: 'Privacy and legal',
            tiles: [
              _Tile(
                icon: Icons.description_outlined,
                title: 'Terms of Use',
                onTap: () => _openLegal(context, LegalDocument.terms),
              ),
              _Tile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () => _openLegal(context, LegalDocument.privacy),
              ),
              _Tile(
                icon: Icons.verified_user_outlined,
                title: 'Your consent',
                subtitle: state.consent.acceptedAt == null
                    ? 'Version ${ConsentService.currentVersion}'
                    : 'Accepted ${dateTimeFormat.format(state.consent.acceptedAt!)} '
                        '(version ${ConsentService.currentVersion})',
              ),
              _Tile(
                icon: Icons.gpp_maybe_outlined,
                iconColor: AppColors.error,
                title: 'Withdraw consent',
                subtitle: 'Signs you out of CampusFix',
                onTap: () => _withdrawConsent(context),
              ),
            ],
          ),
          _Section(
            title: 'About',
            tiles: [
              _Tile(
                icon: Icons.info_outline,
                title: 'About CampusFix',
                subtitle: 'Version 1.0.0',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'CampusFix',
                  applicationVersion: '1.0.0',
                  applicationIcon: const Icon(Icons.handyman_rounded, color: AppColors.brand),
                  applicationLegalese: 'GIN528 Mobile Programming project, USEK.\n'
                      'Prototype using test accounts and sample data.',
                ),
              ),
              _Tile(
                icon: Icons.restart_alt,
                title: 'Reset sample data',
                subtitle: 'Demo only: restore the original issues',
                onTap: () => _resetData(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _signOut(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
          const SizedBox(height: 12),
          Text('Signed in as ${user.email}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.inkMuted)),
        ],
      ),
    );
  }

  /// Replays the intro pages, then the guided tour of the main screen.
  Future<void> _replayIntro(BuildContext context) async {
    final state = context.read<AppState>();
    final started = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (context) => OnboardingScreen(onDone: () => Navigator.pop(context, true)),
    ));
    if (started != true) return;
    onOpenIssues();
    await state.replayTour();
  }

    void _openLegal(BuildContext context, LegalDocument doc) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => LegalScreen(document: doc)));
  }

  void _showSupport(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Contact support', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.mail_outline),
                title: Text('support@campusfix.test'),
                subtitle: Text('Prototype address. Replies within 2 working days.'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.manage_accounts_outlined),
                title: Text('Account or password problems'),
                subtitle: Text('Contact the USEK IT department.'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.report_outlined),
                title: Text('A campus problem'),
                subtitle: Text('Use Report issue on the Issues tab instead.'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmergency(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.emergency_outlined, color: AppColors.error),
        title: const Text('Emergencies'),
        content: const Text(
          'CampusFix is not monitored around the clock. For fires, injuries, gas or '
          'electrical hazards, or anyone in danger, contact campus security or emergency '
          'services directly. You can report the problem in the app afterwards.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Understood')),
        ],
      ),
    );
  }

  Future<void> _resetData(BuildContext context) async {
    final ok = await confirmAction(
      context,
      title: 'Reset sample data?',
      message: 'All reports, votes and status changes made on this device will be '
          'replaced by the original sample issues. This cannot be undone.',
      confirmLabel: 'Reset data',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await context.read<AppState>().resetSampleData();
    if (context.mounted) showMessage(context, 'Sample data restored.');
  }

  Future<void> _withdrawConsent(BuildContext context) async {
    final ok = await confirmAction(
      context,
      title: 'Withdraw consent?',
      message: 'You will be signed out. To use CampusFix again you will need to accept '
          'the Terms of Use and Privacy Policy.',
      confirmLabel: 'Withdraw and sign out',
      destructive: true,
    );
    if (ok && context.mounted) await context.read<AppState>().withdrawConsent();
  }

  Future<void> _signOut(BuildContext context) async {
    final ok = await confirmAction(
      context,
      title: 'Sign out?',
      message: 'You will need your university email and password to sign in again.',
      confirmLabel: 'Sign out',
    );
    if (ok && context.mounted) await context.read<AppState>().signOut();
  }
}

String initialsOf(String name) =>
    name.split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const AccountDetailsScreen())),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.brand,
                child: Text(initialsOf(user.name),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                    Text(user.email, style: const TextStyle(color: AppColors.inkMuted)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(user.isStaff ? Icons.badge_outlined : Icons.school_outlined,
                              size: 16, color: scheme.onSecondaryContainer),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(user.isStaff ? 'Staff' : 'Student',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSecondaryContainer)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Your activity": tappable counts that open the matching list.
class _StudentStats extends StatelessWidget {
  const _StudentStats({required this.state, required this.onOpenMyReports});

  final AppState state;
  final ValueChanged<int> onOpenMyReports;

  @override
  Widget build(BuildContext context) {
    final mine = state.myIssues;
    final reported = mine.where(state.isMine).toList();
    final voted = mine.where((i) => !state.isMine(i)).length;
    final resolved = reported.where((i) => i.status == IssueStatus.resolved).length;
    return _StatsRow(
      title: 'Your activity',
      stats: [
        _Stat(value: reported.length, label: 'Reported', onTap: () => onOpenMyReports(0)),
        _Stat(value: voted, label: 'Voted for', onTap: () => onOpenMyReports(1)),
        _Stat(value: resolved, label: 'Resolved', onTap: () => onOpenMyReports(0)),
      ],
    );
  }
}

/// Staff see their work queue at a glance; each count opens the filtered list.
class _StaffStats extends StatelessWidget {
  const _StaffStats({required this.state, required this.onOpenIssues});

  final AppState state;
  final VoidCallback onOpenIssues;

  @override
  Widget build(BuildContext context) {
    final issues = state.repository.issuesFor(state.user);
    int count(IssueStatus s) => issues.where((i) => i.status == s).length;
    void open(IssueStatus s) {
      state.clearFilters(notify: false);
      state.setStatusFilter(s);
      onOpenIssues();
    }

    return _StatsRow(
      title: 'Work queue',
      stats: [
        _Stat(
            value: count(IssueStatus.reported),
            label: 'New',
            onTap: () => open(IssueStatus.reported)),
        _Stat(
            value: count(IssueStatus.underReview),
            label: 'In review',
            onTap: () => open(IssueStatus.underReview)),
        _Stat(
            value: count(IssueStatus.inProgress),
            label: 'In progress',
            onTap: () => open(IssueStatus.inProgress)),
      ],
    );
  }
}

class _Stat {
  const _Stat({required this.value, required this.label, required this.onTap});

  final int value;
  final String label;
  final VoidCallback onTap;
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.title, required this.stats});

  final String title;
  final List<_Stat> stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title),
        Card(
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) const VerticalDivider(width: 1, indent: 12, endIndent: 12),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: '${stats[i].label}: ${stats[i].value}. Show list.',
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: stats[i].onTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                          child: Column(
                            children: [
                              Text('${stats[i].value}',
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.brand)),
                              const SizedBox(height: 2),
                              Text(stats[i].label,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 13, color: AppColors.inkMuted)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.tiles});

  final String title;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const Divider(indent: 68),
                tiles[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Settings row with a tinted icon square, as in iOS / Android settings.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.iconColor = AppColors.brand,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minVerticalPadding: 12,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
      child: Semantics(
        header: true,
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 12.5,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
                color: AppColors.inkMuted)),
      ),
    );
  }
}
