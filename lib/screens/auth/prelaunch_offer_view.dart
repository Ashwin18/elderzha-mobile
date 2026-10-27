import 'dart:async';

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/ez_dates.dart';

/// Body of the pre-launch "Pre-Register Now" page: the offer, a live launch
/// countdown, how the free period and billing work, and the features.
/// Everything comes from the server's Early Bird settings (launch date, first
/// payment date, price) — nothing here is typed in by hand.
class PrelaunchOfferView extends StatefulWidget {
  final DateTime launch; // day the full app opens (India date)
  final DateTime firstDebit; // day the first payment is taken
  final String offerPrice; // e.g. "99"
  final String regularPrice; // e.g. "249"
  final Widget featureGrid;

  const PrelaunchOfferView({
    super.key,
    required this.launch,
    required this.firstDebit,
    required this.offerPrice,
    required this.regularPrice,
    required this.featureGrid,
  });

  @override
  State<PrelaunchOfferView> createState() => _PrelaunchOfferViewState();
}

class _PrelaunchOfferViewState extends State<PrelaunchOfferView> {
  Timer? _tick;
  Duration _left = Duration.zero;
  bool _open = false; // "How it works" expanded

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
    final launchTxt = fmtDay(widget.launch);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _offerCard(launchTxt),
        const SizedBox(height: 12),
        _countdownCard(launchTxt),
        const SizedBox(height: 12),
        _howItWorks(launchTxt),
        const SizedBox(height: 12),
        _featuresCard(),
        const SizedBox(height: 12),
        _trialNote(),
        const SizedBox(height: 10),
        _billingNote(),
      ]),
    );
  }

  // ── Offer: struck-through regular price → early-member price ──────────────
  Widget _offerCard(String launchTxt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.yellowLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.yellowBorder, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: C.yellow, borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.card_giftcard_rounded, size: 18, color: C.red),
            const SizedBox(width: 6),
            Text('PRE-LAUNCH OFFER',
                style: poppins(12.5, w: FontWeight.w800, c: C.ink)),
          ]),
        ),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Column(children: [
            Text('₹${widget.regularPrice}',
                style: poppins(24,
                    w: FontWeight.w800,
                    c: C.txl,
                    h: 1.1)
                    .copyWith(
                        decoration: TextDecoration.lineThrough,
                        decorationColor: C.red,
                        decorationThickness: 2.5)),
            Text('Regular price', style: poppins(11.5, c: C.txm)),
          ]),
          Container(
              width: 1.5,
              height: 46,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              color: C.bd2),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('₹${widget.offerPrice}',
                        style: poppins(38,
                            w: FontWeight.w900, c: C.green, h: 1.05)),
                    Padding(
                      padding: const EdgeInsets.only(left: 3, bottom: 6),
                      child: Text('/month',
                          style: poppins(14, w: FontWeight.w700, c: C.ink)),
                    ),
                  ]),
              Text('For early members',
                  style: poppins(12.5, w: FontWeight.w700, c: C.green)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _miniTile(Icons.calendar_month_rounded, C.green,
              '$_trialDays-Day Free Trial', 'Enjoy the app from ${fmtDayShort(widget.launch)}'),
          const SizedBox(width: 8),
          _miniTile(Icons.sell_rounded, C.green,
              '₹${widget.offerPrice}/month', 'Instead of ₹${widget.regularPrice}/month'),
          const SizedBox(width: 8),
          _miniTile(Icons.workspace_premium_rounded, C.yellowDark, 'Full Access',
              'to all ElderZha features'),
        ]),
      ]),
    );
  }

  Widget _miniTile(IconData icon, Color c, String t, String s) => Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          decoration: BoxDecoration(
            color: C.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: C.bd),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: c, size: 24),
            const SizedBox(height: 6),
            Text(t,
                style: poppins(12, w: FontWeight.w800, c: C.ink, h: 1.2)),
            const SizedBox(height: 2),
            Text(s, style: poppins(10.5, c: C.txm, h: 1.25)),
          ]),
        ),
      );

  // ── Live countdown ────────────────────────────────────────────────────────
  Widget _countdownCard(String launchTxt) {
    final d = _left.inDays;
    final h = _left.inHours % 24;
    final m = _left.inMinutes % 60;
    final s = _left.inSeconds % 60;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.yellowLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.yellowBorder, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.rocket_launch_rounded, color: C.red, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Launching on $launchTxt',
                style: poppins(16, w: FontWeight.w800, c: C.ink, h: 1.2)),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _unit(d, 'Days'),
          const SizedBox(width: 8),
          _unit(h, 'Hours'),
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: C.yellow.withOpacity(.55),
              borderRadius: BorderRadius.circular(14)),
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
                  style: poppins(26, w: FontWeight.w900, c: C.ink, h: 1.1)),
            ),
            Text(label, style: poppins(11.5, w: FontWeight.w700, c: C.ink)),
          ]),
        ),
      );

  // ── Tap to see exactly what happens and when ─────────────────────────────
  Widget _howItWorks(String launchTxt) {
    Widget step(IconData i, Color c, String t, String s, {bool last = false}) =>
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              child: Icon(i, size: 18, color: Colors.white),
            ),
            if (!last)
              Container(width: 2, height: 30, color: C.bd2),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t,
                        style: poppins(13.5, w: FontWeight.w800, c: C.ink)),
                    Text(s, style: poppins(12, c: C.txm, h: 1.35)),
                  ]),
            ),
          ),
        ]);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.bd, width: 1.5),
      ),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const Icon(Icons.help_outline_rounded, color: C.yellowDeep),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('How does pre-registering work?',
                      style: poppins(14, w: FontWeight.w800, c: C.ink))),
              AnimatedRotation(
                turns: _open ? .5 : 0,
                duration: const Duration(milliseconds: 250),
                child: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
              ),
            ]),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState:
              _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Column(children: [
              step(Icons.how_to_reg_rounded, C.green, 'Today: pre-register',
                  'Nothing is charged for the plan. You set up AutoPay once.'),
              step(Icons.rocket_launch_rounded, C.orange,
                  '$launchTxt: app opens',
                  'Your $_trialDays-day free trial starts and every feature unlocks.'),
              step(Icons.autorenew_rounded, C.blue,
                  '${fmtDay(widget.firstDebit)}: subscription starts',
                  '₹${widget.offerPrice} a month by AutoPay. Cancel anytime from your profile settings.',
                  last: true),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _featuresCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.yellowLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: C.yellowBorder, width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Full access to all ElderZha features',
              style: poppins(15, w: FontWeight.w800, c: C.ink)),
          const SizedBox(height: 10),
          widget.featureGrid,
        ]),
      );

  Widget _noteBox(IconData icon, Color c, String t, String s) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.yellowMid,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.yellowBorder, width: 1.5),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: c, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t, style: poppins(14, w: FontWeight.w800, c: C.ink, h: 1.25)),
              const SizedBox(height: 2),
              Text(s, style: poppins(12, c: C.txm, h: 1.4)),
            ]),
          ),
        ]),
      );

  Widget _trialNote() => _noteBox(
        Icons.calendar_month_rounded,
        C.yellowDeep,
        '$_trialDays-Day Free Trial (${fmtDayShort(widget.launch)} to ${fmtDay(_trialEnd)})',
        'Pre-register now and enjoy the app free until ${fmtDay(_trialEnd)}.',
      );

  Widget _billingNote() => _noteBox(
        Icons.autorenew_rounded,
        C.yellowDeep,
        'Subscription starts from ${fmtDay(widget.firstDebit)}',
        'Continue enjoying ElderZha at ₹${widget.offerPrice}/month. '
            'Cancel anytime from your profile settings.',
      );
}
