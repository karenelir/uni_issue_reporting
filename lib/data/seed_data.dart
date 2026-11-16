import '../models/issue.dart';

/// Sample issues matching the low-fidelity prototype. All names and numbers
/// are test data. Votes come from simulated student ids so the counts look
/// realistic; real students' votes are added on top.
List<Issue> buildSeedIssues(DateTime now) {
  Set<String> voters(int count) => {for (var i = 1; i <= count; i++) 'seed-voter-$i'};

  List<StatusChange> history(
          DateTime created, List<(IssueStatus, Duration, String?)> steps) =>
      [
        StatusChange(status: IssueStatus.reported, changedAt: created),
        for (final (status, after, note) in steps)
          StatusChange(status: status, changedAt: created.add(after), note: note),
      ];

  final acCreated = now.subtract(const Duration(days: 3));
  final wifiCreated = now.subtract(const Duration(days: 6));
  final cafeCreated = now.subtract(const Duration(days: 1, hours: 4));
  final portalCreated = now.subtract(const Duration(days: 2));
  final projectorCreated = now.subtract(const Duration(hours: 5));
  final restroomCreated = now.subtract(const Duration(days: 12));

  return [
    Issue(
      id: 'seed-ac-lab3',
      title: 'Air conditioning broken in Lab 3',
      description:
          'The air conditioning has been off since Monday. The room is too hot to hold lab sessions.',
      category: IssueCategory.facilities,
      location: 'Building B, Lab 3',
      reporterId: 'seed-reporter-1',
      createdAt: acCreated,
      voterIds: voters(24),
      history: history(acCreated, [
        (
          IssueStatus.underReview,
          const Duration(days: 1),
          'Facilities team informed. A technician will inspect the unit.',
        ),
      ]),
    ),
    Issue(
      id: 'seed-wifi-library',
      title: 'Wi-Fi drops in the library',
      description:
          'The Wi-Fi disconnects every few minutes on the 2nd floor, which makes it impossible to submit online quizzes.',
      category: IssueCategory.infrastructure,
      location: 'Library, 2nd floor',
      reporterId: 'seed-reporter-2',
      createdAt: wifiCreated,
      voterIds: voters(17),
      history: history(wifiCreated, [
        (IssueStatus.underReview, const Duration(days: 1), null),
        (
          IssueStatus.inProgress,
          const Duration(days: 3, hours: 2),
          'IT is replacing the access point on the 2nd floor.',
        ),
      ]),
    ),
    Issue(
      id: 'seed-cafeteria-reader',
      title: 'Cafeteria card reader offline',
      description: 'The student card reader at the main till has been offline since yesterday; only cash is accepted.',
      category: IssueCategory.facilities,
      location: 'Cafeteria',
      reporterId: 'seed-reporter-3',
      createdAt: cafeCreated,
      voterIds: voters(9),
    ),
    Issue(
      id: 'seed-portal-course',
      title: 'Portal shows the wrong course schedule',
      description: 'The student portal shows last semester\'s timetable for several engineering courses.',
      category: IssueCategory.academic,
      location: 'Online services, student portal',
      reporterId: 'seed-reporter-4',
      createdAt: portalCreated,
      voterIds: voters(6),
    ),
    Issue(
      id: 'seed-projector',
      title: 'Projector not working in Room 204',
      description: 'The projector turns on but shows no signal from the HDMI cable.',
      category: IssueCategory.infrastructure,
      location: 'Building A, Room 204',
      reporterId: 'seed-reporter-5',
      createdAt: projectorCreated,
      voterIds: voters(2),
    ),
    Issue(
      id: 'seed-restroom-tap',
      title: 'Leaking tap in ground floor restroom',
      description: 'The left tap keeps running and the floor is wet.',
      category: IssueCategory.facilities,
      location: 'Building C, ground floor restroom',
      reporterId: 'seed-reporter-6',
      createdAt: restroomCreated,
      voterIds: voters(11),
      urgent: true,
      history: history(restroomCreated, [
        (IssueStatus.underReview, const Duration(hours: 6), null),
        (IssueStatus.inProgress, const Duration(days: 2), 'Plumber scheduled.'),
        (IssueStatus.resolved, const Duration(days: 4), 'Tap washer replaced and floor dried.'),
      ]),
    ),
  ];
}
