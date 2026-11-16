enum UserRole { student, staff }

/// A signed-in account. Only the data needed to run the service is kept:
/// an identifier, the university ID, a display name and an email (NFR10).
class AppUser {
  const AppUser({
    required this.id,
    required this.universityId,
    required this.name,
    required this.email,
    required this.role,
  });

  final String id;

  /// Student ID or staff ID issued by the university.
  final String universityId;
  final String name;
  final String email;
  final UserRole role;

  bool get isStaff => role == UserRole.staff;
  bool get isStudent => role == UserRole.student;

  String get universityIdLabel => isStaff ? 'Staff ID' : 'Student ID';
}
