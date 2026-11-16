# CampusFix

A university issue reporting and tracking app (GIN528 – Mobile Programming).
Students report campus problems, vote on issues reported by others, and follow
each issue from **Reported → Under review → In progress → Resolved**. Staff
move issues to the next status.

One Flutter app for Android and iOS, portrait only (NFR12).

## Run

```bash
flutter pub get
flutter run
```

```bash
flutter test
```

## Test accounts

The project has no access to real university systems (proposal §9.2), so it
uses simulated accounts. The login screen lists them under **Test accounts**;
tap one to fill in the form.

| Role    | Email                     | Password     |
|---------|---------------------------|--------------|
| Student | student1@campusfix.test   | student123   |
| Student | student2@campusfix.test   | student123   |
| Staff   | staff@campusfix.test      | staff123     |

Data is stored on the device (`shared_preferences`) and starts with sample
issues from the prototype. Use **Account menu → Reset sample data** to start over.

## Structure

```
lib/
  main.dart                     app entry, sign-in gate
  theme.dart                    prototype palette, 48 dp targets, 4.5:1 contrast
  models/                       Issue, IssueStatus, IssueCategory, AppUser, ReportDraft
  data/
    issue_repository.dart       storage + all business rules (roles, one vote, status order)
    auth_service.dart           sign-in against test accounts
    consent_service.dart        Terms of Use / Privacy Policy acceptance
    seed_data.dart, test_accounts.dart
  services/device_services.dart camera/gallery photos, one-off location
  state/app_state.dart          ChangeNotifier: user, filters, sort, actions
  screens/                      login, feed, my issues, details (+ staff box),
                                report form, report sent, legal documents
  widgets/                      issue card, vote button, status chip/line, empty state
test/
  repository_test.dart          acceptance criteria and rules, at the data level
  widget_test.dart              UI flows, empty state, validation, staff, 200% text
```

## Requirements coverage

| Requirement | Where |
|---|---|
| FR1, FR2 sign-in, roles | `login_screen.dart`, `home_shell.dart` (staff: no Report or Vote) |
| FR3–FR7 report form, fixed categories, typed location, "Reported" + confirmation | `report_form_screen.dart`, `report_sent_screen.dart` |
| FR8, FR18 feed ranked by votes, first screen | `feed_screen.dart`, `sortIssues()` |
| FR9 details | `issue_details_screen.dart` |
| FR10, NFR11 one vote per student, quick taps count once | `IssueRepository.vote`, `vote_button.dart` |
| FR11 "No issues found" | `empty_state.dart` |
| FR12–FR15 status timeline, staff moves to next step only, timestamps | `StatusTimeline`, `_StaffAction` |
| FR16 My reports (Reported / Voted tabs) | `my_issues_screen.dart` |
| FR17 filters + search + sort | `_FilterBar` in `feed_screen.dart` |
| FR19 up to 3 optional photos | `report_form_screen.dart`, `PhotoService` |
| FR20 similar-issue suggestions | `IssueRepository.findSimilar` |
| FR24 staff hide abusive reports | `IssueRepository.setHidden` |
| NFR5 text scaling to 200% | `Wrap` layouts; checked in `widget_test.dart` |
| NFR7, NFR8 no crash on empty / denied / failed save; form keeps text | `DeviceResult`, `SaveFailedException` |
| NFR9 rules enforced by the system, not only hidden buttons | `_requireStudent` / `_requireStaff` in the repository |
| NFR10 minimum data, reporters and voters never shown | `Issue` model, details screen |

Not built (Could / Won't now): push notifications (FR21), comments (FR22), map view (FR23).

## Design (high fidelity)

The interface follows patterns common to issue-reporting apps (SeeClickFix,
FixMyStreet, UCLA 311, Snap Send Solve) and community-voting apps, on Material 3:

- **Navigation**: bottom bar with Issues, My reports and Profile (staff: Issues
  and Profile), plus a floating **Report issue** button.
- **Feed**: greeting and title, search bar, filter chips (status and sort open
  bottom sheets, categories have icons), a result count, and cards with a
  category icon, location, age, a coloured status chip and an upvote box.
- **Report**: start with an optional photo (Snap Send Solve style), pick the
  category from icon tiles, describe it (with a **Safety hazard or urgent**
  switch), then pick the USEK building from a searchable list
  (`lib/data/campus_places.dart`) plus an optional room. Open issues in the
  same building and similar titles are suggested before submitting. Submit is
  pinned to the bottom; a reference number (e.g. `CF-1A2B3C`) confirms it.
- **Staff updates**: moving an issue to the next status can include a short
  note for students, shown in the progress timeline.
- **Urgent issues**: a red Urgent badge on cards and details, so serious
  problems stand out even with few votes (assumption A3).
- **Details**: category or photo header, status and category chips, info rows,
  Description and Progress (timeline) cards, and the main action pinned to the
  bottom (Vote for students, Move to next status for staff).
- **Profile**: account header (opens account details: name, email, account
  type, Student/Staff ID, and **Change password**), tappable activity counts
  (students: Reported / Voted for / Resolved; staff: a work queue of New /
  In review / In progress), then Help and support (how it works, status guide,
  contact, emergencies), Privacy and legal (Terms, Privacy Policy, consent,
  withdraw), About, and Sign out.
- **Guided tour**: after the first sign-in (and after Get started when
  replayed from Profile → How CampusFix works) the screen dims and each
  control is circled in turn with a short phrase; Skip, Back and Next.
- **Onboarding**: three intro pages on first launch.

## Sign-in with email two-factor authentication

Sign-in has two steps: the university password, then a 6-digit code sent to
the university email (valid 10 minutes, 5 attempts, resend after 30 s).
`lib/data/otp_service.dart` defines the `EmailOtpService` API with two
implementations:

- `SimulatedEmailOtpService` (default): no mail server, so the prototype
  shows the code on the "Check your email" screen.
- `HttpEmailOtpService`: calls a real backend. Build with
  `flutter run --dart-define=OTP_API_URL=https://your-server/api/` and the
  server must provide:
  - `POST otp/send` `{"email": "..."}` → `200 {"expiresInSeconds": 600}`
    (generates, stores and emails the code)
  - `POST otp/verify` `{"email": "...", "code": "123456"}` →
    `200 {"valid": true}` or `{"valid": false, "message": "..."}`

Changed passwords are stored only as a salted SHA-256 hash.

## Course design rules applied (Lecture 2)

- **Error prevention**: category from a fixed list and filter chips always
  visible (recognition over recall); "Use my location", test-account picker and
  duplicate suggestions reduce typing; a permanent **Staff** badge shows which
  mode you are in; the upvote box is a separate target from the card, and
  "Hide report" sits in the overflow menu, apart from the main staff action.
- **Feedback**: every action shows a message; votes change to **Voted**;
  spinners appear while saving; status uses an icon as well as a colour.
- **Error recovery**: Undo after voting, hiding and adding/removing photos;
  Cancel on the report form, with a "Discard this report?" check; confirmation
  before irreversible actions (status change, reset data, sign out, withdraw
  consent); reasonableness checks (title length, photo limit); the cursor goes to
  the first field with an error; plain-language messages next to each field.
- **Context help**: Help on the progress timeline, tips on the report form.
- **Novice users**: three onboarding pages on first launch and a small set of
  tasks; pull-to-refresh and search for frequent users.

## Terms of Use and Privacy Policy

Users must tick **"I agree to the Terms of Use and Privacy Policy"** before
signing in. The acceptance is recorded with its version (`ConsentService`);
raising `ConsentService.currentVersion` asks everyone to accept again. Both
documents can be opened from the login screen and from the Profile tab, where
consent can also be withdrawn. Have the text reviewed by the university before
any real launch.
