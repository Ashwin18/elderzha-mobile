// lib/widgets/plan_status_card.dart
//
// Profile card showing the plan's start and end dates, how many days are
// left, and whether AutoPay will renew it — with a clear warning when the
// renewal is close, AutoPay is off, or the AutoPay payment failed.
import 'package:flutter/material.dart';

import '../navigation_key.dart';
import '../services/plan_state.dart';
import '../theme/app_theme.dart';
import '../utils/app_routes.dart';

class PlanStatusCard extends StatefulWidget {
  const PlanStatusCard({super.key});
  @override
  State<PlanStatusCard> createState() => _PlanStatusCardState();
}

class _PlanStatusCardState extends State<PlanStatusCard> {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    PlanState.loadStatus();
  }

  DateTime? _parse(dynamic v) {
    final t = v?.toString() ?? '';
    if (t.isEmpty || t == 'null') return null;
    return DateTime.tryParse(t.replaceFirst(' ', 'T'));
  }

  String _fmt(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PlanState.lapsed,
      builder: (context, lapsed, _) {
        return ValueListenableBuilder<Map<String, dynamic>?>(
          valueListenable: PlanState.status,
          builder: (context, s, __) => _build(context, s, lapsed),
        );
      },
    );
  }

  Widget _build(BuildContext context, Map<String, dynamic>? s, bool lapsed) {
    if (s == null && !lapsed) return const SizedBox.shrink();

    final start = _parse(s?['plan_purchased_date']);
    final end = _parse(s?['plan_expiry_date']);
    final now = DateTime.now();
    // Whole calendar days until the end date, so the app and the admin panel
    // always show the same number (14 Oct is 4 days after 10 Oct).
    final daysLeft = end == null
        ? null
        : DateTime(end.year, end.month, end.day)
            .difference(DateTime(now.year, now.month, now.day))
            .inDays;

    final autoState = '${s?['auto_pay_status']}'.toLowerCase();
    final rzpState = '${s?['razorpay_status']}'.toLowerCase();
    final autoOn = s?['auto_pay_enabled'] != false &&
        (autoState == 'active' ||
            rzpState == 'active' ||
            rzpState == 'authenticated');
    final failed = PlanState.autoPayFailed;
    final planType = '${s?['plan_type'] ?? ''}'.trim();
    final planName = planType.isEmpty
        ? 'Your plan'
        : '${planType[0].toUpperCase()}${planType.substring(1)} plan';

    // ── What to tell the user ────────────────────────────────────────────
    Color accent;
    Color tint;
    IconData icon;
    String headline;
    String detail;
    // Button under the card. Only shown when the user needs to act:
    // pay again (plan ended / AutoPay failed) or switch AutoPay on.
    String? buttonLabel;
    String buttonRoute = AppRoutes.subscriptionGate;

    if (lapsed || (daysLeft != null && daysLeft < 0)) {
      accent = C.red;
      tint = C.redLight;
      icon = Icons.error_outline_rounded;
      headline = failed ? 'AutoPay payment failed' : 'Plan ended';
      detail = 'Polls, activities and alarms are paused until you renew.';
      buttonLabel = 'Renew now';
    } else if (failed) {
      accent = C.red;
      tint = C.redLight;
      icon = Icons.credit_card_off_rounded;
      headline = 'AutoPay payment failed';
      detail = 'Pay now to avoid losing polls, activities and alarms'
          '${end != null ? ' after ${_fmt(end)}' : ''}.';
      buttonLabel = 'Pay now';
    } else if (daysLeft != null && daysLeft <= 5) {
      accent = C.orange;
      tint = C.orangeLight;
      icon = Icons.schedule_rounded;
      final when = daysLeft <= 0
          ? 'today'
          : daysLeft == 1
              ? 'tomorrow'
              : 'in $daysLeft days';
      if (autoOn) {
        headline = 'Renews $when';
        detail = 'AutoPay will charge your payment method on '
            '${end != null ? _fmt(end) : 'the renewal date'}. '
            'Keep enough balance ready.';
      } else {
        headline = 'Plan ends $when';
        detail = 'We could not find an active AutoPay for this plan, so it '
            'may not renew by itself. You can manage AutoPay in Profile.';
      }
    } else if (autoOn) {
      accent = C.green;
      tint = C.greenLight;
      icon = Icons.autorenew_rounded;
      headline = 'AutoPay is on';
      detail = end != null
          ? 'Your plan renews automatically on ${_fmt(end)}.'
          : 'Your plan renews automatically.';
    } else {
      accent = C.txm;
      tint = C.bg2;
      icon = Icons.autorenew_rounded;
      headline = end != null ? 'Plan active until ${_fmt(end)}' : 'Plan active';
      detail = 'We could not confirm an active AutoPay for this plan. '
          'You can manage AutoPay in Profile.';
    }

    // Share of the plan period already used (for the progress bar).
    double? used;
    if (start != null && end != null && end.isAfter(start)) {
      used = (now.difference(start).inMinutes /
              end.difference(start).inMinutes)
          .clamp(0.0, 1.0);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.bd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(planName,
                    style: poppins(16, w: FontWeight.w800)),
              ),
              if (daysLeft != null && daysLeft >= 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    daysLeft == 0
                        ? 'Last day'
                        : '$daysLeft day${daysLeft == 1 ? '' : 's'} left',
                    style: poppins(11, w: FontWeight.w700, c: accent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _date('Started', start)),
              Expanded(child: _date(lapsed ? 'Ended' : 'Ends', end)),
            ],
          ),
          if (used != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: lapsed ? 1 : used,
                minHeight: 6,
                backgroundColor: C.bg3,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(headline,
                          style: poppins(13, w: FontWeight.w700, c: accent)),
                      const SizedBox(height: 2),
                      Text(detail, style: poppins(12, c: C.txm, h: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (buttonLabel != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () =>
                  appNavigatorKey.currentState?.pushNamed(buttonRoute),
              child: Container(
                width: double.infinity,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: C.ink,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(buttonLabel!,
                    style: poppins(14, w: FontWeight.w700, c: Colors.white)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _date(String label, DateTime? d) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: poppins(11, c: C.txl)),
          Text(d == null ? '—' : _fmt(d),
              style: poppins(13, w: FontWeight.w700)),
        ],
      );
}
