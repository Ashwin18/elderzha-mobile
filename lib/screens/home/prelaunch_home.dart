// lib/screens/home/prelaunch_home.dart
//
// Early Bird launch screen. Shown on the Home tab (instead of the normal
// Home) from the day someone joins with the Early Bird promo code until the
// launch day the server gives us. It counts down to launch (days, hours,
// minutes, seconds), shows what is waiting, reminds them of the free trial
// and first payment date, and lets them manage AutoPay.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/plan_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_routes.dart';
import '../../utils/ez_dates.dart';

class PreLaunchHome extends StatefulWidget {
  const PreLaunchHome({super.key});

  @override
  State<PreLaunchHome> createState() => _PreLaunchHomeState();
}

class _PreLaunchHomeState extends State<PreLaunchHome> {
  Timer? _tick;
  bool _asked = false;
  int _n = 0;

  @override
  void initState() {
    super.initState();
    // Re-read the trial details when this screen opens (dates may have been
    // changed in admin), then keep the countdown moving every second.
    PlanState.loadStatus();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _n++);
      final launch = _launch;
      // Launch day has arrived: ask the server, which switches Home over.
      if (launch != null && !DateTime.now().isBefore(launch) && !_asked) {
        _asked = true;
        PlanState.loadStatus();
      }
      // Safety net: ask again every few minutes in case the date changed.
      if (_n % 300 == 0) PlanState.loadStatus();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Map<String, dynamic> get _t => PlanState.trial.value ?? const {};
  DateTime? get _launch => parseYmd(_t['launch_date']);
  DateTime? get _firstPay => parseYmd(_t['first_debit_date']);

  Future<void> _refresh() async {
    await PlanState.loadStatus();
  }

  static const _waiting = <(IconData, Color, Color, String)>[
    (Icons.alarm_rounded, Color(0xFFE6F1FB), Color(0xFF0C447C), 'Alarms &\nReminders'),
    (Icons.self_improvement_rounded, Color(0xFFEAF3DE), Color(0xFF27500A), 'Fitness\n& Yoga'),
    (Icons.emoji_events_rounded, Color(0xFFEEEDFE), Color(0xFF3C3489), 'Activities\n& Polls'),
    (Icons.shield_rounded, Color(0xFFE3F5EC), Color(0xFF0F6B3A), 'Safety\nSOS Alert'),
    (Icons.card_giftcard_rounded, Color(0xFFFAEEDA), Color(0xFF854F0B), 'Offers\n& More'),
  ];

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AuthProvider>().userName;
    final launch = _launch;
    final firstPay = _firstPay;
    final amount = '${_t['first_payment_display'] ?? ''}';
    var left = launch == null ? Duration.zero : launch.difference(DateTime.now());
    if (left.isNegative) left = Duration.zero;
    String two(int v) => v.toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: C.bgGradient),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _refresh,
            color: C.yellowDark,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      name.trim().isEmpty ? 'Welcome 👋' : 'Hello, $name 👋',
                      style: poppins(15, w: FontWeight.w700, c: C.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: C.ink, borderRadius: BorderRadius.circular(999)),
                    child: Text('Early Bird',
                        style: poppins(11, w: FontWeight.w700, c: C.yellow)),
                  ),
                ]),
                const SizedBox(height: 14),
                Text('ElderZha is coming soon!',
                    textAlign: TextAlign.center,
                    style: poppins(24, w: FontWeight.w800, c: C.ink, h: 1.2)),
                const SizedBox(height: 14),

                // ── Launch date banner ───────────────────────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                      color: C.ink, borderRadius: BorderRadius.circular(18)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_month_rounded,
                          color: C.yellow, size: 30),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('LAUNCHING ON',
                              style: poppins(10.5,
                                  w: FontWeight.w700, c: C.yellow)),
                          Text(
                              launch != null ? fmtDayLong(launch) : 'Soon',
                              style: poppins(19,
                                  w: FontWeight.w800, c: C.white, h: 1.2)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your journey to a healthier, safer and happier life begins soon.',
                  textAlign: TextAlign.center,
                  style: poppins(12.5, c: C.txm, h: 1.4),
                ),
                const SizedBox(height: 14),

                // ── Countdown ────────────────────────────────────────────
                if (launch != null)
                  Row(children: [
                    _box('${left.inDays}', left.inDays == 1 ? 'Day' : 'Days'),
                    const SizedBox(width: 8),
                    _box(two(left.inHours % 24), 'Hours'),
                    const SizedBox(width: 8),
                    _box(two(left.inMinutes % 60), 'Minutes'),
                    const SizedBox(width: 8),
                    _box(two(left.inSeconds % 60), 'Seconds'),
                  ]),
                const SizedBox(height: 16),

                // ── Hero picture ─────────────────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 1600 / 717,
                    child: Container(
                      color: C.yellow,
                      child: Image.asset(
                        'assets/images/home_header_photo_v3.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // ── What is waiting ──────────────────────────────────────
                Text("Here's what's waiting for you",
                    style: poppins(15, w: FontWeight.w800, c: C.ink)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final w in _waiting)
                      Expanded(
                        child: Column(children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                                color: w.$2,
                                borderRadius: BorderRadius.circular(14)),
                            child: Icon(w.$1, color: w.$3, size: 24),
                          ),
                          const SizedBox(height: 6),
                          Text(w.$4,
                              textAlign: TextAlign.center,
                              style: poppins(9.5,
                                  w: FontWeight.w600, c: C.txm, h: 1.25)),
                        ]),
                      ),
                  ],
                ),
                const SizedBox(height: 18),

                // ── Stay tuned ───────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: C.yellow, borderRadius: BorderRadius.circular(18)),
                  child: Row(children: [
                    const Icon(Icons.notifications_active_rounded,
                        color: C.ink, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Stay Tuned',
                              style: poppins(15, w: FontWeight.w800, c: C.ink)),
                          Text("We'll let you know the moment ElderZha opens.",
                              style: poppins(12, c: C.ink, h: 1.35)),
                        ],
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),

                // ── Early Bird details ───────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: C.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: C.yellowBorder),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.card_giftcard_rounded,
                              size: 20, color: C.yellowDeep),
                          const SizedBox(width: 8),
                          Text("You're an Early Bird",
                              style: poppins(14, w: FontWeight.w800, c: C.ink)),
                        ]),
                        const SizedBox(height: 10),
                        _line(Icons.check_circle_rounded, C.green,
                            firstPay == null
                                ? 'Free trial is on — nothing to pay today'
                                : 'Free until ${fmtDay(firstPay)} — nothing to pay today'),
                        const SizedBox(height: 6),
                        _line(
                            Icons.autorenew_rounded,
                            C.yellowDeep,
                            firstPay == null
                                ? 'Your first payment is taken automatically by AutoPay'
                                : '${amount.isEmpty ? 'Your first payment' : 'First payment $amount'} on ${fmtDay(firstPay)}, by AutoPay'),
                        const SizedBox(height: 6),
                        _line(Icons.cancel_outlined, C.txm,
                            'Cancel any time before then and you will not be charged'),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: () => Navigator.of(context)
                              .pushNamed(AppRoutes.autopaySettings),
                          child: Container(
                            width: double.infinity,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: C.ink,
                                borderRadius: BorderRadius.circular(14)),
                            child: Text('Manage AutoPay',
                                style: poppins(13,
                                    w: FontWeight.w700, c: Colors.white)),
                          ),
                        ),
                      ]),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(context).pushNamed('/support'),
                  child: Text('Need help? Contact support',
                      style: poppins(12.5, w: FontWeight.w700, c: C.txm)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _box(String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: C.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: C.yellowBorder),
          ),
          child: Column(children: [
            Text(value,
                style: poppins(24, w: FontWeight.w800, c: C.ink, h: 1.1)),
            const SizedBox(height: 2),
            Text(label, style: poppins(10.5, w: FontWeight.w600, c: C.txm)),
          ]),
        ),
      );

  Widget _line(IconData icon, Color color, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: poppins(12.5, w: FontWeight.w600, c: C.ink, h: 1.4))),
        ],
      );
}
