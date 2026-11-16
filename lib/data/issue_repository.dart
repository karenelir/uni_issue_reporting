import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/issue.dart';
import '../models/report_draft.dart';
import 'campus_places.dart';
import 'exceptions.dart';
import 'seed_data.dart';

/// Stores issues and enforces the business rules on every action, so access
/// is checked by the system itself and not only by hiding controls (NFR9).
///
/// Data is kept on the device. Swap this class for a remote implementation
/// with the same methods to share issues between devices.
class IssueRepository {
  IssueRepository(this._prefs, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  static const _storageKey = 'issues_v1';

  final SharedPreferences _prefs;
  final DateTime Function() _now;
  final _uuid = const Uuid();
  final List<Issue> _issues = [];

  /// Loads stored issues, seeding sample data on first launch.
  Future<void> load({bool seedIfEmpty = true}) async {
    _issues.clear();
    final raw = _prefs.getString(_storageKey);
    if (raw == null) {
      if (seedIfEmpty) {
        _issues.addAll(buildSeedIssues(_now()));
        await _persist();
      }
      return;
    }
    try {
      final decoded = jsonDecode(raw) as List;
      _issues.addAll(decoded.map((e) => Issue.fromJson(e as Map<String, dynamic>)));
    } on FormatException {
      // Corrupt data must not crash the app (NFR7); start from an empty list.
      _issues.clear();
    }
  }

  /// Replaces all data with the sample issues (used from the demo menu).
  Future<void> resetToSampleData() async {
    _issues
      ..clear()
      ..addAll(buildSeedIssues(_now()));
    await _persist();
  }

  /// Issues the [viewer] may see. Students never see hidden reports (FR24).
  List<Issue> issuesFor(AppUser? viewer) {
    if (viewer == null) return const [];
    return _issues.where((i) => viewer.isStaff || !i.hidden).toList();
  }

  Issue? findById(String id) {
    for (final issue in _issues) {
      if (issue.id == id) return issue;
    }
    return null;
  }

  /// Creates a report with the status "Reported" (FR3, FR5, FR7).
  Future<Issue> createIssue(AppUser? actor, ReportDraft draft) async {
    _requireStudent(actor, 'Only students can report issues.');
    final errors = draft.validate();
    if (errors.isNotEmpty) throw ValidationException(errors);

    final issue = Issue(
      id: _uuid.v4(),
      title: draft.title.trim(),
      description: draft.description.trim(),
      category: draft.category!,
      location: draft.location.trim(),
      reporterId: actor!.id,
      createdAt: _now(),
      photoPaths: List.of(draft.photoPaths),
      urgent: draft.urgent,
    );
    _issues.add(issue);
    try {
      await _persist();
    } catch (_) {
      _issues.remove(issue);
      throw const SaveFailedException(
          'Your report was not sent. Your text is still here, try again.');
    }
    return issue;
  }

  /// Adds one vote per student per issue (FR10, NFR11).
  ///
  /// The check and the insert run synchronously before any await, so rapid
  /// repeated taps can never add more than one vote.
  Future<void> vote(AppUser? actor, String issueId) async {
    _requireStudent(actor, 'Only students can vote on issues.');
    final issue = _requireVisible(actor!, issueId);
    if (!issue.voterIds.add(actor.id)) throw const AlreadyVotedException();
    try {
      await _persist();
    } catch (_) {
      issue.voterIds.remove(actor.id);
      throw const SaveFailedException('Your vote was not saved. Try again.');
    }
  }

  /// Takes back the student's own vote, so a mistaken tap can be undone
  /// (error recovery: allow reconsideration of an action).
  Future<void> removeVote(AppUser? actor, String issueId) async {
    _requireStudent(actor, 'Only students can vote on issues.');
    final issue = _requireVisible(actor!, issueId);
    if (!issue.voterIds.remove(actor.id)) return;
    try {
      await _persist();
    } catch (_) {
      issue.voterIds.add(actor.id);
      throw const SaveFailedException('Your vote was not removed. Try again.');
    }
  }

  /// Moves an issue to the next status in the sequence (FR13, FR15), with
  /// an optional note that students see in the progress timeline.
  Future<IssueStatus> advanceStatus(AppUser? actor, String issueId, {String? note}) async {
    _requireStaff(actor, 'Only staff can change the status of an issue.');
    final issue = _requireVisible(actor!, issueId);
    final next = issue.status.next;
    if (next == null) {
      throw const PermissionDeniedException('This issue is already resolved.');
    }
    final trimmed = note?.trim();
    final change = StatusChange(
      status: next,
      changedAt: _now(),
      note: trimmed == null || trimmed.isEmpty ? null : trimmed,
    );
    issue.history.add(change);
    try {
      await _persist();
    } catch (_) {
      issue.history.remove(change);
      throw const SaveFailedException('The status was not saved. Try again.');
    }
    return next;
  }

  /// Hides or shows a report that breaks the content rules (FR24).
  Future<void> setHidden(AppUser? actor, String issueId, bool hidden) async {
    _requireStaff(actor, 'Only staff can hide reports.');
    final issue = _requireVisible(actor!, issueId);
    final previous = issue.hidden;
    issue.hidden = hidden;
    try {
      await _persist();
    } catch (_) {
      issue.hidden = previous;
      throw const SaveFailedException('The change was not saved. Try again.');
    }
  }

  /// Open issues whose titles share words with [title] (FR20).
  List<Issue> findSimilar(AppUser? viewer, String title, {int limit = 3}) {
    final words = _significantWords(title);
    if (words.isEmpty) return const [];
    final scored = <(Issue, int)>[];
    for (final issue in issuesFor(viewer)) {
      if (issue.status == IssueStatus.resolved) continue;
      final shared = _significantWords(issue.title).intersection(words).length;
      if (shared > 0) scored.add((issue, shared));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).map((e) => e.$1).toList();
  }

  /// Open issues at the same building or area as [location], so a student
  /// can see what is already reported there before adding a duplicate.
  List<Issue> findAtPlace(AppUser? viewer, String location) {
    final place = placeOf(location).toLowerCase();
    if (place.isEmpty) return const [];
    return issuesFor(viewer)
        .where((i) =>
            i.status != IssueStatus.resolved && placeOf(i.location).toLowerCase() == place)
        .toList()
      ..sort((a, b) => b.votes.compareTo(a.votes));
  }

  static const _stopWords = {
    'the', 'a', 'an', 'in', 'on', 'at', 'of', 'is', 'and', 'to', 'for',
    'not', 'no', 'with', 'from', 'my', 'it', 'are', 'was',
  };

  Set<String> _significantWords(String text) => text
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.length > 2 && !_stopWords.contains(w))
      .toSet();

  void _requireStudent(AppUser? actor, String message) {
    if (actor == null) throw const NotSignedInException();
    if (!actor.isStudent) throw PermissionDeniedException(message);
  }

  void _requireStaff(AppUser? actor, String message) {
    if (actor == null) throw const NotSignedInException();
    if (!actor.isStaff) throw PermissionDeniedException(message);
  }

  Issue _requireVisible(AppUser actor, String issueId) {
    final issue = findById(issueId);
    if (issue == null || (issue.hidden && !actor.isStaff)) {
      throw const IssueNotFoundException();
    }
    return issue;
  }

  Future<void> _persist() async {
    final ok = await _prefs.setString(
        _storageKey, jsonEncode(_issues.map((i) => i.toJson()).toList()));
    if (!ok) throw const SaveFailedException('Could not save data.');
  }
}
