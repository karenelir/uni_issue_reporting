import 'package:campusfix/data/exceptions.dart';
import 'package:campusfix/data/issue_repository.dart';
import 'package:campusfix/data/test_accounts.dart';
import 'package:campusfix/models/issue.dart';
import 'package:campusfix/models/report_draft.dart';
import 'package:campusfix/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final student = testAccounts[0].user;
final otherStudent = testAccounts[1].user;
final staff = testAccounts[2].user;

ReportDraft validDraft({String title = 'Broken chair in Room 101'}) => ReportDraft(
      title: title,
      description: 'The chair in the front row has a broken leg.',
      category: IssueCategory.facilities,
      location: 'Building A, Room 101',
    );

void main() {
  late IssueRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = IssueRepository(await SharedPreferences.getInstance());
    await repo.load(seedIfEmpty: false);
  });

  group('AC1 / FR3, FR7: successful issue submission', () {
    test('a valid report is created with status Reported', () async {
      final issue = await repo.createIssue(student, validDraft());
      expect(issue.status, IssueStatus.reported);
      expect(issue.votes, 0);
      expect(repo.issuesFor(otherStudent).map((i) => i.id), contains(issue.id));
    });

    test('reports survive an app restart', () async {
      final issue = await repo.createIssue(student, validDraft());
      final reloaded = IssueRepository(await SharedPreferences.getInstance());
      await reloaded.load();
      expect(reloaded.findById(issue.id)?.title, issue.title);
    });

    test('photos are optional and limited to three (FR19)', () async {
      final withTwo = validDraft()..photoPaths.addAll(['a.jpg', 'b.jpg']);
      expect((await repo.createIssue(student, withTwo)).photoPaths, hasLength(2));
      final withFour = validDraft()..photoPaths.addAll(['a', 'b', 'c', 'd']);
      expect(() => repo.createIssue(student, withFour), throwsA(isA<ValidationException>()));
    });
  });

  group('AC4 / FR5: invalid input', () {
    for (final field in [
      ReportField.title,
      ReportField.category,
      ReportField.location,
      ReportField.description,
    ]) {
      test('missing ${field.label} is refused and named', () async {
        final draft = validDraft();
        switch (field) {
          case ReportField.title:
            draft.title = '  ';
          case ReportField.category:
            draft.category = null;
          case ReportField.location:
            draft.location = '';
          case ReportField.description:
            draft.description = '';
          case ReportField.photos:
            break;
        }
        await expectLater(
          repo.createIssue(student, draft),
          throwsA(isA<ValidationException>()
              .having((e) => e.errors.keys, 'fields', [field])),
        );
        expect(repo.issuesFor(student), isEmpty);
      });
    }

    test('all fields empty names all four fields', () {
      final errors = ReportDraft().validate();
      expect(errors.keys, containsAll([
        ReportField.title,
        ReportField.category,
        ReportField.location,
        ReportField.description,
      ]));
      expect(errors[ReportField.title], 'Title is required. Add a few words.');
    });
  });

  group('AC2 / FR10, NFR11: voting', () {
    test('a student can vote once; a second vote is refused', () async {
      final issue = await repo.createIssue(student, validDraft());
      await repo.vote(otherStudent, issue.id);
      expect(issue.votes, 1);
      await expectLater(repo.vote(otherStudent, issue.id), throwsA(isA<AlreadyVotedException>()));
      expect(issue.votes, 1);
    });

    test('ten quick taps add exactly one vote', () async {
      final issue = await repo.createIssue(student, validDraft());
      final results = await Future.wait(List.generate(
        10,
        (_) => repo.vote(otherStudent, issue.id).then((_) => true, onError: (_) => false),
      ));
      expect(results.where((ok) => ok), hasLength(1));
      expect(issue.votes, 1);
    });

    test('a vote can be undone', () async {
      final issue = await repo.createIssue(student, validDraft());
      await repo.vote(otherStudent, issue.id);
      await repo.removeVote(otherStudent, issue.id);
      expect(issue.votes, 0);
    });
  });

  group('FR8, FR18: ranking', () {
    test('the issue with most votes is first, and moves up after votes', () async {
      final a = await repo.createIssue(student, validDraft(title: 'First issue here'));
      final b = await repo.createIssue(student, validDraft(title: 'Second issue here'));
      await repo.vote(student, a.id);
      expect(sortIssues(repo.issuesFor(student), SortOrder.mostVotes).first.id, a.id);
      await repo.vote(student, b.id);
      await repo.vote(otherStudent, b.id);
      expect(sortIssues(repo.issuesFor(student), SortOrder.mostVotes).first.id, b.id);
    });
  });

  group('AC3 / FR12, FR13, FR15: status tracking', () {
    test('staff move the status one step at a time, with a timestamp', () async {
      final issue = await repo.createIssue(student, validDraft());
      for (final expected in [
        IssueStatus.underReview,
        IssueStatus.inProgress,
        IssueStatus.resolved,
      ]) {
        expect(await repo.advanceStatus(staff, issue.id), expected);
      }
      expect(issue.history.map((h) => h.status), IssueStatus.values);
      await expectLater(
          repo.advanceStatus(staff, issue.id), throwsA(isA<PermissionDeniedException>()));
    });

    test('a student cannot change a status (NFR9)', () async {
      final issue = await repo.createIssue(student, validDraft());
      await expectLater(
          repo.advanceStatus(student, issue.id), throwsA(isA<PermissionDeniedException>()));
      expect(issue.status, IssueStatus.reported);
    });
  });

  group('FR1, NFR9: signed-out and wrong-role actions are refused', () {
    test('signed out', () async {
      final issue = await repo.createIssue(student, validDraft());
      await expectLater(repo.createIssue(null, validDraft()), throwsA(isA<NotSignedInException>()));
      await expectLater(repo.vote(null, issue.id), throwsA(isA<NotSignedInException>()));
      await expectLater(repo.advanceStatus(null, issue.id), throwsA(isA<NotSignedInException>()));
    });

    test('staff cannot report or vote', () async {
      final issue = await repo.createIssue(student, validDraft());
      await expectLater(
          repo.createIssue(staff, validDraft()), throwsA(isA<PermissionDeniedException>()));
      await expectLater(repo.vote(staff, issue.id), throwsA(isA<PermissionDeniedException>()));
    });
  });

  group('FR24: hiding reports', () {
    test('hidden reports disappear for students only', () async {
      final issue = await repo.createIssue(student, validDraft());
      await repo.setHidden(staff, issue.id, true);
      expect(repo.issuesFor(otherStudent), isEmpty);
      expect(repo.issuesFor(staff), hasLength(1));
      await expectLater(
          repo.setHidden(student, issue.id, false), throwsA(isA<PermissionDeniedException>()));
    });
  });

  test('urgent flag and staff notes are saved and reloaded', () async {
    final draft = validDraft()..urgent = true;
    final issue = await repo.createIssue(student, draft);
    await repo.advanceStatus(staff, issue.id, note: '  Technician booked.  ');
    await repo.advanceStatus(staff, issue.id, note: '   ');

    final reloaded = IssueRepository(await SharedPreferences.getInstance());
    await reloaded.load();
    final saved = reloaded.findById(issue.id)!;
    expect(saved.urgent, isTrue);
    expect(saved.history[1].note, 'Technician booked.');
    expect(saved.history[2].note, isNull);
  });

  test('open issues are found by building', () async {
    final a = validDraft(title: 'Broken chair in Lab 3')..location = 'Building B, Lab 3';
    final b = validDraft(title: 'Lights flicker')..location = 'Building B';
    final c = validDraft(title: 'Door stuck')..location = 'Library';
    await repo.createIssue(student, a);
    final resolved = await repo.createIssue(student, b);
    await repo.createIssue(student, c);
    expect(repo.findAtPlace(student, 'building b'), hasLength(2));

    for (var i = 0; i < 3; i++) {
      await repo.advanceStatus(staff, resolved.id);
    }
    expect(repo.findAtPlace(student, 'Building B, room 1'), hasLength(1));
  });

  test('FR20: similar titles are suggested', () async {
    await repo.createIssue(student, validDraft(title: 'Projector broken in Room 204'));
    expect(repo.findSimilar(student, 'projector not working'), hasLength(1));
    expect(repo.findSimilar(student, 'wifi slow'), isEmpty);
  });
}
