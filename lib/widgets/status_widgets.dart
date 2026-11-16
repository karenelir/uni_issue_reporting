import 'package:flutter/material.dart';

import '../models/issue.dart';
import '../theme.dart';
import 'format.dart';

/// Coloured pill with icon and label for an issue's status (FR12).
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.large = false});

  final IssueStatus status;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final style = StatusStyle.of(status);
    return Semantics(
      label: 'Status: ${status.label}',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: large ? 12 : 10, vertical: large ? 6 : 4),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, size: large ? 18 : 16, color: style.foreground),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                status.label,
                style: TextStyle(
                  fontSize: large ? 14 : 13,
                  fontWeight: FontWeight.w600,
                  color: style.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Red "Urgent" label for issues flagged as a safety hazard.
class UrgentBadge extends StatelessWidget {
  const UrgentBadge({super.key, this.large = false});

  final bool large;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Urgent, safety hazard',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: large ? 12 : 8, vertical: large ? 6 : 2),
        decoration: BoxDecoration(
          color: AppColors.errorContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: large ? 18 : 14, color: AppColors.error),
            const SizedBox(width: 4),
            Text(large ? 'Safety hazard' : 'Urgent',
                style: TextStyle(
                    fontSize: large ? 14 : 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error)),
          ],
        ),
      ),
    );
  }
}

/// Round category icon, as used by 311 apps to identify the request type.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar(this.category, {super.key, this.size = 44});

  final IssueCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(category);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: style.background, shape: BoxShape.circle),
        child: Icon(style.icon, color: style.foreground, size: size * 0.5),
      ),
    );
  }
}

/// Vertical progress timeline Reported -> Under review -> In progress ->
/// Resolved, with the date of each step (US3, FR12, FR15). Vertical, so
/// labels are never cut off at large font sizes (NFR5).
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({super.key, required this.issue});

  final Issue issue;

  @override
  Widget build(BuildContext context) {
    final current = issue.status;
    final changes = {for (final c in issue.history) c.status: c};
    const descriptions = {
      IssueStatus.reported: 'Report received',
      IssueStatus.underReview: 'Staff are checking the report',
      IssueStatus.inProgress: 'Someone is fixing the problem',
      IssueStatus.resolved: 'Staff consider it fixed',
    };

    return Column(
      children: [
        for (final status in IssueStatus.values)
          _Step(
            status: status,
            done: status.index < current.index,
            current: status == current,
            last: status == IssueStatus.values.last,
            subtitle: changes[status] != null
                ? dateTimeFormat.format(changes[status]!.changedAt)
                : descriptions[status]!,
            note: changes[status]?.note,
          ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.status,
    required this.done,
    required this.current,
    required this.last,
    required this.subtitle,
    this.note,
  });

  final IssueStatus status;
  final bool done;
  final bool current;
  final bool last;
  final String subtitle;

  /// Public note from staff explaining this step.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final reached = done || current;
    final style = StatusStyle.of(status);
    final dotColor = reached ? style.foreground : const Color(0xFFC3CBD2);
    final stateText = current ? 'current step' : (done ? 'done' : 'not reached yet');

    return Semantics(
      label: '${status.label}, $stateText, $subtitle'
          '${note != null ? '. Staff note: $note' : ''}',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 36,
              child: Column(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: reached ? style.background : Colors.white,
                      border: Border.all(color: dotColor, width: current ? 2.5 : 1.5),
                    ),
                    child: Icon(
                      done ? Icons.check : style.icon,
                      size: 16,
                      color: dotColor,
                    ),
                  ),
                  if (!last)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        constraints: const BoxConstraints(minHeight: 14),
                        color: done ? style.foreground : const Color(0xFFDCE1E5),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            status.label,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                              color: reached ? AppColors.ink : AppColors.inkMuted,
                            ),
                          ),
                        ),
                        if (current) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: style.background,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text('Now',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: style.foreground)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(fontSize: 13.5, color: AppColors.inkMuted)),
                    if (note != null)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.campaign_outlined,
                                size: 16, color: AppColors.inkMuted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text.rich(
                                TextSpan(children: [
                                  const TextSpan(
                                      text: 'Staff: ',
                                      style: TextStyle(fontWeight: FontWeight.w700)),
                                  TextSpan(text: note),
                                ]),
                                style: const TextStyle(fontSize: 13.5, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Context-sensitive help explaining what each status means.
void showStatusHelp(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What the statuses mean', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            for (final (status, text) in const [
              (IssueStatus.reported, 'The report was received. Staff have not looked at it yet.'),
              (IssueStatus.underReview, 'Staff are checking the report and deciding what to do.'),
              (IssueStatus.inProgress, 'Someone is working on fixing the problem.'),
              (IssueStatus.resolved, 'Staff consider the problem fixed.'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusChip(status),
                    const SizedBox(width: 12),
                    Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
                  ],
                ),
              ),
            const Text(
              'Only university staff can move an issue forward, one step at a time. '
              'Issues with more votes are seen as affecting more students.',
              style: TextStyle(fontSize: 14, color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    ),
  );
}
