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

  static Future<void> markSubscriptionActiveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(localActiveKey, true);
    await prefs.setBool(paymentGateCompletedKey, true);
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

  Future<bool> hasActiveSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(localActiveKey) == true) return true;

    final plan = await getPurchasedPlan();
    if (_looksActive(plan)) {
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
    return false;
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
  // Returns: { status, subscription_id, short_url, plan_id }
  Future<Map<String, dynamic>> createSubscription({
    required int planId,
    bool autoPay = true,
  }) async {
    final res = await _api.safePost('/user/subscription/create', data: {
      'plan_id': planId,
      'auto_pay': autoPay ? 1 : 0,
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
  Future<Map<String, dynamic>?> getSubscriptionStatus() =>
      _api.safeGet('/user/subscription/status');

  // ── POST /user/subscription/cancel ───────────────────────
  Future<Map<String, dynamic>> cancelSubscription() async {
    final res = await _api.safePost('/user/subscription/cancel');
    return res ?? {'status': false, 'message': 'Network error'};
  }
}
