import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../theme/app_theme.dart';
import '../../utils/ez_dates.dart';

/// The pre-launch "Pre-Register Now" page. It is one screen: greeting and
/// headline on top, the offer and a live countdown in a floating card, a
/// three-step timeline, a feature strip — and the green button pinned at the
/// bottom so nobody has to scroll to find it. Every date and price comes from
/// the server's Early Bird settings.
class PrelaunchOfferView extends StatefulWidget {
  final String name; // first name, or '' if unknown
  final DateTime launch; // day the full app opens (India date)
  final DateTime firstDebit; // day the first payment is taken
  final String offerPrice; // e.g. "99"
  final String regularPrice; // e.g. "249"
  final bool paying;
  final VoidCallback onPay;

  const PrelaunchOfferView({
    super.key,
    required this.name,
    required this.launch,
    required this.firstDebit,
    required this.offerPrice,
    required this.regularPrice,
    required this.paying,
    required this.onPay,
  });

  @override
  State<PrelaunchOfferView> createState() => _PrelaunchOfferViewState();
}

class _PrelaunchOfferViewState extends State<PrelaunchOfferView> {
  static const _deepGreen = Color(0xFF14602F);
  Timer? _tick;
  Duration _left = Duration.zero;

  // Midnight at the start of the launch day, India time (UTC+5:30).
  DateTime get _launchMoment => DateTime.utc(
          widget.launch.year, widget.launch.month, widget.launch.day)
      .subtract(const Duration(hours: 5, minutes: 30));

  @override
  void initState() {
    super.initState();
    _update();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  void _update() {
    final d = _launchMoment.difference(DateTime.now().toUtc());
    if (!mounted) return;
    setState(() => _left = d.isNegative ? Duration.zero : d);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  int get _trialDays =>
      widget.firstDebit.difference(widget.launch).inDays.clamp(1, 365);

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final tight = h < 730; // small phones: drop the feature strip
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(children: [
        Expanded(
          child: Stack(children: [
            // Yellow top, fading into the page colour.
            Container(
              height: 270,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [C.yellow, C.yellow, C.bg],
                  stops: [0, .62, 1],
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                // Built to fit one screen; scrolls only on very small phones.
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Column(children: [
                  _top(),
                  const SizedBox(height: 12),
                  _offerCard(),
                  const SizedBox(height: 12),
                  _timeline(),
                  if (!tight) ...[
                    const SizedBox(height: 12),
                    _featureStrip(),
                  ],
                ]),
              ),
            ),
          ]),
        ),
        _bottomBar(),
      ]),
    );
  }

  // ── Greeting + headline ───────────────────────────────────────────────────
  Widget _top() {
    final hey = widget.name.isEmpty ? 'Hey there!' : 'Hey ${widget.name}!';
    return Column(children: [
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$hey 👋',
                style: poppins(15, w: FontWeight.w700, c: C.yellowDeep)),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Pre-register with\n'),
                TextSpan(
                    text: 'Zero Payment',
                    style: poppins(26, w: FontWeight.w900, c: _deepGreen, h: 1.1)),
              ]),
              style: poppins(24, w: FontWeight.w900, c: C.ink, h: 1.1),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        // Launch-day badge.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: C.ink,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('OPENS', style: poppins(10, w: FontWeight.w800, c: C.yellow)),
            Text('${widget.launch.day}',
                style: poppins(30, w: FontWeight.w900, c: Colors.white, h: 1.05)),
            Text(fmtDay(widget.launch).split(' ')[1].toUpperCase(),
                style: poppins(13, w: FontWeight.w800, c: C.yellow)),
          ]),
        ),
      ]),
    ]);
  }

  // ── Floating offer card: price + live countdown ───────────────────────────
  Widget _offerCard() {
    final d = _left.inDays;
    final hh = _left.inHours % 24;
    final m = _left.inMinutes % 60;
    final s = _left.inSeconds % 60;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.10),
              blurRadius: 22,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: C.yellow, borderRadius: BorderRadius.circular(9)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.card_giftcard_rounded, size: 15, color: C.red),
              const SizedBox(width: 5),
              Text('PRE-LAUNCH OFFER',
                  style: poppins(11, w: FontWeight.w800, c: C.ink)),
            ]),
          ),
          const Spacer(),
          const _EarlyBadge(),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text('₹${widget.regularPrice}',
              style: poppins(22, w: FontWeight.w800, c: C.txl, h: 1.1).copyWith(
                  decoration: TextDecoration.lineThrough,
                  decorationColor: C.red,
                  decorationThickness: 2.5)),
          const SizedBox(width: 10),
          const Icon(Icons.arrow_forward_rounded, color: C.txl, size: 22),
          const SizedBox(width: 10),
          Text('₹${widget.offerPrice}',
              style: poppins(42, w: FontWeight.w900, c: C.green, h: 1.0)),
          Padding(
            padding: const EdgeInsets.only(left: 3, top: 14),
            child: Text('/month',
                style: poppins(14, w: FontWeight.w700, c: C.ink)),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.rocket_launch_rounded, color: C.red, size: 18),
          const SizedBox(width: 6),
          Text('Launching on ${fmtDay(widget.launch)}',
              style: poppins(13, w: FontWeight.w800, c: C.ink)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _unit(d, 'Days'),
          const SizedBox(width: 8),
          _unit(hh, 'Hours'),
          const SizedBox(width: 8),
          _unit(m, 'Mins'),
          const SizedBox(width: 8),
          _unit(s, 'Secs'),
        ]),
      ]),
    );
  }

  Widget _unit(int v, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: C.yellowMid, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                      position: Tween<Offset>(
                              begin: const Offset(0, .35), end: Offset.zero)
                          .animate(a),
                      child: c)),
              child: Text(v.toString().padLeft(2, '0'),
                  key: ValueKey('$label$v'),
                  style: poppins(24, w: FontWeight.w900, c: C.ink, h: 1.1)),
            ),
            Text(label, style: poppins(11, w: FontWeight.w700, c: C.txm)),
          ]),
        ),
      );

  // ── Today → launch → first payment, in plain sentences (no tap needed) ───
  Widget _timeline() {
    Widget step(IconData i, Color c, String title, String line,
            {bool last = false}) =>
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 40,
              child: Column(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  child: Icon(i, size: 20, color: Colors.white),
                ),
                if (!last)
                  Expanded(
                      child: Container(width: 3, color: C.yellowBorder)),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 1, bottom: last ? 0 : 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: poppins(14.5, w: FontWeight.w800, c: C.ink, h: 1.2)),
                      Text(line,
                          style: poppins(13, w: FontWeight.w600, c: C.txm, h: 1.35)),
                    ]),
              ),
            ),
          ]),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: C.yellowLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.yellowBorder, width: 1.5),
      ),
      child: Column(children: [
        step(Icons.how_to_reg_rounded, C.green, 'Today',
            'Join free. Set up AutoPay once. Nothing is charged for the plan.'),
        step(Icons.celebration_rounded, C.orange, fmtDay(widget.launch),
            'The app opens. Your $_trialDays-day free trial starts.'),
        step(Icons.autorenew_rounded, C.blue, fmtDay(widget.firstDebit),
            '₹${widget.offerPrice} a month begins. Cancel anytime from your profile.',
            last: true),
      ]),
    );
  }

  // ── One-row feature strip (scrolls sideways, never down) ──────────────────
  Widget _featureStrip() {
    const items = <(IconData, Color, String)>[
      (Icons.directions_run_rounded, Color(0xFFEF8F00), 'Fitness'),
      (Icons.restaurant_rounded, Color(0xFFE53935), 'Food'),
      (Icons.medication_rounded, Color(0xFF2979FF), 'Medicine'),
      (Icons.personal_injury_rounded, Color(0xFFE53935), 'Fall alert'),
      (Icons.menu_book_rounded, Color(0xFF00897B), 'Learning'),
      (Icons.event_note_rounded, Color(0xFF5E5CE6), 'Routine'),
      (Icons.sentiment_satisfied_alt_rounded, Color(0xFFEF8F00), 'Happiness'),
      (Icons.verified_user_rounded, Color(0xFF22A85A), 'Independence'),
    ];
    return Column(children: [
      _Marquee(items: items.sublist(0, 4), reverse: false),
      const SizedBox(height: 8),
      _Marquee(items: items.sublist(4), reverse: true),
    ]);
  }

  // ── Pinned bottom bar ─────────────────────────────────────────────────────
  Widget _bottomBar() => Container(
        padding: EdgeInsets.fromLTRB(
            16, 10, 16, 8 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: C.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(.08),
                blurRadius: 16,
                offset: const Offset(0, -4)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(
            onTap: widget.paying ? null : widget.onPay,
            child: Container(
              width: double.infinity,
              height: 64,
              decoration: BoxDecoration(
                  color: _deepGreen,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: C.green.withOpacity(.35),
                        blurRadius: 12,
                        offset: const Offset(0, 5))
                  ]),
              child: Center(
                child: widget.paying
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: C.yellow, strokeWidth: 2.5))
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text('🎁', style: TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Pre-Register Now',
                                  style: poppins(18,
                                      w: FontWeight.w800,
                                      c: Colors.white,
                                      h: 1.15)),
                              Text('₹0 Payment',
                                  style: poppins(15,
                                      w: FontWeight.w800, c: C.yellow, h: 1.15)),
                            ]),
                        const SizedBox(width: 10),
                        const Icon(Icons.chevron_right_rounded,
                            color: Colors.white, size: 30),
                      ]),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('Secured by Razorpay · Cancel anytime from profile settings',
              textAlign: TextAlign.center,
              style: poppins(10.5, c: C.txl)),
        ]),
      );
}

/// "EARLY MEMBERS ONLY" — a pulsing orange badge with a sweeping shine, so the
/// eye goes to it first.
class _EarlyBadge extends StatefulWidget {
  const _EarlyBadge();
  @override
  State<_EarlyBadge> createState() => _EarlyBadgeState();
}

class _EarlyBadgeState extends State<_EarlyBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.scale(
          scale: 1 + .07 * t,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFF6D00), Color(0xFFE53935)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFFFF6D00).withOpacity(.25 + .3 * t),
                    blurRadius: 6 + 10 * t,
                    spreadRadius: 1 + 2 * t),
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.stars_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 5),
              Text('EARLY MEMBERS',
                  style: poppins(10.5, w: FontWeight.w800, c: Colors.white)),
            ]),
          ),
        );
      },
    );
  }
}

/// A row of feature chips that glides by on its own (left, or right when
/// [reverse]). It pauses while a finger is on it and picks up again after.
class _Marquee extends StatefulWidget {
  final List<(IconData, Color, String)> items;
  final bool reverse;
  const _Marquee({required this.items, required this.reverse});
  @override
  State<_Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<_Marquee>
    with SingleTickerProviderStateMixin {
  final _ctrl = ScrollController();
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;
  bool _held = false;
  Timer? _resume;
  static const _pxPerSecond = 34.0;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  void _onTick(Duration now) {
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (_held || !_ctrl.hasClients) return;
    _ctrl.jumpTo(_ctrl.offset + _pxPerSecond * dt);
  }

  void _hold() {
    _resume?.cancel();
    _held = true;
  }

  void _release() {
    _resume?.cancel();
    _resume = Timer(const Duration(milliseconds: 1500), () => _held = false);
  }

  @override
  void dispose() {
    _resume?.cancel();
    _ticker.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return SizedBox(
      height: 52,
      child: Listener(
        onPointerDown: (_) => _hold(),
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: ListView.builder(
          controller: _ctrl,
          reverse: widget.reverse,
          scrollDirection: Axis.horizontal,
          // Endless: the same chips repeat, so it never runs out.
          itemBuilder: (_, i) {
            final it = items[i % items.length];
            return Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: C.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: C.bd),
              ),
              child: Row(children: [
                Icon(it.$1, color: it.$2, size: 24),
                const SizedBox(width: 8),
                Text(it.$3, style: poppins(13, w: FontWeight.w700, c: C.ink)),
              ]),
            );
          },
        ),
      ),
    );
  }
}
