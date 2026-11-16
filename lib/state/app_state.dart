import 'package:flutter/foundation.dart';

import '../data/auth_service.dart';
import '../data/consent_service.dart';
import '../data/exceptions.dart';
import '../data/issue_repository.dart';
import '../data/local_settings.dart';
import '../data/otp_service.dart';
import '../models/app_user.dart';
import '../models/issue.dart';
import '../models/report_draft.dart';

enum SortOrder {
  mostVotes('Most votes'),
  newest('Newest');

  const SortOrder(this.label);

  final String label;
}

/// App-wide state: the signed-in user, feed filters and the issue actions.
/// Screens listen to it and call its methods; the rules themselves are
/// enforced by [IssueRepository].
class AppState extends ChangeNotifier {
  AppState({
    required this.auth,
    required this.consent,
    required this.settings,
    required this.repository,
    required this.otp,
  }) : _user = consent.hasAcceptedCurrent ? auth.restoreSession() : null;

  final AuthService auth;
  final ConsentService consent;
  final LocalSettings settings;
  final IssueRepository repository;
  final EmailOtpService otp;

  bool get showOnboarding => !settings.onboardingSeen;

  Future<void> finishOnboarding() async {
    await settings.markOnboardingSeen();
    notifyListeners();
  }

  AppUser? _user;
  AppUser? get user => _user;

  IssueCategory? categoryFilter;
  IssueStatus? statusFilter;
  String searchQuery = '';
  SortOrder sortOrder = SortOrder.mostVotes;

  bool get hasActiveFilters =>
      categoryFilter != null || statusFilter != null || searchQuery.trim().isNotEmpty;

  /// A sign-in waiting for the email code (two-factor authentication).
  ({AppUser user, OtpDelivery delivery})? _pending;
  ({AppUser user, OtpDelivery delivery})? get pendingSignIn => _pending;

  /// First sign-in step: checks the password, then emails a code. The Terms
  /// of Use and Privacy Policy must have been accepted, now or earlier.
  Future<void> signIn(String email, String password, {required bool acceptedTerms}) async {
    if (!acceptedTerms && !consent.hasAcceptedCurrent) {
      throw const ConsentRequiredException();
    }
    final user = await auth.checkPassword(email, password);
    final delivery = await otp.sendCode(user.email);
    _pending = (user: user, delivery: delivery);
    notifyListeners();
  }

  /// Second sign-in step: the code from the email starts the session.
  Future<void> verifySignInCode(String code) async {
    final pending = _pending;
    if (pending == null) throw const VerificationException('Sign in again to get a new code.');
    await otp.verifyCode(pending.user.email, code);
    if (!consent.hasAcceptedCurrent) await consent.accept();
    await auth.startSession(pending.user);
    _pending = null;
    _user = pending.user;
    clearFilters(notify: false);
    notifyListeners();
  }

  Future<void> resendSignInCode() async {
    final pending = _pending;
    if (pending == null) return;
    _pending = (user: pending.user, delivery: await otp.sendCode(pending.user.email));
    notifyListeners();
  }

  void cancelSignIn() {
    _pending = null;
    notifyListeners();
  }

  Future<void> changePassword(String current, String next) async {
    final u = _user;
    if (u == null) throw const NotSignedInException();
    await auth.changePassword(u, current, next);
  }

  /// The guided tour of the main screen runs once, after the first sign-in,
  /// and again when asked for from the Profile tab.
  bool get showTour => !settings.tourSeen;

  Future<void> finishTour() async {
    await settings.setTourSeen(true);
    notifyListeners();
  }

  Future<void> replayTour() async {
    await settings.setTourSeen(false);
    notifyListeners();
  }

  Future<void> signOut() async {
    await auth.signOut();
    _user = null;
    notifyListeners();
  }

  /// Withdraws consent and signs out; the user must accept again to use the app.
  Future<void> withdrawConsent() async {
    await consent.withdraw();
    await signOut();
  }

  /// Re-reads stored data so the latest status is shown (FR14).
  Future<void> refresh() async {
    await repository.load();
    notifyListeners();
  }

  Future<void> resetSampleData() async {
    await repository.resetToSampleData();
    notifyListeners();
  }

  void setCategoryFilter(IssueCategory? category) {
    categoryFilter = category;
    notifyListeners();
  }

  void setStatusFilter(IssueStatus? status) {
    statusFilter = status;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    searchQuery = query;
    notifyListeners();
  }

  void setSortOrder(SortOrder order) {
    sortOrder = order;
    notifyListeners();
  }

  void clearFilters({bool notify = true}) {
    categoryFilter = null;
    statusFilter = null;
    searchQuery = '';
    if (notify) notifyListeners();
  }

  /// The main feed: every visible issue, filtered (FR17) and ranked by votes
  /// with the highest first unless "Newest" is chosen (FR8, FR18).
  List<Issue> get feed {
    final query = searchQuery.trim().toLowerCase();
    final issues = repository.issuesFor(_user).where((i) {
      if (categoryFilter != null && i.category != categoryFilter) return false;
      if (statusFilter != null && i.status != statusFilter) return false;
      if (query.isNotEmpty &&
          !i.title.toLowerCase().contains(query) &&
          !i.location.toLowerCase().contains(query) &&
          !i.description.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
    return sortIssues(issues, sortOrder);
  }

  /// Issues the current student reported or voted for (FR16).
  List<Issue> get myIssues {
    final u = _user;
    if (u == null) return const [];
    return repository
        .issuesFor(u)
        .where((i) => i.reporterId == u.id || i.hasVoted(u.id))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Issue? issueById(String id) {
    final issue = repository.findById(id);
    if (issue == null) return null;
    if (issue.hidden && !(_user?.isStaff ?? false)) return null;
    return issue;
  }

  bool isMine(Issue issue) => _user != null && issue.reporterId == _user!.id;

  bool hasVoted(Issue issue) => _user != null && issue.hasVoted(_user!.id);

  List<Issue> similarIssues(String title) => repository.findSimilar(_user, title);

  List<Issue> issuesAtPlace(String location) => repository.findAtPlace(_user, location);

  Future<Issue> submitReport(ReportDraft draft) async {
    final issue = await repository.createIssue(_user, draft);
    notifyListeners();
    return issue;
  }

  Future<void> vote(String issueId) => _run(() => repository.vote(_user, issueId));

  Future<void> removeVote(String issueId) =>
      _run(() => repository.removeVote(_user, issueId));

  Future<IssueStatus> advanceStatus(String issueId, {String? note}) =>
      _run(() => repository.advanceStatus(_user, issueId, note: note));

  Future<void> setHidden(String issueId, bool hidden) =>
      _run(() => repository.setHidden(_user, issueId, hidden));

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } finally {
      notifyListeners();
    }
  }
}

List<Issue> sortIssues(List<Issue> issues, SortOrder order) {
  switch (order) {
    case SortOrder.mostVotes:
      issues.sort((a, b) {
        final byVotes = b.votes.compareTo(a.votes);
        return byVotes != 0 ? byVotes : b.createdAt.compareTo(a.createdAt);
      });
    case SortOrder.newest:
      issues.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
  return issues;
}
