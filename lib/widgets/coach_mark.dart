// lib/widgets/coach_mark.dart
//
// A small, reusable "coach mark" / feature-spotlight overlay: dims the
// screen except for one target widget at a time, with a caption card
// and Next/Skip controls. Used to give first-time users a short guided
// tour of a screen's main areas.
//
// Deliberately senior-friendly: no auto-advancing (the user taps
// "Next" at their own pace), no flashy animation beyond a gentle
// fade-in, large tap targets, and "Skip" is always visible. Each tour
// only ever shows once per device (tracked in SharedPreferences via
// the prefsKey passed to maybeShow) unless that key is cleared.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class CoachMarkStep {
  final GlobalKey targetKey;
  final String title;
  final String message;
  final double borderRadius;
  final EdgeInsets padding;

  const CoachMarkStep({
    required this.targetKey,
    required this.title,
    required this.message,
    this.borderRadius = 18,
    this.padding = const EdgeInsets.all(8),
  });
}

class CoachMarkTour {
  CoachMarkTour._();

  /// Shows [steps] as a one-time guided tour, gated by [prefsKey] in
  /// SharedPreferences so it never shows twice on the same device.
  /// Safe to call unconditionally from a screen's initState (via a
  /// post-frame callback) — it's a no-op once the tour has been seen.
  static Future<void> maybeShow({
    required BuildContext context,
    required String prefsKey,
    required List<CoachMarkStep> steps,
    Duration settleDelay = const Duration(milliseconds: 450),
  }) async {
    if (steps.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(prefsKey) == true) return;

    // Give the screen's first frame(s) time to lay out and for any
    // async data (which can shift widget positions) to settle before
    // measuring target positions.
    await Future.delayed(settleDelay);
    if (!context.mounted) return;

    await prefs.setBool(prefsKey, true);

    final overlayState = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CoachMarkOverlay(
        steps: steps,
        onFinished: () => entry.remove(),
      ),
    );
    overlayState.insert(entry);
  }
}

class _CoachMarkOverlay extends StatefulWidget {
  final List<CoachMarkStep> steps;
  final VoidCallback onFinished;
  const _CoachMarkOverlay({required this.steps, required this.onFinished});

  @override
  State<_CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<_CoachMarkOverlay> {
  int _index = 0;
  Rect? _rect;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  Future<void> _measure() async {
    setState(() => _ready = false);
    final step = widget.steps[_index];
    final ctx = step.targetKey.currentContext;
    if (ctx != null) {
      // Bring the target on-screen first, in case it's below the fold.
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        alignment: 0.2,
      );
      await Future.delayed(const Duration(milliseconds: 80));
    }
    if (!mounted) return;
    final renderCtx = step.targetKey.currentContext;
    if (renderCtx == null) {
      // Target never rendered (e.g. not part of this build) — skip it
      // rather than getting stuck.
      _advance();
      return;
    }
    final box = renderCtx.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero);
    if (!mounted) return;
    setState(() {
      _rect = topLeft & box.size;
      _ready = true;
    });
  }

  void _advance() {
    if (_index >= widget.steps.length - 1) {
      widget.onFinished();
      return;
    }
    setState(() => _index += 1);
    _measure();
  }

  void _skip() => widget.onFinished();

  @override
  Widget build(BuildContext context) {
    if (!_ready || _rect == null) return const SizedBox.shrink();
    final step = widget.steps[_index];
    final screen = MediaQuery.of(context).size;
    final target = step.padding.inflateRect(_rect!);
    final isLast = _index == widget.steps.length - 1;

    // Card goes below the target if there's room, otherwise above it.
    final spaceBelow = screen.height - target.bottom;
    final cardBelow = spaceBelow > 190 || target.top < 190;

    return Material(
      color: Colors.transparent,
      child: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {}, // absorb taps outside the card — Skip is explicit
            child: CustomPaint(
              painter: _SpotlightPainter(
                rect: target,
                radius: step.borderRadius,
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          top: cardBelow
              ? (target.bottom + 16).clamp(0.0, screen.height - 220)
              : null,
          bottom: cardBelow ? null : (screen.height - target.top + 16),
          child: TweenAnimationBuilder<double>(
            key: ValueKey(_index),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * 8),
                child: child,
              ),
            ),
            child: _CoachMarkCard(
              step: step,
              index: _index,
              total: widget.steps.length,
              isLast: isLast,
              onNext: _advance,
              onSkip: _skip,
            ),
          ),
        ),
      ]),
    );
  }
}

class _CoachMarkCard extends StatelessWidget {
  final CoachMarkStep step;
  final int index;
  final int total;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _CoachMarkCard({
    required this.step,
    required this.index,
    required this.total,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: C.ink.withOpacity(.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: C.yellowMid,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text('${index + 1}',
                    style: poppins(12, w: FontWeight.w800, c: C.yellowDeep)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(step.title,
                  style: poppins(15, w: FontWeight.w800, c: C.ink)),
            ),
            GestureDetector(
              onTap: onSkip,
              child: Text('Skip',
                  style: poppins(12.5, w: FontWeight.w700, c: C.txl)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(step.message, style: poppins(13, c: C.txm, h: 1.45)),
          const SizedBox(height: 14),
          Row(children: [
            Row(
              children: List.generate(
                total,
                (i) => Container(
                  margin: const EdgeInsets.only(right: 5),
                  width: i == index ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == index ? C.yellowDark : C.bd,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onNext,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: C.ink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(isLast ? 'Got it' : 'Next',
                    style: poppins(13, w: FontWeight.w700, c: C.yellow)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect rect;
  final double radius;
  _SpotlightPainter({required this.rect, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Paint()..color = Colors.black.withOpacity(0.62);
    final full = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final cut = Path.combine(PathOperation.difference, full, hole);
    canvas.drawPath(cut, scrim);

    // A soft gold ring around the spotlighted area for extra clarity.
    final ring = Paint()
      ..color = C.yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      ring,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.rect != rect || oldDelegate.radius != radius;
}
