// lib/screens/home/prelaunch_home.dart
//
// Early Bird launch screen. Shown on the Home tab (instead of the normal
// Home) from the day someone joins with the Early Bird promo code until the
// launch day the server gives us. It counts down to launch, reminds them of
// the free trial and the first payment date, and lets them manage AutoPay.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/plan_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_routes.dart';
import '../../utils/ez_dates.dart';
import '../auth/benefits_showcase_screen.dart';

class PreLaunchHome extends StatefulWidget {
  const PreLaunchHome({super.key});

  @override
  State<PreLaunchHome> createState() => _PreLaunchHomeState();
}

class _PreLaunchHomeState extends State<PreLaunchHome> {
  Timer? _tick;
  bool _asked = false;

  @override
  void initState() {
    super.initState();
    // Re-read the trial details when this screen opens (dates may have been
    // changed in admin), then keep the countdown moving.
    PlanState.loadStatus();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {});
      final launch = _launch;
      // Launch day has arrived: ask the server, which switches Home over.
      if (launch != null && !DateTime.now().isBefore(launch) && !_asked) {
        _asked = true;
        PlanState.loadStatus();
      }
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

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AuthProvider>().userName;
    final launch = _launch;
    final firstPay = _firstPay;
    final amount = '${_t['first_payment_display'] ?? ''}';
    var left = launch == null ? Duration.zero : launch.difference(DateTime.now());
    if (left.isNegative) left = Duration.zero;
    final days = left.inDays;
    final hours = left.inHours % 24;
    final mins = left.inMinutes % 60;

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
                      style: poppins(20, w: FontWeight.w800, c: C.ink),
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
                        style:
                            poppins(11, w: FontWeight.w700, c: C.yellow)),
                  ),
                ]),
                const SizedBox(height: 16),

                // ── Countdown ────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                  decoration: BoxDecoration(
                    color: C.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: C.yellowBorder),
                  ),
                  child: Column(children: [
                    Text(
                        launch == null
                            ? 'ElderZha is launching soon'
                            : 'ElderZha opens in',
                        style: poppins(13, w: FontWeight.w600, c: C.txm)),
                    if (launch != null) ...[
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _box('$days', days == 1 ? 'Day' : 'Days'),
                          const SizedBox(width: 10),
                          _box('$hours', 'Hrs'),
                          const SizedBox(width: 10),
                          _box('$mins', 'Min'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text('Launch day · ${fmtDay(launch)}',
                          style: poppins(13, w: FontWeight.w700, c: C.ink)),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Everything unlocks on launch day — your alarms, polls, '
                      'community and more. Nothing for you to do.',
                      textAlign: TextAlign.center,
                      style: poppins(12, c: C.txm, h: 1.45),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),

                // ── Early Bird details ───────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: C.yellowMid,
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
                              style: poppins(14,
                                  w: FontWeight.w800, c: C.ink)),
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
                const SizedBox(height: 18),

                Text(
                    launch == null
                        ? 'What opens on launch day'
                        : 'What opens on ${fmtDayShort(launch)}',
                    style: poppins(15, w: FontWeight.w800, c: C.ink)),
                const SizedBox(height: 10),
                const BenefitsList(unlocked: false),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _box(String value, String label) => Container(
        width: 78,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            color: C.ink, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Text(value,
              style: poppins(28, w: FontWeight.w800, c: C.yellow, h: 1.1)),
          const SizedBox(height: 2),
          Text(label, style: poppins(11, w: FontWeight.w600, c: C.white)),
        ]),
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
