import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/issue.dart';
import '../state/app_state.dart';
import '../widgets/empty_state.dart';
import '../widgets/issue_card.dart';
import 'issue_details_screen.dart';

/// Issues the student reported or voted for, so they can follow them (FR16).
class MyIssuesScreen extends StatelessWidget {
  const MyIssuesScreen({super.key, required this.onReport, this.initialTab = 0});

  final VoidCallback onReport;

  /// 0 = Reported, 1 = Voted.
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final reported = state.myIssues.where(state.isMine).toList();
    final voted = state.myIssues.where((i) => !state.isMine(i)).toList();

    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My reports'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Reported (${reported.length})'),
              Tab(text: 'Voted (${voted.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _IssueList(
              issues: reported,
              empty: EmptyState(
                icon: Icons.assignment_outlined,
                title: 'No reports yet',
                message: 'Issues you report will appear here, so you can follow their status.',
                actionLabel: 'Report an issue',
                onAction: onReport,
              ),
            ),
            _IssueList(
              issues: voted,
              empty: const EmptyState(
                icon: Icons.how_to_vote_outlined,
                title: 'No votes yet',
                message: 'Vote for issues in the feed that affect you, and follow them here.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueList extends StatelessWidget {
  const _IssueList({required this.issues, required this.empty});

  final List<Issue> issues;
  final Widget empty;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return RefreshIndicator(
      onRefresh: state.refresh,
      child: issues.isEmpty
          ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(child: empty),
                ),
              ),
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: issues.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => IssueCard(
                key: ValueKey(issues[i].id),
                issue: issues[i],
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => IssueDetailsScreen(issueId: issues[i].id),
                )),
              ),
            ),
    );
  }
}
