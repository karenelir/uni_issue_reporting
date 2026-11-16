import '../models/app_user.dart';

/// Simulated university accounts. The project has no access to real
/// university systems (Section 9.2, NFR13), so sign-in uses these test
/// accounts only. Replace [AuthService] with the university's identity
/// provider when one is available.
class TestAccount {
  const TestAccount(this.user, this.password);

  final AppUser user;
  final String password;
}

const testAccounts = <TestAccount>[
  TestAccount(
    AppUser(
      id: 'stu-001',
      universityId: '202310452',
      name: 'Student One',
      email: 'student1@campusfix.test',
      role: UserRole.student,
    ),
    'student123',
  ),
  TestAccount(
    AppUser(
      id: 'stu-002',
      universityId: '202311873',
      name: 'Student Two',
      email: 'student2@campusfix.test',
      role: UserRole.student,
    ),
    'student123',
  ),
  TestAccount(
    AppUser(
      id: 'staff-001',
      universityId: 'S-1047',
      name: 'Maintenance Staff',
      email: 'staff@campusfix.test',
      role: UserRole.staff,
    ),
    'staff123',
  ),
];
