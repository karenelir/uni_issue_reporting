import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/issue.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/format.dart';
import '../widgets/status_widgets.dart';
import 'issue_details_screen.dart';

/// Screen 6: confirmation with a reference number and the first status,
/// "Reported", so the tracking journey starts here (FR7).
class ReportSentScreen extends StatelessWidget {
  const ReportSentScreen({super.key, required this.issueId});

  final String issueId;

  @override
  Widget build(BuildContext context) {
    final issue = context.read<AppState>().issueById(issueId);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.primaryContainer,
                        ),
                        child: const Icon(Icons.check_rounded, size: 60, color: AppColors.brand),
                      ),
                      const SizedBox(height: 24),
                      Semantics(
                        liveRegion: true,
                        child: const Text('Thank you, your report is in',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Other students can now see it and vote on it. '
                        'You will find it under My reports.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15.5, color: AppColors.inkMuted, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      if (issue != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _Row(label: 'Reference', value: Text(referenceOf(issue),
                                    style: const TextStyle(fontWeight: FontWeight.w700))),
                                const Divider(height: 24),
                                _Row(label: 'Issue', value: Text(issue.title, textAlign: TextAlign.end)),
                                const Divider(height: 24),
                                const _Row(label: 'Status', value: StatusChip(IssueStatus.reported)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 32),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => IssueDetailsScreen(issueId: issueId)),
                        ),
                        child: const Text('View my report'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Back to all issues'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: AppColors.inkMuted)),
        const SizedBox(width: 16),
        Expanded(child: Align(alignment: Alignment.centerRight, child: value)),
      ],
    );
  }
}
