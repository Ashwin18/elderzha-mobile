import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

/// ALL subscription + autopay endpoints from api.php
///
/// ONE-TIME PAYMENT:
///   POST /user/purchase/plan           → initiate → returns razorpay order_id
///   POST /user/razorpay/sucess         → confirm one-time payment
///   GET  /user/get/purchased_plan      → current plan
///   GET  /user/payment/history         → history
///   GET  /user/active-plans            → available plans
///   POST /user/plan/coupon/check       → validate coupon
///   POST /user/plan/coupon/apply       → apply coupon
///   GET  /user/razorpay/credentials    → get key_id (public, no auth)
///
/// AUTO PAY (Razorpay Subscription):
///   POST /user/subscription/create     → create subscription → subscription_id
///   GET  /user/subscription/status     → active / cancelled / pending
///   POST /user/subscription/confirm    → confirm after checkout success
///   POST /user/subscription/cancel     → cancel subscription

class SubscriptionService {
  static const String localActiveKey = 'subscription_active_local';
  static const String paymentGateCompletedKey = 'payment_gate_completed';
  final _api = ApiClient();

  static const String cacheTimestampKey = 'subscription_cache_timestamp';
  static const int cacheExpiryHours = 24;

  static Future<void> markSubscriptionActiveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(localActiveKey, true);
    await prefs.setBool(paymentGateCompletedKey, true);
    // Store timestamp so cache expires after 24 hours
    await prefs.setString(cacheTimestampKey, DateTime.now().toIso8601String());
  }

  static Future<bool> isCacheExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(cacheTimestampKey);
    if (raw == null) return true;
    try {
      final saved = DateTime.parse(raw);
      return DateTime.now().difference(saved).inHours >= cacheExpiryHours;
    } catch (_) {
      return true;
    }
  }

  static Future<void> clearSubscriptionActiveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(localActiveKey);
    await prefs.remove(paymentGateCompletedKey);
  }

  static Future<bool> hasLocalActiveSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(localActiveKey) == true;
  }

  static Future<bool> hasCompletedPaymentGate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(paymentGateCompletedKey) == true ||
        prefs.getBool(localActiveKey) == true;
  }


  // ── Ask the server whether the plan is active ────────────────────────────
  // true / false ONLY when the server clearly answered.
  // null when the answer can't be trusted: no network, timeout, an error
  // reply, or a reply without the plan field. Callers must treat null as
  // "don't know" — never as "not paid". (A failed request used to look
  // exactly like "no plan", which sent paying users to the payment screen
  // at random whenever the network blinked as the app opened.)
  Future<bool?> _planFromServer() async {
    try {
      // /user/get/user/details returns is_plan_active and plan_expiry_date
      // on the User object (/user/get/purchased_plan has no plan status).
      final res = await _api.safeGet('/user/get/user/details');
      if (res == null || res['status'] != true) return null;
      final userData =
          res['data'] is Map ? (res['data']['user'] ?? res['data']) : null;
      if (userData is! Map) return null;
      final flag = userData['is_plan_active'];
      if (flag == null) return null;
      final active = flag == 1 || flag == '1' || flag == true;
      if (!active) return false;
      final expiryStr = userData['plan_expiry_date']?.toString() ?? '';
      if (expiryStr.isNotEmpty && expiryStr != 'null') {
        try {
          return DateTime.now().isBefore(DateTime.parse(expiryStr));
        } catch (_) {
          return true; // can't parse the date — trust is_plan_active
        }
      }
      return true; // no expiry date = active
    } catch (_) {
      return null;
    }
  }

  // The server's own yes/no for "is this plan active?" — taken straight from
  // is_plan_active, with NO arithmetic against the phone's clock (a phone
  // with a wrong date must never lock out a paying user or silence their
  // alarms). Also keeps the saved "active" flag in step.
  //   true / false -> the server clearly answered
  //   null         -> could not tell (no network, error reply, odd reply)
  Future<bool?> definitivePlanStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final res = await _api.safeGet('/user/get/user/details');
      if (res == null || res['status'] != true) return null;
      final userData =
          res['data'] is Map ? (res['data']['user'] ?? res['data']) : null;
      if (userData is! Map) return null;
      final flag = userData['is_plan_active'];
      if (flag == null) return null;
      final active = flag == 1 || flag == '1' || flag == true;
      if (active) {
        await _rememberActive(prefs);
      } else {
        await prefs.setBool(localActiveKey, false);
      }
      return active;
    } catch (_) {
      return null;
    }
  }

  // ── GET /user/subscription/status ────────────────────────────────────────
  // The real AutoPay status: plan_expiry_date, plan_purchased_date,
  // plan_type, auto_pay_enabled, auto_pay_status ('created' | 'active' |
  // 'halted' | 'cancelled' ...), razorpay_status, next_billing_date.
  // null when it could not be fetched.
  Future<Map<String, dynamic>?> getAutoPayStatus() async {
    try {
      final res = await _api.safeGet('/user/subscription/status');
      if (res == null || res['status'] != true) return null;
      final d = res['data'];
      return d is Map ? Map<String, dynamic>.from(d) : null;
    } catch (_) {
      return null;
    }
  }

  // ── A payment that was taken but not yet confirmed with the server ───────
  // Saved the moment Razorpay reports success, cleared only when the server
  // confirms. Lets the app finish activating later (next open, or the
  // "I already paid" button) instead of losing the payment.
  static const String pendingPaymentKey = 'pending_payment_confirm';

  static Future<void> savePendingPayment({
    required int purchaseId,
    required String subscriptionId,
    required String paymentId,
    required String signature,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        pendingPaymentKey,
        jsonEncode({
          'purchase_id': purchaseId,
          'subscription_id': subscriptionId,
          'payment_id': paymentId,
          'signature': signature,
          'saved_at': DateTime.now().toIso8601String(),
        }));
  }

  static Future<bool> hasPendingPayment() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(pendingPaymentKey) ?? '').isNotEmpty;
  }

  static Future<void> clearPendingPayment() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(pendingPaymentKey);
  }

  /// Tries again to confirm a saved payment. Returns true when the server
  /// confirmed it (the record is then cleared and the plan marked active),
  /// false when it is still unconfirmed or there was nothing saved.
  Future<bool> retryPendingConfirm() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(pendingPaymentKey);
    if (raw == null || raw.isEmpty) return false;
    try {
      final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      // Give up on very old records so a bad one cannot loop forever.
      final saved = DateTime.tryParse('${m['saved_at']}');
      if (saved != null && DateTime.now().difference(saved).inDays >= 3) {
        await prefs.remove(pendingPaymentKey);
        return false;
      }
      final res = await confirmSubscription(
        purchaseId: int.tryParse('${m['purchase_id']}') ?? 0,
        razorpaySubscriptionId: '${m['subscription_id'] ?? ''}',
        razorpayPaymentId: '${m['payment_id'] ?? ''}',
        razorpaySignature: '${m['signature'] ?? ''}',
      ).timeout(const Duration(seconds: 15),
          onTimeout: () => {'status': false, 'message': 'Network error'});
      if (res['status'] == true) {
        await prefs.remove(pendingPaymentKey);
        await _rememberActive(prefs);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Called right after Razorpay reports success. Saves the payment, then
  /// asks the server to confirm it (two tries). true = confirmed; false =
  /// still unconfirmed — the saved record stays so it is finished later.
  Future<bool> finishPayment({
    required int purchaseId,
    required String subscriptionId,
    required String paymentId,
    required String signature,
  }) async {
    await savePendingPayment(
      purchaseId: purchaseId,
      subscriptionId: subscriptionId,
      paymentId: paymentId,
      signature: signature,
    );
    for (var i = 0; i < 2; i++) {
      if (await retryPendingConfirm()) return true;
      if (i == 0) await Future<void>.delayed(const Duration(seconds: 3));
    }
    return false;
  }

  /// Before starting a NEW payment: is an earlier one still unconfirmed?
  ///   'none'      nothing waiting — go ahead
  ///   'confirmed' the earlier payment has just been confirmed (already paid)
  ///   'stuck'     still unconfirmed — do NOT charge the user again yet
  Future<String> settlePendingPayment() async {
    if (!await hasPendingPayment()) return 'none';
    if (await retryPendingConfirm()) return 'confirmed';
    // retryPendingConfirm drops records older than 3 days.
    return await hasPendingPayment() ? 'stuck' : 'none';
  }

  Future<void> _rememberActive(SharedPreferences prefs) async {
    await prefs.setBool(localActiveKey, true);
    await prefs.setBool(paymentGateCompletedKey, true);
    await prefs.setString(cacheTimestampKey, DateTime.now().toIso8601String());
  }

  // ── Check plan status directly from API ──────────────────────────────────
  // Used when the app is resumed, to detect expired plans.
  Future<bool> checkPlanFromAPI() async {
    final prefs = await SharedPreferences.getInstance();
    final server = await _planFromServer();
    if (server == null) {
      // Couldn't verify — keep whatever was last known. Do NOT clear the
      // saved "active" flag because of a failed request.
      return prefs.getBool(localActiveKey) == true;
    }
    if (server) {
      await _rememberActive(prefs);
    } else {
      await prefs.setBool(localActiveKey, false);
    }
    return server;
  }

  Future<bool> hasActiveSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    final hadActive = prefs.getBool(localActiveKey) == true;
    // Only use local cache if not expired (24 hours)
    if (hadActive && !(await isCacheExpired())) {
      return true;
    }

    final plan = await getPurchasedPlan();
    if (_looksActive(plan) || _hasPurchasedPlan(plan)) {
      await prefs.setBool(localActiveKey, true);
      await prefs.setBool(paymentGateCompletedKey, true);
      return true;
    }

    final status = await getSubscriptionStatus();
    if (_looksActive(status)) {
      await prefs.setBool(localActiveKey, true);
      await prefs.setBool(paymentGateCompletedKey, true);
      return true;
    }

    // Both checks above said "not active" — but a failed request looks the
    // same. Ask the one endpoint that reports plan status plainly.
    final server = await _planFromServer();
    if (server == true) {
      await _rememberActive(prefs);
      return true;
    }
    // Server unreachable or unclear, and this user was active before:
    // keep them in the app instead of sending them to pay again.
    if (server == null && hadActive) return true;
    return false;
  }

  bool _hasPurchasedPlan(dynamic value) {
    if (value == null) return false;
    if (value is List) return value.any(_hasPurchasedPlan);
    if (value is! Map) return false; // Fix 14: don't treat raw strings as active

    final map = Map<String, dynamic>.from(value);
    // Fix 14: check explicit status/plan_status fields only
    final planStatus = map['plan_status'];
    if (planStatus == 1 || planStatus == '1' || planStatus == true) return true;

    final statusText = (map['status'] ?? '').toString().toLowerCase().trim();
    if (statusText == 'false' || statusText == '0' ||
        statusText == 'error' || statusText == 'fail') return false;

    final data = map['data'];
    if (data is List) return data.isNotEmpty && _hasPurchasedPlan(data.first);
    if (data is Map) return _hasPurchasedPlan(data);

    // Must have both a plan reference AND an end date in the future
    final endDate = map['end_date']?.toString() ?? map['expiry_date']?.toString() ?? '';
    final hasPlanRef = (map['purchase_id'] ?? map['plan_id'] ?? map['subscription_id']) != null;
    if (hasPlanRef && endDate.isNotEmpty) {
      try {
        return DateTime.now().isBefore(DateTime.parse(endDate));
      } catch (_) {}
    }
    return hasPlanRef;
  }

  bool _looksActive(dynamic value) {
    if (value == null) return false;
    if (value is List) return value.any(_looksActive);
    if (value is! Map) {
      final text = value.toString().toLowerCase();
      return text == 'active' || text == 'subscribed';
    }
    final map = Map<String, dynamic>.from(value);
    final explicit = [
      map['is_active'],
      map['active'],
      map['is_subscribed'],
      map['subscribed'],
    ];
    for (final item in explicit) {
      final text = item?.toString().toLowerCase().trim();
      if (text == '1' || text == 'true' || text == 'active') return true;
    }
    final status = [
      map['status'],
      map['subscription_status'],
      map['payment_status'],
      map['plan_status'],
    ].map((e) => e?.toString().toLowerCase().trim()).whereType<String>();
    if (status.any((s) =>
        s == 'active' ||
        s == 'subscribed' ||
        s == 'paid' ||
        s == 'success' ||
        s == 'completed')) {
      return true;
    }
    return map.values.any(_looksActive);
  }

  // ── GET /user/razorpay/credentials ───────────────────────
  // PUBLIC — no auth needed. Returns { key_id: "rzp_live_xxx" }
  Future<Map<String, dynamic>?> getRazorpayCredentials() =>
      _api.safeGet('/user/razorpay/credentials');

  // ── GET /user/active-plans ────────────────────────────────
  // Returns list of plans: [{ id, name, amount, duration_type, ... }]
  Future<Map<String, dynamic>?> getActivePlans() =>
      _api.safeGet('/user/active-plans');

  // ── GET /user/get/purchased_plan ─────────────────────────
  Future<Map<String, dynamic>?> getPurchasedPlan() =>
      _api.safeGet('/user/get/purchased_plan');

  // ── GET /user/payment/history ─────────────────────────────
  Future<Map<String, dynamic>?> getPaymentHistory() =>
      _api.safeGet('/user/payment/history');

  // ─────────────────────────────────────────────────────────
  //  ONE-TIME PAYMENT FLOW
  // ─────────────────────────────────────────────────────────

  // Step 1 — POST /user/purchase/plan
  // Returns: { status, order_id, amount, currency, plan_id }
  Future<Map<String, dynamic>> initiatePlanPurchase({
    required int planId,
    String? couponCode,
  }) async {
    final res = await _api.safePost('/user/purchase/plan', data: {
      'plan_id': planId,
      if (couponCode != null && couponCode.isNotEmpty)
        'coupon_code': couponCode,
    });
    return res ?? {'status': false, 'message': 'Network error'};
  }

  // Step 2 — POST /user/razorpay/sucess
  // Called after Razorpay one-time payment succeeds
  Future<Map<String, dynamic>> confirmOneTimePayment({
    required int purchaseId,
    required int planId,
    required String razorpayPaymentId,
  }) async {
    final res = await _api.safePost('/user/razorpay/sucess', data: {
      'purchase_id': purchaseId,
      'plan_id': planId,
      'transaction_id': razorpayPaymentId,
    });
    return res ?? {'status': false, 'message': 'Network error'};
  }

  // ── POST /user/plan/coupon/check ─────────────────────────
  Future<Map<String, dynamic>> checkCoupon({
    required String couponCode,
    required int planId,
  }) async {
    final res = await _api.safePost('/user/plan/coupon/check', data: {
      'coupon_code': couponCode,
      'plan_id': planId,
    });
    return res ?? {'status': false, 'message': 'Network error'};
  }

  // ── POST /user/plan/coupon/apply ─────────────────────────
  Future<Map<String, dynamic>> applyCoupon({
    required String couponCode,
    required int planId,
  }) async {
    final res = await _api.safePost('/user/plan/coupon/apply', data: {
      'coupon_code': couponCode,
      'plan_id': planId,
    });
    return res ?? {'status': false, 'message': 'Network error'};
  }

  // ─────────────────────────────────────────────────────────
  //  AUTO PAY FLOW (Razorpay Subscription)
  // ─────────────────────────────────────────────────────────

  // Step 1 — POST /user/subscription/create
  // Returns: { status, subscription_id, short_url, plan_id, promo_applied, ... }
  //
  // FIX: this previously called /user/purchase/plan (the one-time
  // payment endpoint) — meaning "Auto Pay" never actually created a
  // real recurring Razorpay subscription for ANY user. Now correctly
  // calls the real endpoint.
  Future<Map<String, dynamic>> createSubscription({
    required int planId,
    String? promoCode,
  }) async {
    final res = await _api.safePost('/user/subscription/create', data: {
      'plan_id': planId,
      if (promoCode != null && promoCode.isNotEmpty) 'promo_code': promoCode,
    });
    return res ?? {'status': false, 'message': 'Network error'};
  }

  // Turn AutoPay on for a plan the user already paid for. Nothing is
  // charged for the plan now; billing starts when the current plan ends.
  Future<Map<String, dynamic>> enableAutoPay({int? planId}) async {
    final res = await _api.safePost('/user/subscription/create', data: {
      'enable_autopay': 1,
      if (planId != null) 'plan_id': planId,
    });
    return res ?? {'status': false, 'message': 'Network error'};
  }

  // ── POST /user/promo-code/validate ───────────────────────
  // Called while user is entering a promo code, before checkout —
  // shows pricing preview ("Pay ₹1 now, ₹299/month from next cycle").
  Future<Map<String, dynamic>> validatePromoCode({
    required String code,
    required int planId,
  }) async {
    final res = await _api.safePost('/user/promo-code/validate', data: {
      'code': code,
      'plan_id': planId,
    });
    return res ?? {'status': false, 'message': 'Network error'};
  }

  // Step 2 — POST /user/subscription/confirm
  // Called after Razorpay subscription checkout success
  Future<Map<String, dynamic>> confirmSubscription({
    required int purchaseId,
    required String razorpaySubscriptionId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final res = await _api.safePost('/user/subscription/confirm', data: {
      'purchase_id': purchaseId,
      'razorpay_subscription_id': razorpaySubscriptionId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
    });
    return res ?? {'status': false, 'message': 'Network error'};
  }

  // ── GET /user/subscription/status ────────────────────────
  // Returns: { status, subscription: { status: 'active'|'cancelled'|'pending', ... } }
  // /user/subscription/status doesn't exist — use purchased_plan + user/details
  Future<Map<String, dynamic>?> getSubscriptionStatus() async {
    final plan = await _api.safeGet('/user/get/purchased_plan');
    final user = await _api.safeGet('/user/get/user/details');
    if (plan == null && user == null) return null;
    return {
      'status': true,
      'data': {
        'plan': plan?['data'],
        'is_plan_active': (user?['data'] is Map)
            ? ((user!['data'] as Map)['user'] is Map
                ? ((user['data'] as Map)['user'] as Map)['is_plan_active']
                : (user['data'] as Map)['is_plan_active'])
            : null,
        'plan_expiry_date': (user?['data'] is Map)
            ? ((user!['data'] as Map)['user'] is Map
                ? ((user['data'] as Map)['user'] as Map)['plan_expiry_date']
                : (user['data'] as Map)['plan_expiry_date'])
            : null,
      }
    };
  }

  // ── POST /user/subscription/cancel ───────────────────────
  // Route exists via SubscriptionApiController
  Future<Map<String, dynamic>> cancelSubscription() async {
    final res = await _api.safePost('/user/subscription/cancel');
    return res ?? {'status': false, 'message': 'Network error'};
  }
}
