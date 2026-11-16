/// Fixed list of categories (FR4).
enum IssueCategory {
  facilities('Facilities', 'Facilities'),
  academic('Academic services', 'Academic'),
  infrastructure('Infrastructure', 'Infra');

  const IssueCategory(this.label, this.shortLabel);

  final String label;
  final String shortLabel;
}

/// Status sequence: Reported -> Under review -> In progress -> Resolved (FR12).
enum IssueStatus {
  reported('Reported'),
  underReview('Under review'),
  inProgress('In progress'),
  resolved('Resolved');

  const IssueStatus(this.label);

  final String label;

  /// The only status a staff member may move to next, or null when resolved (FR13).
  IssueStatus? get next =>
      index < IssueStatus.values.length - 1 ? IssueStatus.values[index + 1] : null;
}

/// One entry in an issue's status history (FR15), with an optional public
/// note from staff explaining what is happening.
class StatusChange {
  const StatusChange({required this.status, required this.changedAt, this.note});

  final IssueStatus status;
  final DateTime changedAt;
  final String? note;

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'changedAt': changedAt.toIso8601String(),
        if (note != null) 'note': note,
      };

  factory StatusChange.fromJson(Map<String, dynamic> json) => StatusChange(
        status: IssueStatus.values.byName(json['status'] as String),
        changedAt: DateTime.parse(json['changedAt'] as String),
        note: json['note'] as String?,
      );
}

/// A report created by a student.
///
/// [reporterId] and [voterIds] are stored so the system can enforce one vote
/// per student and build "My issues", but they are never shown to other
/// students (NFR10).
class Issue {
  Issue({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    required this.reporterId,
    required this.createdAt,
    List<String>? photoPaths,
    Set<String>? voterIds,
    List<StatusChange>? history,
    this.hidden = false,
    this.urgent = false,
  })  : photoPaths = photoPaths ?? [],
        voterIds = voterIds ?? {},
        history = history ?? [StatusChange(status: IssueStatus.reported, changedAt: createdAt)];

  final String id;
  final String title;
  final String description;
  final IssueCategory category;
  final String location;
  final String reporterId;
  final DateTime createdAt;
  final List<String> photoPaths;
  final Set<String> voterIds;
  final List<StatusChange> history;

  /// Hidden by staff for breaking the content rules (FR24).
  bool hidden;

  /// Flagged by the reporter as a safety hazard or urgent. Votes show how
  /// many students are affected, not how serious a problem is (assumption
  /// A3), so this flag lets serious issues stand out even with few votes.
  final bool urgent;

  IssueStatus get status => history.last.status;

  /// The vote count always equals the number of distinct voters (NFR11).
  int get votes => voterIds.length;

  bool hasVoted(String userId) => voterIds.contains(userId);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category.name,
        'location': location,
        'reporterId': reporterId,
        'createdAt': createdAt.toIso8601String(),
        'photoPaths': photoPaths,
        'voterIds': voterIds.toList(),
        'history': history.map((h) => h.toJson()).toList(),
        'hidden': hidden,
        'urgent': urgent,
      };

  factory Issue.fromJson(Map<String, dynamic> json) => Issue(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        category: IssueCategory.values.byName(json['category'] as String),
        location: json['location'] as String,
        reporterId: json['reporterId'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        photoPaths: (json['photoPaths'] as List).cast<String>(),
        voterIds: (json['voterIds'] as List).cast<String>().toSet(),
        history: (json['history'] as List)
            .map((h) => StatusChange.fromJson(h as Map<String, dynamic>))
            .toList(),
        hidden: json['hidden'] as bool? ?? false,
        urgent: json['urgent'] as bool? ?? false,
      );
}
