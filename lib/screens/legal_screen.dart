import 'package:flutter/material.dart';

import '../data/consent_service.dart';
import '../theme.dart';

enum LegalDocument { terms, privacy }

/// Terms of Use and Privacy Policy. The wording follows the proposal's
/// privacy requirements (NFR10) and content rules (FR24). Have the
/// university's legal office review it before any real launch.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.document});

  final LegalDocument document;

  static const lastUpdated = '7 November 2026';

  @override
  Widget build(BuildContext context) {
    final isTerms = document == LegalDocument.terms;
    final sections = isTerms ? _termsSections : _privacySections;
    return Scaffold(
      appBar: AppBar(title: Text(isTerms ? 'Terms of Use' : 'Privacy Policy')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text('Version ${ConsentService.currentVersion} · Last updated $lastUpdated',
                style: const TextStyle(fontSize: 14, color: AppColors.inkMuted)),
            const SizedBox(height: 12),
            Text(
              isTerms
                  ? 'Please read these terms before using CampusFix. By signing in you agree to them.'
                  : 'This policy explains what information CampusFix collects, why, and who can see it.',
              style: const TextStyle(fontSize: 16),
            ),
            for (final (heading, body) in sections) ...[
              const SizedBox(height: 22),
              Semantics(
                header: true,
                child: Text(heading,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              Text(body, style: const TextStyle(fontSize: 16, height: 1.45)),
            ],
          ],
        ),
      ),
    );
  }
}

const _termsSections = <(String, String)>[
  (
    '1. What CampusFix is',
    'CampusFix lets students report problems with campus facilities, academic services and '
        'infrastructure, vote on problems reported by others, and follow the university\'s '
        'response until the problem is resolved. University staff use it to review reports and '
        'update their status.',
  ),
  (
    '2. Who may use it',
    'CampusFix is for current students and staff of the university. You must sign in with your '
        'own university account. Do not share your account or use someone else\'s.',
  ),
  (
    '3. Reporting responsibly',
    'Reports must be honest and about a real campus problem. When you report an issue:\n'
        '• Describe the problem, not a person. Do not name, insult or accuse anyone.\n'
        '• Do not include personal information such as phone numbers, ID numbers or health details.\n'
        '• Only attach photos you took yourself. Do not photograph people without their consent.\n'
        '• Check the feed first. If the problem is already reported, vote for it instead of '
        'reporting it again.',
  ),
  (
    '4. Content that is not allowed',
    'Abusive, offensive, threatening, discriminatory, false or spam reports are not allowed, and '
        'neither is content that breaks the law or university regulations. Staff may hide reports '
        'that break these rules. Repeated misuse may be reported to the university under its '
        'student conduct rules.',
  ),
  (
    '5. Voting',
    'Each student can vote once per issue. Votes help the university see which problems affect '
        'the most students. Do not try to inflate votes, for example by using several accounts.',
  ),
  (
    '6. What the university commits to',
    'Staff review reports and update their status (Reported, Under review, In progress, '
        'Resolved). CampusFix does not guarantee that a problem will be fixed or by when. For '
        'emergencies or safety hazards, contact campus security directly: do not rely on the app.',
  ),
  (
    '7. Your content',
    'You keep ownership of what you submit. You allow the university to store, display and use '
        'your reports and photos to handle the issue and improve campus services.',
  ),
  (
    '8. Prototype notice',
    'This version of CampusFix is a course prototype (GIN528 – Mobile Programming). It uses '
        'test accounts and sample data, and is not connected to the university\'s real systems.',
  ),
  (
    '9. Changes to these terms',
    'If these terms change, the app will ask you to read and accept the new version before you '
        'continue using it.',
  ),
  (
    '10. Contact',
    'Questions about these terms can be sent to the CampusFix team through the course '
        'instructor or the university\'s student services office.',
  ),
];

const _privacySections = <(String, String)>[
  (
    '1. What we collect',
    'Only what is needed to run the service:\n'
        '• Account: an account identifier, your name and your university email.\n'
        '• Reports: the title, description, category, location and any photos you add, with the '
        'date and time.\n'
        '• Votes: which issues you voted for, so you can vote only once per issue.\n'
        '• Consent: the version of these documents you accepted and when.',
  ),
  (
    '2. What we do not collect',
    'CampusFix does not track your location in the background, read your contacts, or collect '
        'advertising identifiers. It does not use analytics or advertising services.',
  ),
  (
    '3. Who can see what',
    '• Other students see the report itself (title, description, category, location, photos, '
        'status and number of votes). They never see who reported or voted for an issue.\n'
        '• Staff see the same report details so they can act on it.\n'
        '• Only you can see which issues you reported or voted for, under My issues.',
  ),
  (
    '4. Camera, photos and location',
    'The app asks for permission only when you choose to use these features:\n'
        '• Camera and photo library: only when you tap Take photo or Choose from gallery.\n'
        '• Location: only when you tap Use my location, to fill in the location field once. '
        'You can always type the location instead and refuse the permission.',
  ),
  (
    '5. Why we use your data',
    'To let you report, vote on and follow issues; to let staff handle them; to enforce one vote '
        'per student; and to keep the service safe from abuse.',
  ),
  (
    '6. Where data is stored',
    'In this prototype, all data is stored on this device only and is not sent to any server. '
        'Signing out keeps the reports on the device; withdrawing consent signs you out.',
  ),
  (
    '7. How long we keep it',
    'Reports are kept while they are useful for handling the issue and for the university\'s '
        'records of campus problems. In a real deployment, the university will set and publish '
        'a retention period.',
  ),
  (
    '8. Your choices and rights',
    'You can read these documents at any time from the menu. You can withdraw your consent from '
        'the menu, which signs you out. You can ask the university to see, correct or delete the '
        'personal data held about you.',
  ),
  (
    '9. Security',
    'Only signed-in users with the right role can create reports, vote or change a status. '
        'These rules are enforced by the system, not only by hiding buttons.',
  ),
  (
    '10. Changes to this policy',
    'If this policy changes, the app will ask you to read and accept the new version.',
  ),
];
