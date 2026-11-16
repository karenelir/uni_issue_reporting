import 'package:flutter/material.dart';

import '../theme.dart';

/// Three short intro pages shown on first launch, explaining the core
/// journey to first-time (novice) users: report, vote, follow.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    (
      Icons.add_a_photo_outlined,
      'Report campus problems',
      'Broken AC, Wi-Fi drops, a wrong timetable? Report it in under two minutes, '
          'with a photo if you like.',
    ),
    (
      Icons.arrow_upward_rounded,
      'Vote on what matters',
      'See what other students reported and vote for the issues that affect you. '
          'The most voted issues rise to the top.',
    ),
    (
      Icons.timeline_rounded,
      'Follow the fix',
      'Track each issue from Reported to Resolved as university staff update it.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _pages.length - 1) {
      widget.onDone();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = _page == _pages.length - 1;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: widget.onDone, child: const Text('Skip')),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  for (final (icon, title, text) in _pages)
                    SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                      child: Column(
                        children: [
                          Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, size: 72, color: AppColors.brand),
                          ),
                          const SizedBox(height: 40),
                          Text(title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 12),
                          Text(text,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 16, color: AppColors.inkMuted, height: 1.45)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Semantics(
              label: 'Page ${_page + 1} of ${_pages.length}',
              excludeSemantics: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page ? AppColors.brand : AppColors.outline,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: FilledButton(
                onPressed: _next,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: Text(last ? 'Get started' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
