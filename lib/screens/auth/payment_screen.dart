import 'dart:async';

import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_routes.dart';
import '../../services/services.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _subService = SubscriptionService();
  late Razorpay _rzp;

  bool _loadingPlans = true;
  bool _paying = false;
  bool _autoPay = true; // Auto pay ON by default per reference
  List _plans = [];
  int? _selPlanId;
  String? _rzpKey;
  int? _pendingPurchaseId;
  String? _pendingSubscriptionId;
  final _promoCtrl = TextEditingController();
  String? _promoApplied;      // the code, once validated
  double? _promoValue;        // e.g. 1.00 — what they pay today
  double? _promoFullAmount;   // e.g. 299.00 — what bills from next cycle
  String? _promoBillingNote;  // human-readable line from backend
  bool _checkingPromo = false;
  bool _paymentHandled = false;

  @override
  void initState() {
    super.initState();
    _rzp = Razorpay();
    _rzp.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _rzp.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _rzp.on(Razorpay.EVENT_EXTERNAL_WALLET, _onWallet);
    _load();
  }

  @override
  void dispose() {
    _rzp.clear();
    _promoCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadingPlans = true);
    final results = await Future.wait(
        [_subService.getActivePlans(), _subService.getRazorpayCredentials()]);
    if (!mounted) return;
    setState(() {
      _plans = _extractList(results[0]);
      _rzpKey = results[1]?['key_id'] ??
          results[1]?['RAZORPAY_KEY'] ??
          results[1]?['data']?['key_id'] ??
          results[1]?['data']?['RAZORPAY_KEY'];
      if (_plans.isNotEmpty) _selPlanId = _plans[0]['id'];
      _loadingPlans = false;
    });
  }

  Future<void> _validatePromo() async {
    if (_promoCtrl.text.isEmpty || _selPlanId == null) return;
    setState(() => _checkingPromo = true);
    final res = await _subService.validatePromoCode(
        code: _promoCtrl.text.trim(), planId: _selPlanId!);
    setState(() => _checkingPromo = false);
    if (!mounted) return;
    if (res['status'] == true) {
      final data = res['data'] is Map ? res['data'] as Map : {};
      setState(() {
        _promoApplied = (data['code'] ?? _promoCtrl.text.trim()).toString();
        _promoValue = _toDouble(data['promo_value']);
        _promoFullAmount = _toDouble(data['plan_amount']) ?? _planAmount;
        _promoBillingNote = data['billing_note']?.toString();
      });
      _snack('Promo code applied!', ok: true);
    } else {
      setState(() {
        _promoApplied = null;
        _promoValue = null;
        _promoFullAmount = null;
        _promoBillingNote = null;
      });
      _snack(res['message'] ?? 'Invalid promo code');
    }
  }

  Future<void> _pay() async {
    if (_selPlanId == null || _rzpKey == null) {
      _snack('Payment not ready. Try again.');
      return;
    }
    setState(() => _paying = true);

    // Always create a REAL Razorpay recurring subscription — this used
    // to call the one-time /user/purchase/plan endpoint regardless of
    // the "auto pay" messaging shown above, meaning no actual recurring
    // charge was ever set up. Now fixed to use the real endpoint.
    //
    // If a promo code is applied, the backend charges the promo value
    // now (e.g. ₹1) via Razorpay's native upfront-amount mechanism, and
    // schedules the subscription's own recurring billing (at the full
    // plan price) to begin automatically at the next cycle — all as
    // ONE Razorpay subscription, one checkout step.
    final res = await _subService.createSubscription(
      planId: _selPlanId!,
      promoCode: _promoApplied,
    );
    setState(() => _paying = false);
    if (!mounted) return;
    if (res['status'] != true) {
      _snack(res['message'] ?? 'Failed to start subscription');
      return;
    }

    final data = res['data'] is Map ? res['data'] as Map : {};
    final subscriptionId = data['subscription_id']?.toString();
    final purchaseId = int.tryParse((data['purchase_id'] ?? '').toString());
    if (subscriptionId == null || purchaseId == null) {
      _snack('Invalid subscription response');
      return;
    }
    _pendingPurchaseId = purchaseId;
    _pendingSubscriptionId = subscriptionId;

    _openRzp({
      'key': _rzpKey,
      'subscription_id': subscriptionId,
      'name': 'ElderZha',
      'description': data['description'] ?? _planName(_selPlan),
      'prefill': {
        'name': data['user_name'],
        'contact': data['user_phone'],
      },
      'theme': {'color': '#FFCC01'}
    });
  }

  void _openRzp(Map<String, dynamic> opts) {
    try {
      _rzp.open(opts);
    } catch (e) {
      _snack('Could not open payment: $e');
    }
  }

  void _onSuccess(PaymentSuccessResponse r) async {
    if (_paymentHandled) return;
    _paymentHandled = true;
    setState(() => _paying = true);
    Map<String, dynamic> res = {'status': true};
    try {
      // POST /user/subscription/confirm — verifies and activates the
      // real recurring subscription (was previously confirming as if
      // it were a one-time payment, which doesn't apply here at all).
      final confirmation = _subService.confirmSubscription(
        purchaseId: _pendingPurchaseId ?? 0,
        razorpaySubscriptionId: _pendingSubscriptionId ?? '',
        razorpayPaymentId: r.paymentId ?? '',
        razorpaySignature: r.signature ?? '',
      );
      res = await confirmation.timeout(
        const Duration(seconds: 8),
        onTimeout: () => {
          'status': true,
          'message': 'Payment captured. Confirmation is syncing.',
        },
      );
    } catch (_) {
      res = {
        'status': true,
        'message': 'Payment captured. Confirmation is syncing.',
      };
    }
    if (mounted) setState(() => _paying = false);
    if (!mounted) return;
    if (res['status'] != true) {
      _snack(res['message'] ?? 'Payment confirmation failed');
      _paymentHandled = false;
      return;
    }
    await SubscriptionService.markSubscriptionActiveLocal();
    _goSuccess({
      'plan_name': _planName(_selPlan),
      'payment_id': r.paymentId,
      'auto_pay': true,
      'first_month_free': false,
      'promo_applied': _promoApplied != null,
      'promo_value': _promoValue,
      'recurring_amount': _formatAmount(_promoFullAmount ?? _planAmount),
    });
  }

  Future<void> _goSuccess(Map<String, dynamic> args) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.paymentSuccess,
      (route) => false,
      arguments: args,
    );
  }

  void _onError(PaymentFailureResponse r) {
    setState(() => _paying = false);
    _snack('Payment failed: ${r.message ?? 'Unknown'}');
  }

  void _onWallet(ExternalWalletResponse r) {
    setState(() => _paying = false);
  }

  void _snack(String m, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, style: poppins(13)),
        backgroundColor: ok ? C.green : C.red));
  }

  dynamic get _selPlan =>
      _plans.firstWhere((p) => p['id'] == _selPlanId, orElse: () => null);
  List _extractList(Map<String, dynamic>? res) {
    final data = res?['data'];
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'] as List;
    return [];
  }

  String _planName(dynamic plan) {
    if (plan is! Map) return 'Plan';
    return (plan['name'] ?? plan['plan_name'] ?? plan['type'] ?? 'Plan')
        .toString();
  }

  String _amount(dynamic plan) =>
      '₹${plan['amount'] ?? plan['price'] ?? plan['plan_amount'] ?? ''}';
  String _period(dynamic plan) =>
      '/${plan['duration_type'] ?? plan['type'] ?? 'month'}';
  double get _planAmount =>
      _toDouble(_selPlan?['amount'] ??
          _selPlan?['price'] ??
          _selPlan?['plan_amount']) ??
      0;

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(RegExp(r'[^0-9.]'), ''));
  }

  String _formatAmount(double value) {
    return value.toStringAsFixed(2);
  }

  String _renewalText() {
    if (_promoBillingNote != null) return _promoBillingNote!;
    final amount = _formatAmount(_promoFullAmount ?? _planAmount);
    return 'Pay ₹${_formatAmount(_promoValue ?? 0)} now, then Rs $amount/month';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(children: [
        Container(
          width: double.infinity,
          color: C.yellow,
          child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Almost there! 🎉',
                          style:
                              poppins(13, w: FontWeight.w600, c: C.yellowDeep)),
                      const SizedBox(height: 4),
                      Text('Choose your\nplan',
                          style: poppins(26,
                              w: FontWeight.w800, c: C.ink, h: 1.2)),
                    ]),
              )),
        ),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
                color: C.white,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28))),
            child: _loadingPlans
                ? const Center(
                    child: CircularProgressIndicator(color: C.yellowDark))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Plan cards
                          ..._plans.map<Widget>((plan) {
                            final sel = _selPlanId == plan['id'];
                            final isYear =
                                (plan['duration_type'] ?? plan['type'] ?? '')
                                    .toString()
                                    .toLowerCase()
                                    .contains('year');
                            return GestureDetector(
                              onTap: () => setState(() {
                                _selPlanId = plan['id'];
                                _promoApplied = null;
                                _promoValue = null;
                                _promoFullAmount = null;
                                _promoBillingNote = null;
                                _promoCtrl.clear();
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: sel ? C.yellowLight : C.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                      color: sel ? C.yellow : C.bd,
                                      width: sel ? 2 : 1.5),
                                ),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 9, vertical: 3),
                                          decoration: BoxDecoration(
                                              color: sel ? C.ink : C.bg3,
                                              borderRadius:
                                                  BorderRadius.circular(6)),
                                          child: Text(
                                              isYear ? 'Save ₹189' : 'Popular',
                                              style: poppins(10,
                                                  w: FontWeight.w700,
                                                  c: sel ? C.yellow : C.txl)),
                                        ),
                                      ]),
                                      const SizedBox(height: 8),
                                      Text(_planName(plan),
                                          style: poppins(15,
                                              w: FontWeight.w700, c: C.ink)),
                                      Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(_amount(plan),
                                                style: poppins(24,
                                                    w: FontWeight.w800,
                                                    c: C.yellowDeep)),
                                            Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 3, left: 3),
                                                child: Text(_period(plan),
                                                    style:
                                                        poppins(12, c: C.txl))),
                                          ]),
                                      const Divider(height: 16),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: C.yellowMid,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border:
                                              Border.all(color: C.yellowBorder),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(
                                              Icons.autorenew_rounded,
                                              color: C.yellowDeep,
                                              size: 19,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text('Monthly auto pay',
                                                      style: poppins(13,
                                                          w: FontWeight.w800,
                                                          c: C.ink)),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                      'This plan renews automatically every month. You can disable auto pay later from My Profile settings.',
                                                      style: poppins(11,
                                                          w: FontWeight.w600,
                                                          c: C.yellowDeep,
                                                          h: 1.35)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ]),
                              ),
                            );
                          }),

                          const SizedBox(height: 4),
                          Row(children: [
                            Expanded(
                                child: TextField(
                              controller: _promoCtrl,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                hintText: 'Promo code',
                                prefixIcon: const Icon(
                                    Icons.local_offer_outlined,
                                    size: 18),
                                suffixIcon: _promoApplied != null
                                    ? const Icon(Icons.check_circle_rounded,
                                        color: C.green, size: 18)
                                    : null,
                              ),
                            )),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _checkingPromo ? null : _validatePromo,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                    color: C.ink,
                                    borderRadius: BorderRadius.circular(14)),
                                child: _checkingPromo
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2))
                                    : Text('Apply',
                                        style: poppins(13,
                                            w: FontWeight.w700,
                                            c: Colors.white)),
                              ),
                            ),
                          ]),
                          if (_promoApplied != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: C.greenLight,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: C.green.withOpacity(.25)),
                                  ),
                                  child: Row(children: [
                                    const Icon(Icons.check_circle_rounded,
                                        size: 16, color: C.green),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Text(
                                        _renewalText(),
                                        style: poppins(12,
                                            w: FontWeight.w700, c: C.green),
                                      ),
                                    ),
                                  ]),
                                )),

                          const SizedBox(height: 20),
                          // Features
                          _feature(Icons.medication_rounded,
                              'Daily medication reminders'),
                          _feature(Icons.people_rounded, 'Family event alerts'),
                          _feature(Icons.calendar_month_rounded,
                              'Wellness calendar & check-ins'),
                          _feature(
                              Icons.forum_rounded, 'Senior community access'),
                          const SizedBox(height: 24),

                          // Pay button
                          GestureDetector(
                            onTap: _paying ? null : _pay,
                            child: Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                  color: C.ink,
                                  borderRadius: BorderRadius.circular(14)),
                              child: Center(
                                  child: _paying
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                              color: C.yellow, strokeWidth: 2))
                                      : Text('⚡ Subscribe with Razorpay',
                                          style: poppins(14,
                                              w: FontWeight.w700,
                                              c: Colors.white))),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Center(
                              child: Text(
                                  'Secured by Razorpay · 256-bit encryption',
                                  style: poppins(11, c: C.txl))),
                        ]),
                  ),
          ),
        ),
      ]),
    );
  }

  Widget _feature(IconData icon, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, size: 16, color: C.yellowDark),
          const SizedBox(width: 10),
          Text(label, style: poppins(13, c: C.txm)),
        ]),
      );
}
