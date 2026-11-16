import 'package:flutter/material.dart';

import '../models/issue.dart';
import '../theme.dart';
import 'format.dart';
import 'status_widgets.dart';
import 'vote_button.dart';

/// One issue in a list: category icon, title, location, age, status and
/// photo count, with the upvote box on the right so students can vote
/// without opening the issue (FR8, FR10).
///
/// The card body opens the details; the upvote box is a separate target,
/// so the two actions are not confused.
class IssueCard extends StatelessWidget {
  const IssueCard({
    super.key,
    required this.issue,
    required this.onTap,
    this.rank,
    this.tag,
    this.showVote = true,
    this.voteKey,
  });

  final Issue issue;
  final VoidCallback onTap;
  final int? rank;

  /// Optional note such as "You reported this" (only ever about the viewer).
  final String? tag;
  final bool showVote;

  /// Lets the guided tour point at this card's vote box.
  final Key? voteKey;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategoryAvatar(issue.category),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (rank != null || tag != null || issue.hidden || issue.urgent)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (issue.urgent) const UrgentBadge(),
                            if (rank != null)
                              Semantics(
                                label: 'Rank $rank',
                                excludeSemantics: true,
                                child: Text('#$rank',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.brand)),
                              ),
                            if (tag != null)
                              Text(tag!,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.inkMuted)),
                            if (issue.hidden)
                              const Text('Hidden from students',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.error)),
                          ],
                        ),
                      ),
                    Text(issue.title,
                        style: const TextStyle(
                            fontSize: 16.5, fontWeight: FontWeight.w600, height: 1.25)),
                    const SizedBox(height: 6),
                    _MetaLine(icon: Icons.place_outlined, text: issue.location),
                    const SizedBox(height: 2),
                    _MetaLine(
                      icon: Icons.schedule,
                      text: [
                        timeAgo(issue.createdAt),
                        if (issue.photoPaths.isNotEmpty)
                          plural(issue.photoPaths.length, 'photo'),
                      ].join(' · '),
                    ),
                    const SizedBox(height: 10),
                    StatusChip(issue.status),
                  ],
                ),
              ),
              if (showVote) ...[
                const SizedBox(width: 8),
                VoteButton(key: voteKey, issue: issue),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 15, color: AppColors.inkMuted),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13.5, color: AppColors.inkMuted)),
        ),
      ],
    );
  }
}
