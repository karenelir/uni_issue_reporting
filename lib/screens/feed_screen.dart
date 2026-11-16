import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/issue.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/format.dart';
import '../widgets/issue_card.dart';
import '../widgets/spotlight_tour.dart';
import '../widgets/status_widgets.dart';
import 'issue_details_screen.dart';

/// Screen 2: the main feed, first screen after sign-in. Every issue is shown,
/// ranked by votes with the highest first (FR8, FR18), with search, category
/// and status filters (FR17) and sort. Pull down to refresh (FR14).
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearAll(AppState state) {
    _searchController.clear();
    state.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;
    final isStaff = user?.isStaff ?? false;
    final issues = state.feed;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: state.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isStaff
                                  ? 'Staff dashboard'
                                  : 'Hi, ${user?.name.split(' ').first ?? ''}',
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppColors.inkMuted,
                              ),
                            ),
                            Semantics(
                              header: true,
                              child: const Text(
                                'Campus issues',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Always-visible cue for staff mode (avoids mode errors).
                      if (isStaff)
                        Chip(
                          avatar: const Icon(Icons.badge_outlined, size: 18),
                          label: const Text('Staff'),
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .secondaryContainer,
                          side: BorderSide.none,
                        ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: SearchBar(
                    key: TourKeys.search,
                    controller: _searchController,
                    hintText: 'Search issues or places',
                    elevation: const WidgetStatePropertyAll(0),
                    backgroundColor: const WidgetStatePropertyAll(Colors.white),
                    side: const WidgetStatePropertyAll(
                      BorderSide(color: AppColors.outline),
                    ),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 16),
                    ),
                    leading: const Icon(
                      Icons.search,
                      color: AppColors.inkMuted,
                    ),
                    trailing: [
                      if (state.searchQuery.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            state.setSearchQuery('');
                          },
                        ),
                    ],
                    onChanged: state.setSearchQuery,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _FilterBar(key: TourKeys.filters, state: state),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    '${plural(issues.length, 'issue')} · ${state.sortOrder == SortOrder.mostVotes ? 'most voted first' : 'newest first'}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
              ),
              if (issues.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    message: state.hasActiveFilters
                        ? 'Nothing matches these filters. Try another category or status.'
                        : isStaff
                        ? 'No student has reported anything yet.'
                        : 'Nobody has reported anything yet. Tap Report issue to be the first.',
                    actionLabel: state.hasActiveFilters
                        ? 'Clear filters'
                        : null,
                    onAction: state.hasActiveFilters
                        ? () => _clearAll(state)
                        : null,
                  ),
                )
              else
                SliverPadding(
                  // Bottom padding keeps the last card clear of the Report button.
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList.separated(
                    itemCount: issues.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => KeyedSubtree(
                      key: i == 0 ? TourKeys.firstCard : ValueKey(issues[i].id),
                      child: IssueCard(
                        issue: issues[i],
                        voteKey: i == 0 ? TourKeys.firstVote : null,
                        rank: state.sortOrder == SortOrder.mostVotes
                            ? i + 1
                            : null,
                        tag: state.isMine(issues[i]) ? 'Your report' : null,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                IssueDetailsScreen(issueId: issues[i].id),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _SheetChip(
            icon: Icons.tune,
            label: state.statusFilter?.label ?? 'Any status',
            active: state.statusFilter != null,
            tooltip: 'Filter by status',
            onTap: () => _pickStatus(context),
          ),
          const SizedBox(width: 8),
          _SheetChip(
            icon: Icons.swap_vert,
            label: state.sortOrder.label,
            active: false,
            tooltip: 'Change sort order',
            onTap: () => _pickSort(context),
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 28, color: AppColors.outline),
          const SizedBox(width: 12),
          ChoiceChip(
            label: const Text('All'),
            selected: state.categoryFilter == null,
            showCheckmark: false,
            onSelected: (_) => state.setCategoryFilter(null),
          ),
          for (final c in IssueCategory.values) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              avatar: Icon(CategoryStyle.of(c).icon, size: 18),
              label: Text(c.shortLabel, semanticsLabel: c.label),
              selected: state.categoryFilter == c,
              showCheckmark: false,
              onSelected: (_) =>
                  state.setCategoryFilter(state.categoryFilter == c ? null : c),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickStatus(BuildContext context) async {
    final picked = await showModalBottomSheet<(IssueStatus?,)>(
      context: context,
      builder: (context) => _OptionsSheet(
        title: 'Filter by status',
        children: [
          _option(
            context,
            (null,),
            'Any status',
            state.statusFilter == null,
            null,
          ),
          for (final s in IssueStatus.values)
            _option(
              context,
              (s,),
              s.label,
              state.statusFilter == s,
              StatusChip(s),
            ),
        ],
      ),
    );
    if (picked != null) state.setStatusFilter(picked.$1);
  }

  Future<void> _pickSort(BuildContext context) async {
    final picked = await showModalBottomSheet<SortOrder>(
      context: context,
      builder: (context) => _OptionsSheet(
        title: 'Sort issues',
        children: [
          _option(
            context,
            SortOrder.mostVotes,
            'Most votes',
            state.sortOrder == SortOrder.mostVotes,
            const Icon(Icons.trending_up),
          ),
          _option(
            context,
            SortOrder.newest,
            'Newest',
            state.sortOrder == SortOrder.newest,
            const Icon(Icons.schedule),
          ),
        ],
      ),
    );
    if (picked != null) state.setSortOrder(picked);
  }

  Widget _option<T>(
    BuildContext context,
    T value,
    String label,
    bool selected,
    Widget? leading,
  ) {
    return ListTile(
      leading: leading,
      title: leading is StatusChip ? null : Text(label),
      trailing: selected
          ? const Icon(Icons.check, color: AppColors.brand)
          : null,
      selected: selected,
      onTap: () => Navigator.pop(context, value),
    );
  }
}

class _OptionsSheet extends StatelessWidget {
  const _OptionsSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SheetChip extends StatelessWidget {
  const _SheetChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: ActionChip(
        avatar: Icon(icon, size: 18),
        backgroundColor: active
            ? Theme.of(context).colorScheme.secondaryContainer
            : null,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Text(label), const Icon(Icons.arrow_drop_down, size: 20)],
        ),
        onPressed: onTap,
      ),
    );
  }
}
