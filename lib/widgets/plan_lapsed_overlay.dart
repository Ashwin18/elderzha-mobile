// lib/widgets/plan_lapsed_overlay.dart
//
// Wraps the whole app. While the plan is lapsed (expired, or an AutoPay
// payment failed) the screen underneath is blurred and a "Renew" card sits
// on top, every time the app opens. Alarms are paused by PlanState at the
// same moment. Payment, subscription and sign-up screens are never covered.
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../navigation_key.dart';
import '../services/plan_state.dart';
import '../theme/app_theme.dart';
import '../utils/app_routes.dart';

class PlanLapsedHost extends StatelessWidget {
  final Widget child;
  const PlanLapsedHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PlanState.lapsed,
      builder: (context, lapsed, _) {
        return ValueListenableBuilder<String>(
          valueListenable: PlanState.routeName,
          builder: (context, route, __) {
            final show = lapsed && PlanState.coveredRoutes.contains(route);
            return Stack(
              children: [
                child,
                if (show) const Positioned.fill(child: _LapsedOverlay()),
              ],
            );
          },
        );
      },
    );
  }
}

class _LapsedOverlay extends StatefulWidget {
  const _LapsedOverlay();
  @override
  State<_LapsedOverlay> createState() => _LapsedOverlayState();
}

class _LapsedOverlayState extends State<_LapsedOverlay> {
  bool _checking = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    // Make sure the wording (ended vs. AutoPay failed) is up to date.
    PlanState.loadStatus();
  }

  Future<void> _checkAgain() async {
    setState(() {
      _checking = true;
      _msg = null;
    });
    final answered = await PlanState.refresh(force: true);
    if (!mounted) return;
    setState(() {
      _checking = false;
      if (!answered) {
        _msg = 'Could not check right now. Please check your internet '
            'connection and try again.';
      } else if (PlanState.lapsed.value) {
        _msg = 'We could not find an active plan yet. If you just paid, '
            'please wait a minute and try again.';
      }
    });
  }

  void _renew() {
    appNavigatorKey.currentState?.pushNamed(AppRoutes.subscriptionGate);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: PlanState.status,
      builder: (context, _, __) {
        final failed = PlanState.autoPayFailed;
        final title =
            failed ? 'AutoPay payment failed' : 'Your subscription has ended';
        final body = failed
            ? 'We could not collect your AutoPay payment. Until you pay, '
                'polls, activities and your alarms are paused.'
            : 'Until you renew, polls, activities and your alarms are paused.';
        return Material(
          type: MaterialType.transparency,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
            child: Container(
              color: C.ink.withOpacity(.45),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                    decoration: BoxDecoration(
                      color: C.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: failed ? C.redLight : C.yellowMid,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            failed
                                ? Icons.credit_card_off_rounded
                                : Icons.lock_clock_rounded,
                            size: 30,
                            color: failed ? C.red : C.yellowDeep,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(title,
                            textAlign: TextAlign.center,
                            style: poppins(20, w: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(body,
                            textAlign: TextAlign.center,
                            style: poppins(13, c: C.txm)),
                        const SizedBox(height: 8),
                        Text(
                            'Everything you set up is saved. Your alarms start '
                            'ringing again as soon as you subscribe.',
                            textAlign: TextAlign.center,
                            style: poppins(12, c: C.txl)),
                        const SizedBox(height: 18),
                        GestureDetector(
                          onTap: _renew,
                          child: Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              color: C.ink,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: Text('Renew now',
                                style: poppins(15,
                                    w: FontWeight.w700, c: Colors.white)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: _checking ? null : _checkAgain,
                          child: Container(
                            width: double.infinity,
                            height: 44,
                            alignment: Alignment.center,
                            child: _checking
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: C.yellowDark))
                                : Text('I already paid — check again',
                                    style: poppins(13,
                                        w: FontWeight.w600,
                                        c: C.yellowDeep)),
                          ),
                        ),
                        if (_msg != null) ...[
                          const SizedBox(height: 6),
                          Text(_msg!,
                              textAlign: TextAlign.center,
                              style: poppins(12, c: C.red)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
