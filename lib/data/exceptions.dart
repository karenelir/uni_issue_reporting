import '../models/report_draft.dart';

/// Base class for errors the UI turns into a plain-language message.
sealed class CampusFixException implements Exception {
  const CampusFixException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The action needs a signed-in user (FR1, NFR9).
class NotSignedInException extends CampusFixException {
  const NotSignedInException() : super('Please sign in to do this.');
}

/// The signed-in user's role does not allow the action (FR2, FR13, NFR9).
class PermissionDeniedException extends CampusFixException {
  const PermissionDeniedException(super.message);
}

/// The report is missing required fields (FR5).
class ValidationException extends CampusFixException {
  ValidationException(this.errors)
      : super('Report not sent. Please fill in: '
            '${errors.keys.map((f) => f.label).join(', ')}.');

  final Map<ReportField, String> errors;
}

/// The student has already voted for this issue (FR10).
class AlreadyVotedException extends CampusFixException {
  const AlreadyVotedException() : super('You already voted for this issue.');
}

class IssueNotFoundException extends CampusFixException {
  const IssueNotFoundException() : super('This issue is no longer available.');
}

/// Saving failed (for example, the connection was lost) (NFR8).
class SaveFailedException extends CampusFixException {
  const SaveFailedException(super.message);
}

class ConsentRequiredException extends CampusFixException {
  const ConsentRequiredException()
      : super('Please accept the Terms of Use and Privacy Policy to continue.');
}

/// The email verification code was wrong, expired or could not be sent.
class VerificationException extends CampusFixException {
  const VerificationException(super.message);
}

/// A new password was refused (wrong current password or too weak).
class PasswordChangeException extends CampusFixException {
  const PasswordChangeException(super.message);
}

class InvalidCredentialsException extends CampusFixException {
  const InvalidCredentialsException()
      : super('Email or password is incorrect. Check them and try again.');
}
