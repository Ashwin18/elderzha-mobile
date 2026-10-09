// lib/services/plan_state.dart
//
// One place that knows whether the user's plan is lapsed (expired, or an
// AutoPay payment failed) and what the app does about it:
//
//   lapsed  -> the app is shown blurred with a "Renew" prompt every time it
//              opens, and the phone's alarms are PAUSED (nothing rings).
//   renewed -> the prompt goes away and the alarms come back exactly as the
//              user set them.
//
// "Lapsed" is only ever decided from a clear answer from the server. A
// failed request, a timeout or a strange reply means "don't know" and never
// locks anyone out or silences their alarms.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../navigation_key.dart';
import '../utils/app_routes.dart';
import 'subscription_service.dart';

const MethodChannel _planAlarmChannel = MethodChannel('alarm_service');

class PlanState {
  PlanState._();

  /// True while the plan is lapsed. The blurred "Renew" overlay listens.
  static final ValueNotifier<bool> lapsed = ValueNotifier<bool>(false);

  /// Latest /user/subscription/status data (null until fetched).
  static final ValueNotifier<Map<String, dynamic>?> status =
      ValueNotifier<Map<String, dynamic>?>(null);

  /// Name of the screen currently on top (kept by [PlanRouteObserver]).
  static final ValueNotifier<String> routeName = ValueNotifier<String>('');

  /// True while Razorpay checkout is open. Plan checks wait until it is over
  /// so returning from a UPI app can never be mistaken for "not paid".
  static bool paymentInFlight = false;

  static bool _refreshing = false;
  static DateTime? _lastRefresh;

  /// Screens where the blurred overlay is drawn. Payment / subscription /
  /// sign-up screens are deliberately NOT here, so the user can always get
  /// to them.
  static const Set<String> coveredRoutes = {
    AppRoutes.home,
    AppRoutes.reminder,
    AppRoutes.checkIn,
    AppRoutes.notifications,
    AppRoutes.profile,
    AppRoutes.alarms,
    AppRoutes.familyMembers,
    AppRoutes.familyTree,
    AppRoutes.addMember,
    AppRoutes.editProfile,
    AppRoutes.polls,
    AppRoutes.offers,
    AppRoutes.community,
  };

  /// Asks the server whether the plan is active and updates the app to
  /// match. Safe to call often (throttled).
  static Future<bool> refresh({bool force = false}) async {
    if (_refreshing || paymentInFlight) return false;
    final last = _lastRefresh;
    if (!force &&
        last != null &&
        DateTime.now().difference(last).inSeconds < 20) {
      return false;
    }
    _refreshing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if ((prefs.getString('auth_token') ?? '').isEmpty) {
        lapsed.value = false;
        return false;
      }
      final svc = SubscriptionService();
      // A payment taken earlier but never confirmed: finish it first, so a
      // user who really paid is never shown the "renew" prompt.
      if (await SubscriptionService.hasPendingPayment()) {
        await svc.retryPendingConfirm();
      }
      final active = await svc.definitivePlanStatus();
      _lastRefresh = DateTime.now();
      if (active == true) {
        await markActive();
      } else if (active == false) {
        await markLapsed();
      }
      // null -> couldn't tell: leave everything exactly as it is.
      return active != null;
    } catch (_) {
      return false; // leave state as it is
    } finally {
      _refreshing = false;
    }
  }

  /// The server clearly says the plan is not active.
  static Future<void> markLapsed() async {
    final wasLapsed = lapsed.value;
    lapsed.value = true;
    try {
      await _planAlarmChannel.invokeMethod('pauseAlarms');
    } catch (_) {}
    if (!wasLapsed) {
      // If the user was deep inside the app, bring them back to Home so the
      // blurred prompt covers what they see.
      final nav = appNavigatorKey.currentState;
      if (nav != null && coveredRoutes.contains(routeName.value)) {
        nav.popUntil((r) =>
            r.settings.name == AppRoutes.home || r.isFirst);
      }
    }
    unawaited(loadStatus());
  }

  /// The plan is active (server confirmed, or a payment just went through).
  static Future<void> markActive() async {
    lapsed.value = false;
    try {
      final paused = await _planAlarmChannel.invokeMethod('alarmsPaused');
      if (paused == true) {
        await _planAlarmChannel.invokeMethod('resumeAlarms');
      }
    } catch (_) {}
    unawaited(loadStatus());
  }

  /// Fetches the AutoPay / plan-dates status for the Profile card and the
  /// overlay wording.
  static Future<void> loadStatus() async {
    final s = await SubscriptionService().getAutoPayStatus();
    if (s != null) status.value = s;
  }

  /// Logout: forget everything and let the next account start clean.
  static Future<void> reset() async {
    lapsed.value = false;
    status.value = null;
    _lastRefresh = null;
    try {
      final paused = await _planAlarmChannel.invokeMethod('alarmsPaused');
      if (paused == true) {
        await _planAlarmChannel.invokeMethod('resumeAlarms');
      }
    } catch (_) {}
  }

  /// True when the last known AutoPay state is "payment failed".
  static bool get autoPayFailed {
    final s = status.value;
    if (s == null) return false;
    final a = '${s['auto_pay_status']}'.toLowerCase();
    final r = '${s['razorpay_status']}'.toLowerCase();
    return a == 'halted' || a == 'failed' || r == 'halted';
  }
}

/// Keeps [PlanState.routeName] up to date. Only full-screen pages count —
/// dialogs, bottom sheets and popups (which have no name) must not make the
/// Renew prompt disappear while they are open.
class PlanRouteObserver extends NavigatorObserver {
  void _set(Route<dynamic>? r) {
    if (r is! PageRoute) return;
    final name = r.settings.name ?? '';
    // Never notify during a build/transition — wait for the frame to end.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PlanState.routeName.value = name;
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _set(newRoute);

  // Intentionally ignored: after pushNamedAndRemoveUntil the removals are
  // reported AFTER the push of the new top page and would overwrite it.
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {}
}
