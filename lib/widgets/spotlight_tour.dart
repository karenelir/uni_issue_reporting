import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Widgets the guided tour points at. Each key is attached to exactly one
/// widget on the main screen.
abstract final class TourKeys {
  static final search = GlobalKey(debugLabel: 'tour-search');
  static final filters = GlobalKey(debugLabel: 'tour-filters');
  static final firstCard = GlobalKey(debugLabel: 'tour-first-card');
  static final firstVote = GlobalKey(debugLabel: 'tour-first-vote');
  static final report = GlobalKey(debugLabel: 'tour-report');
  static final issuesTab = GlobalKey(debugLabel: 'tour-issues-tab');
  static final myReportsTab = GlobalKey(debugLabel: 'tour-my-reports-tab');
  static final profileTab = GlobalKey(debugLabel: 'tour-profile-tab');
}

class TourStep {
  const TourStep({required this.target, required this.icon, required this.title, required this.text});

  final GlobalKey target;
  final IconData icon;
  final String title;
  final String text;
}

/// Dims the screen and circles one control at a time with a short
/// explanation (a "coach mark" tour). Steps whose widget is not on screen
/// are skipped. Completes when the user finishes or taps Skip.
Future<void> showSpotlightTour(BuildContext context, List<TourStep> steps) async {
  final visible = steps.where((s) => _rectOf(s.target) != null).toList();
  if (visible.isEmpty) return;
  await Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: false,
    barrierDismissible: false,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, _, _) => _TourOverlay(steps: visible),
    transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
  ));
}

Rect? _rectOf(GlobalKey key) {
  final box = key.currentContext?.findRenderObject();
  if (box is! RenderBox || !box.hasSize || !box.attached) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

class _TourOverlay extends StatefulWidget {
  const _TourOverlay({required this.steps});

  final List<TourStep> steps;

  @override
  State<_TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<_TourOverlay> with SingleTickerProviderStateMixin {
  int _index = 0;
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  bool get _last => _index == widget.steps.length - 1;

  void _next() => _last ? Navigator.of(context).pop() : setState(() => _index++);

  void _back() {
    if (_index > 0) setState(() => _index--);
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final size = MediaQuery.sizeOf(context);
    final target = _rectOf(step.target) ?? Rect.fromCenter(center: size.center(Offset.zero), width: 0, height: 0);
    final below = target.center.dy < size.height / 2;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _next,
              child: TweenAnimationBuilder<Rect?>(
                tween: RectTween(end: target),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeInOutCubic,
                builder: (context, rect, _) => AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => CustomPaint(
                    painter: _SpotlightPainter(rect: rect ?? target, pulse: _pulse.value),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: below ? math.min(target.bottom + 28, size.height - 260) : null,
            bottom: below ? null : math.min(size.height - target.top + 28, size.height - 260),
            child: SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _TourCard(
                  key: ValueKey(_index),
                  step: step,
                  index: _index,
                  count: widget.steps.length,
                  last: _last,
                  onNext: _next,
                  onBack: _index > 0 ? _back : null,
                  onSkip: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TourCard extends StatelessWidget {
  const _TourCard({
    super.key,
    required this.step,
    required this.index,
    required this.count,
    required this.last,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  final TourStep step;
  final int index;
  final int count;
  final bool last;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                  child: Icon(step.icon, size: 20, color: AppColors.brand),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(step.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(step.text, style: const TextStyle(fontSize: 15, height: 1.4, color: AppColors.inkMuted)),
            const SizedBox(height: 12),
            Semantics(
              label: 'Step ${index + 1} of $count',
              excludeSemantics: true,
              child: Row(
                children: [
                  for (var i = 0; i < count; i++)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      width: i == index ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == index ? AppColors.brand : AppColors.outline,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Text('${index + 1} of $count',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.inkMuted)),
                ],
              ),
            ),
            // Wraps onto a second line when the text is very large.
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 4,
              children: [
                if (!last) TextButton(onPressed: onSkip, child: const Text('Skip')),
                if (onBack != null) TextButton(onPressed: onBack, child: const Text('Back')),
                FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
                  child: Text(last ? 'Done' : 'Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dark scrim with a hole around the target: a circle for small controls,
/// a rounded rectangle for wide ones, with a pulsing ring.
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.rect, required this.pulse});

  final Rect rect;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final circle = rect.width <= 140 && rect.height <= 140;
    final RRect hole;
    if (circle) {
      final r = math.max(rect.width, rect.height) / 2 + 12;
      hole = RRect.fromRectAndRadius(Rect.fromCircle(center: rect.center, radius: r), Radius.circular(r));
    } else {
      hole = RRect.fromRectAndRadius(rect.inflate(8), const Radius.circular(22));
    }

    final scrim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(hole),
    );
    canvas.drawPath(scrim, Paint()..color = const Color(0xC70B1F1C));

    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
    final grow = 4 + 14 * pulse;
    canvas.drawRRect(
      hole.inflate(grow),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF9EF2E2).withValues(alpha: 1 - pulse),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.rect != rect || old.pulse != pulse;
}
