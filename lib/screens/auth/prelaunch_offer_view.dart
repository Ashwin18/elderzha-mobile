import 'dart:async';

import 'package:flutter/material.dart';
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
  DateTime get _trialEnd => widget.firstDebit.subtract(const Duration(days: 1));

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final tight = h < 690; // small phones: drop the feature strip
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(children: [
        Expanded(
          child: Stack(children: [
            // Yellow top, fading into the page colour.
            Container(
              height: 300,
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
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: _showDetails,
                    child: Text('How does pre-registering work?',
                        style: poppins(13,
                                w: FontWeight.w700, c: C.yellowDeep)
                            .copyWith(decoration: TextDecoration.underline)),
                  ),
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
      Image.asset('assets/images/logo.png',
          height: 40,
          errorBuilder: (_, __, ___) =>
              Text('ElderZha', style: poppins(22, w: FontWeight.w800, c: C.ink))),
      const SizedBox(height: 8),
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
          Text('Early members only',
              style: poppins(11, w: FontWeight.w600, c: C.txm)),
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

  // ── Today → launch → first payment ────────────────────────────────────────
  Widget _timeline() {
    Widget node(IconData i, Color c, String top, String bottom) => Expanded(
          child: Column(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(color: C.white, width: 3)),
              child: Icon(i, size: 20, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(top,
                textAlign: TextAlign.center,
                style: poppins(12.5, w: FontWeight.w800, c: C.ink, h: 1.2)),
            Text(bottom,
                textAlign: TextAlign.center,
                style: poppins(11, w: FontWeight.w600, c: C.txm, h: 1.25)),
          ]),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
      decoration: BoxDecoration(
        color: C.yellowLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.yellowBorder, width: 1.5),
      ),
      child: Stack(children: [
        // connecting line behind the three circles
        Positioned(
          top: 19,
          left: 52,
          right: 52,
          child: Container(height: 3, color: C.yellowBorder),
        ),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          node(Icons.how_to_reg_rounded, C.green, 'Today', '₹0 to join'),
          node(Icons.celebration_rounded, C.orange,
              fmtDayShort(widget.launch), '$_trialDays-day free trial'),
          node(Icons.autorenew_rounded, C.blue, fmtDayShort(widget.firstDebit),
              '₹${widget.offerPrice}/month starts'),
        ]),
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
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: C.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: C.bd),
          ),
          child: Row(children: [
            Icon(items[i].$1, color: items[i].$2, size: 24),
            const SizedBox(width: 8),
            Text(items[i].$3,
                style: poppins(12.5, w: FontWeight.w700, c: C.ink)),
          ]),
        ),
      ),
    );
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

  // ── Details sheet (kept out of the main screen) ───────────────────────────
  void _showDetails() {
    Widget row(IconData i, Color c, String t, String s) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              child: Icon(i, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t, style: poppins(14, w: FontWeight.w800, c: C.ink)),
                    Text(s, style: poppins(12.5, c: C.txm, h: 1.4)),
                  ]),
            ),
          ]),
        );

    showModalBottomSheet(
      context: context,
      backgroundColor: C.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: C.bd2, borderRadius: BorderRadius.circular(4))),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('How pre-registering works',
                  style: poppins(18, w: FontWeight.w800, c: C.ink)),
            ),
            const SizedBox(height: 14),
            row(Icons.how_to_reg_rounded, C.green, 'Today: pre-register',
                'Nothing is charged for the plan. You set up AutoPay once. '
                'Your bank may take ₹1 to ₹5 for the set-up and refunds it.'),
            row(Icons.celebration_rounded, C.orange,
                '${fmtDay(widget.launch)}: app opens',
                'Your $_trialDays-day free trial runs until ${fmtDay(_trialEnd)} '
                'and every feature unlocks.'),
            row(Icons.autorenew_rounded, C.blue,
                '${fmtDay(widget.firstDebit)}: subscription starts',
                '₹${widget.offerPrice} a month by AutoPay instead of '
                '₹${widget.regularPrice}. Cancel anytime from your profile settings.'),
            const SizedBox(height: 4),
          ]),
        ),
      ),
    );
  }
}
