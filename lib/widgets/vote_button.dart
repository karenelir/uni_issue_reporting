import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/exceptions.dart';
import '../models/issue.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'feedback.dart';
import 'format.dart';

/// Upvote control (FR10), in the compact box style used by community
/// voting apps, or as a full-width button on the details screen.
///
/// One tap adds a vote and offers Undo. Tapping again does not add a second
/// vote: the student is told they already voted. The control is disabled
/// while saving, so quick repeated taps count once (NFR11). Staff do not
/// vote; they see the count only.
class VoteButton extends StatefulWidget {
  const VoteButton({super.key, required this.issue, this.expanded = false});

  final Issue issue;

  /// Full-width button for the details screen's bottom bar.
  final bool expanded;

  @override
  State<VoteButton> createState() => _VoteButtonState();
}

class _VoteButtonState extends State<VoteButton> {
  bool _busy = false;

  Future<void> _onPressed() async {
    final state = context.read<AppState>();
    final issue = widget.issue;
    if (state.hasVoted(issue)) {
      showMessage(
        context,
        'You already voted for this issue.',
        actionLabel: 'Remove my vote',
        onAction: () => _removeVote(state, issue),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await state.vote(issue.id);
      if (!mounted) return;
      showMessage(
        context,
        'Vote added. Thanks for supporting this issue.',
        actionLabel: 'Undo',
        onAction: () => _removeVote(state, issue),
      );
    } on AlreadyVotedException catch (e) {
      if (mounted) showMessage(context, e.message);
    } catch (e) {
      if (mounted) showMessage(context, describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeVote(AppState state, Issue issue) async {
    try {
      await state.removeVote(issue.id);
    } catch (e) {
      if (mounted) showMessage(context, describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final issue = widget.issue;
    final votes = issue.votes;
    final isStaff = state.user?.isStaff ?? false;
    final voted = state.hasVoted(issue);
    final scheme = Theme.of(context).colorScheme;

    if (isStaff) return _StaffCount(votes: votes, expanded: widget.expanded);

    final semantics = voted
        ? 'Voted, ${plural(votes, 'vote')}. You already voted for this issue.'
        : 'Vote for this issue, ${plural(votes, 'vote')}';

    if (widget.expanded) {
      final icon = _busy
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(voted ? Icons.check_circle : Icons.arrow_upward_rounded);
      final label = Semantics(
        label: semantics,
        excludeSemantics: true,
        child: Text(voted ? 'Voted · $votes' : 'Vote · $votes'),
      );
      return voted
          ? OutlinedButton.icon(
              onPressed: _busy ? null : _onPressed,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: scheme.secondaryContainer,
                side: BorderSide.none,
              ),
              icon: icon,
              label: label,
            )
          : FilledButton.icon(
              onPressed: _busy ? null : _onPressed,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              icon: icon,
              label: label,
            );
    }

    // Compact upvote box.
    final fg = voted ? Colors.white : AppColors.brand;
    return Material(
      color: voted ? AppColors.brand : scheme.secondaryContainer.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _busy ? null : _onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Semantics(
          button: true,
          label: semantics,
          excludeSemantics: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: _busy
                  ? Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: fg)),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(voted ? Icons.check_rounded : Icons.arrow_upward_rounded,
                            size: 20, color: fg),
                        Text('$votes',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700, color: fg)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StaffCount extends StatelessWidget {
  const _StaffCount({required this.votes, required this.expanded});

  final int votes;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: plural(votes, 'vote'),
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 56),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.how_to_vote_outlined, size: 20, color: AppColors.inkMuted),
            Text('$votes', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
