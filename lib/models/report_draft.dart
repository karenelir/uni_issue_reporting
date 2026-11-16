import 'issue.dart';

/// The fields a student fills in on the report form (FR3).
class ReportDraft {
  ReportDraft({
    this.title = '',
    this.description = '',
    this.category,
    this.location = '',
    List<String>? photoPaths,
    this.urgent = false,
  }) : photoPaths = photoPaths ?? [];

  static const maxPhotos = 3;
  static const minTitleLength = 5;
  static const maxTitleLength = 80;
  static const maxDescriptionLength = 1000;

  String title;
  String description;
  IssueCategory? category;
  String location;
  final List<String> photoPaths;
  bool urgent;

  /// Validates the four required fields and returns one plain-language
  /// message per missing field, keyed by field name (FR5, NFR4).
  Map<ReportField, String> validate() {
    final errors = <ReportField, String>{};
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      errors[ReportField.title] = 'Title is required. Add a few words.';
    } else if (trimmedTitle.length < minTitleLength) {
      // Reasonableness check on the input.
      errors[ReportField.title] =
          'Title is too short. Use at least $minTitleLength characters.';
    }
    if (category == null) {
      errors[ReportField.category] = 'Choose a category from the list.';
    }
    if (location.trim().isEmpty) {
      errors[ReportField.location] =
          'Location is required. Type the building, room or area.';
    }
    if (description.trim().isEmpty) {
      errors[ReportField.description] =
          'Description is required. Say what happened.';
    }
    if (photoPaths.length > maxPhotos) {
      errors[ReportField.photos] = 'You can attach up to $maxPhotos photos.';
    }
    return errors;
  }
}

enum ReportField {
  title('Title'),
  category('Category'),
  location('Location'),
  description('Description'),
  photos('Photos');

  const ReportField(this.label);

  final String label;
}
