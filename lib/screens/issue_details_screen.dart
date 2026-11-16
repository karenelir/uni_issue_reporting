import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/issue.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/feedback.dart';
import '../widgets/format.dart';
import '../widgets/photo_image.dart';
import '../widgets/status_widgets.dart';
import '../widgets/vote_button.dart';

/// Screens 3 and 8: issue details for students, and the staff action for
/// staff accounts (FR9, FR10, FR12 to FR15, FR24). The main action sits in
/// a bar pinned to the bottom of the screen, within thumb reach.
class IssueDetailsScreen extends StatelessWidget {
  const IssueDetailsScreen({super.key, required this.issueId});

  final String issueId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final issue = state.issueById(issueId);
    final isStaff = state.user?.isStaff ?? false;

    if (issue == null) {
      // Hidden or removed while open: never a broken page (NFR7).
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: EmptyState(
            title: 'Issue not available',
            message: 'This issue is no longer available. Go back to see the other issues.',
            icon: Icons.visibility_off_outlined,
          ),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: state.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _Header(issue: issue, isStaff: isStaff),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              sliver: SliverList.list(
                children: [
                  _Summary(issue: issue, isMine: state.isMine(issue)),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Description',
                    child: Text(issue.description,
                        style: const TextStyle(fontSize: 15.5, height: 1.45)),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Progress',
                    action: TextButton.icon(
                      onPressed: () => showStatusHelp(context),
                      icon: const Icon(Icons.help_outline, size: 18),
                      label: const Text('Help'),
                    ),
                    child: StatusTimeline(issue: issue),
                  ),
                  if (!isStaff) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'One vote per student. Other students never see who reported or voted.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(
        child: isStaff ? _StaffAction(issue: issue) : VoteButton(issue: issue, expanded: true),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.issue, required this.isStaff});

  final Issue issue;
  final bool isStaff;

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(issue.category);
    final hasPhotos = issue.photoPaths.isNotEmpty;
    return SliverAppBar(
      pinned: true,
      expandedHeight: hasPhotos ? 260 : 150,
      backgroundColor: hasPhotos ? Colors.black : style.background,
      foregroundColor: hasPhotos ? Colors.white : style.foreground,
      title: const Text('Issue details'),
      actions: [if (isStaff) _StaffMenu(issue: issue)],
      flexibleSpace: FlexibleSpaceBar(
        background: hasPhotos
            ? _PhotoCarousel(paths: issue.photoPaths)
            : Align(
                alignment: const Alignment(0, 0.6),
                child: Icon(style.icon, size: 56, color: style.foreground.withValues(alpha: 0.85)),
              ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.issue, required this.isMine});

  final Issue issue;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusChip(issue.status, large: true),
            if (issue.urgent) const UrgentBadge(large: true),
            Chip(
              avatar: Icon(CategoryStyle.of(issue.category).icon, size: 18),
              label: Text(issue.category.label),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(issue.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
        const SizedBox(height: 12),
        _InfoRow(icon: Icons.place_outlined, text: issue.location),
        _InfoRow(
          icon: Icons.event_outlined,
          text: DateTime.now().difference(issue.createdAt).inDays < 7
              ? 'Reported ${timeAgo(issue.createdAt)} · ${dateTimeFormat.format(issue.createdAt)}'
              : 'Reported ${dateTimeFormat.format(issue.createdAt)}',
        ),
        _InfoRow(icon: Icons.how_to_vote_outlined, text: '${plural(issue.votes, 'student')} affected'),
        if (isMine)
          _InfoRow(
            icon: Icons.person_outline,
            text: 'You reported this · Ref. ${referenceOf(issue)}',
            highlight: true,
          ),
        if (issue.hidden)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.visibility_off_outlined, color: AppColors.error),
                SizedBox(width: 10),
                Expanded(child: Text('Hidden from students for breaking the content rules.')),
              ],
            ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, this.highlight = false});

  final IconData icon;
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.brand : AppColors.inkMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 14.5,
                    color: highlight ? AppColors.brand : AppColors.ink,
                    fontWeight: highlight ? FontWeight.w600 : FontWeight.w400)),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Semantics(
                    header: true,
                    child: Text(title,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 4),
            child,
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 10), child: child),
      ),
    );
  }
}

class _PhotoCarousel extends StatelessWidget {
  const _PhotoCarousel({required this.paths});

  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      itemCount: paths.length,
      itemBuilder: (context, i) => Semantics(
        button: true,
        label: 'Photo ${i + 1} of ${paths.length}. Tap to enlarge.',
        child: GestureDetector(
          onTap: () => _openPhoto(context, paths[i]),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _photo(paths[i], BoxFit.cover),
              if (paths.length > 1)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('${i + 1} / ${paths.length}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPhoto(BuildContext context, String path) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Photo', style: TextStyle(color: Colors.white)),
        ),
        body: Center(child: InteractiveViewer(child: _photo(path, BoxFit.contain))),
      ),
    ));
  }
}

Widget _photo(String path, BoxFit fit) => photoImage(
      path,
      fit: fit,
      // A missing file shows a placeholder instead of crashing (NFR7).
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Color(0xFF2B2F33),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined, size: 36, color: Colors.white70),
              Text('Photo unavailable', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );

/// Staff move an issue to the next status only; students never see this
/// control, and the system refuses the action for them anyway (FR13).
class _StaffAction extends StatefulWidget {
  const _StaffAction({required this.issue});

  final Issue issue;

  @override
  State<_StaffAction> createState() => _StaffActionState();
}

class _StaffActionState extends State<_StaffAction> {
  bool _busy = false;

  Future<void> _advance() async {
    final issue = widget.issue;
    final next = issue.status.next!;
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _StatusChangeDialog(issue: issue, next: next),
    );
    if (note == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final status = await context.read<AppState>().advanceStatus(issue.id, note: note);
      if (mounted) showMessage(context, 'Status changed to ${status.label}.');
    } catch (e) {
      if (mounted) showMessage(context, describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final next = widget.issue.status.next;
    if (next == null) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: Color(0xFF1B6B35)),
          SizedBox(width: 8),
          Flexible(child: Text('Resolved. No further steps.', style: TextStyle(fontSize: 15))),
        ],
      );
    }
    return FilledButton.icon(
      onPressed: _busy ? null : _advance,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      icon: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(StatusStyle.of(next).icon),
      label: Text('Move to: ${next.label}'),
    );
  }
}

/// Confirms a status change and lets staff add a short public note, as
/// 311 apps do, so students know what is happening. Returns the note
/// ('' for none), or null when cancelled.
class _StatusChangeDialog extends StatefulWidget {
  const _StatusChangeDialog({required this.issue, required this.next});

  final Issue issue;
  final IssueStatus next;

  @override
  State<_StatusChangeDialog> createState() => _StatusChangeDialogState();
}

class _StatusChangeDialogState extends State<_StatusChangeDialog> {
  final _note = TextEditingController();

  static const _examples = {
    IssueStatus.underReview: 'e.g. Facilities team informed.',
    IssueStatus.inProgress: 'e.g. Technician booked for Thursday.',
    IssueStatus.resolved: 'e.g. Unit repaired and tested.',
  };

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final next = widget.next;
    return AlertDialog(
      title: Text('Move to "${next.label}"?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Students will see that "${widget.issue.title}" is now '
              '${next.label.toLowerCase()}. Statuses only move forward, so this cannot be undone.',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              maxLength: 200,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Note for students (optional)',
                hintText: _examples[next],
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _note.text.trim()),
          child: Text('Move to ${next.label}'),
        ),
      ],
    );
  }
}

/// Hide / show is kept in the overflow menu, away from the main action, so
/// it is not pressed by mistake (FR24).
class _StaffMenu extends StatelessWidget {
  const _StaffMenu({required this.issue});

  final Issue issue;

  Future<void> _toggle(BuildContext context) async {
    final hide = !issue.hidden;
    if (hide) {
      final ok = await confirmAction(
        context,
        title: 'Hide this report?',
        message: 'Students will no longer see it. Hide reports only when they break the '
            'content rules (abusive, offensive or fake). You can show it again later.',
        confirmLabel: 'Hide report',
        destructive: true,
      );
      if (!ok || !context.mounted) return;
    }
    final state = context.read<AppState>();
    try {
      await state.setHidden(issue.id, hide);
      if (!context.mounted) return;
      showMessage(
        context,
        hide ? 'Report hidden from students.' : 'Report visible to students again.',
        actionLabel: 'Undo',
        onAction: () => state.setHidden(issue.id, !hide),
      );
    } catch (e) {
      if (context.mounted) showMessage(context, describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      tooltip: 'More actions',
      itemBuilder: (_) => [
        PopupMenuItem(
          onTap: () => _toggle(context),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(issue.hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: issue.hidden ? null : AppColors.error),
            title: Text(issue.hidden ? 'Show to students' : 'Hide report (breaks the rules)'),
          ),
        ),
      ],
    );
  }
}
