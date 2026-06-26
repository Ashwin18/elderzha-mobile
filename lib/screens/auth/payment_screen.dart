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
  final _couponCtrl = TextEditingController();
  String? _couponApplied;
  String? _couponDiscount;
  double? _couponPlanAmount;
  bool _couponFirstMonthFree = false;
  bool _checkingCoupon = false;

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
    _couponCtrl.dispose();
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

  Future<void> _checkCoupon() async {
    if (_couponCtrl.text.isEmpty || _selPlanId == null) return;
    setState(() => _checkingCoupon = true);
    final res = await _subService.checkCoupon(
        couponCode: _couponCtrl.text.trim(), planId: _selPlanId!);
    setState(() => _checkingCoupon = false);
    if (!mounted) return;
    if (res['status'] == true) {
      // ── POST /user/plan/coupon/apply ─────────────────────
      final applyRes = await _subService.applyCoupon(
          couponCode: _couponCtrl.text.trim(), planId: _selPlanId!);
      final data = applyRes['data'] is Map ? applyRes['data'] as Map : applyRes;
      final finalAmount = _toDouble(data['final_amount'] ?? data['amount']);
      final planAmount = _toDouble(data['plan_amount'] ??
          data['original_amount'] ??
          data['amount'] ??
          _selPlan?['amount']);
      final discountAmount = data['discount_amount'] ??
          data['discount'] ??
          applyRes['discount'] ??
          res['discount'] ??
          res['message'];
      setState(() {
        _couponApplied = _couponCtrl.text.trim();
        _couponDiscount = discountAmount?.toString();
        _couponPlanAmount = planAmount;
        _couponFirstMonthFree = finalAmount != null && finalAmount <= 0;
      });
      _snack(
          _couponFirstMonthFree
              ? 'Coupon applied! First month is free.'
              : 'Coupon applied! ${_couponDiscount ?? ''}',
          ok: true);
    } else {
      setState(() {
        _couponApplied = null;
        _couponDiscount = null;
        _couponPlanAmount = null;
        _couponFirstMonthFree = false;
      });
      _snack(res['message'] ?? 'Invalid coupon');
    }
  }

  Future<void> _pay() async {
    if (_selPlanId == null || _rzpKey == null) {
      _snack('Payment not ready. Try again.');
      return;
    }
    setState(() => _paying = true);
    if (_couponFirstMonthFree) {
      final res = await _subService.initiatePlanPurchase(
          planId: _selPlanId!, couponCode: _couponApplied);
      setState(() => _paying = false);
      if (!mounted) return;
      if (res['status'] != true) {
        _snack(res['message'] ?? 'Failed to activate coupon');
        return;
      }
      final data = res['data'] is Map ? res['data'] : res;
      Navigator.pushReplacementNamed(context, AppRoutes.paymentSuccess,
          arguments: {
            'plan_name': data['plan_name'] ?? _planName(_selPlan),
            'payment_id': data['transaction_id'],
            'auto_pay': _autoPay,
            'first_month_free': true,
            'recurring_amount': _formatAmount(_couponPlanAmount ?? _planAmount),
          });
      return;
    }
    if (_autoPay) {
      final res = await _subService.createSubscription(
          planId: _selPlanId!, autoPay: true);
      setState(() => _paying = false);
      if (!mounted) return;
      if (res['status'] != true) {
        _snack(res['message'] ?? 'Failed to create subscription');
        return;
      }
      final subId = res['subscription_id'] ?? res['data']?['subscription_id'];
      final purchaseId = int.tryParse(
          (res['purchase_id'] ?? res['data']?['purchase_id'] ?? '').toString());
      if (subId == null) {
        _snack('Invalid subscription response');
        return;
      }
      _pendingSubscriptionId = subId.toString();
      _pendingPurchaseId = purchaseId;
      _openRzp({
        'key': res['data']?['razorpay_key'] ?? _rzpKey,
        'subscription_id': subId,
        'name': 'ElderZha',
        'description': res['data']?['description'] ?? _planName(_selPlan),
        'prefill': {
          'name': res['data']?['user_name'],
          'contact': res['data']?['user_phone'],
        },
        'theme': {'color': '#FFCC01'}
      });
    } else {
      final res = await _subService.initiatePlanPurchase(
          planId: _selPlanId!, couponCode: _couponApplied);
      setState(() => _paying = false);
      if (!mounted) return;
      if (res['status'] != true) {
        _snack(res['message'] ?? 'Failed to initiate payment');
        return;
      }
      final data = res['data'] is Map ? res['data'] : res;
      final purchaseId = int.tryParse((data['purchase_id'] ?? '').toString());
      final amountText =
          data['final_amount'] ?? data['amount'] ?? data['plan_amount'];
      final amount =
          ((double.tryParse(amountText.toString()) ?? 0) * 100).round();
      if (purchaseId == null) {
        _snack('Invalid purchase response');
        return;
      }
      if (data['activate_without_payment'] == true || amount <= 0) {
        Navigator.pushReplacementNamed(context, AppRoutes.paymentSuccess,
            arguments: {
              'plan_name': data['plan_name'] ?? _planName(_selPlan),
              'payment_id': data['transaction_id'],
              'auto_pay': false,
              'first_month_free': _couponFirstMonthFree,
              'recurring_amount':
                  _formatAmount(_couponPlanAmount ?? _planAmount),
            });
        return;
      }
      _pendingPurchaseId = purchaseId;
      _openRzp({
        'key': _rzpKey,
        'amount': amount,
        'name': 'ElderZha',
        'description': data['plan_name'] ?? _planName(_selPlan),
        'prefill': {
          'name': data['userdetails']?['first_name'],
          'email': data['userdetails']?['email'],
          'contact': data['userdetails']?['phone'],
        },
        'theme': {'color': '#FFCC01'}
      });
    }
  }

  void _openRzp(Map<String, dynamic> opts) {
    try {
      _rzp.open(opts);
    } catch (e) {
      _snack('Could not open payment: $e');
    }
  }

  void _onSuccess(PaymentSuccessResponse r) async {
    setState(() => _paying = true);
    Map<String, dynamic> res;
    if (_autoPay) {
      res = await _subService.confirmSubscription(
          purchaseId: _pendingPurchaseId ?? 0,
          razorpaySubscriptionId: _pendingSubscriptionId ?? r.orderId ?? '',
          razorpayPaymentId: r.paymentId ?? '',
          razorpaySignature: r.signature ?? '');
    } else {
      res = await _subService.confirmOneTimePayment(
        purchaseId: _pendingPurchaseId ?? 0,
        planId: _selPlanId ?? 0,
        razorpayPaymentId: r.paymentId ?? '',
      );
    }
    setState(() => _paying = false);
    if (!mounted) return;
    if (res['status'] != true) {
      _snack(res['message'] ?? 'Payment confirmation failed');
      return;
    }
    Navigator.pushReplacementNamed(context, AppRoutes.paymentSuccess,
        arguments: {
          'plan_name': _planName(_selPlan),
          'payment_id': r.paymentId,
          'auto_pay': _autoPay,
          'first_month_free': _couponFirstMonthFree,
          'recurring_amount': _formatAmount(_couponPlanAmount ?? _planAmount),
        });
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
    final amount = _formatAmount(_couponPlanAmount ?? _planAmount);
    return '1st Month Rs 0, then Rs $amount/ Monthly';
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
                                _couponApplied = null;
                                _couponDiscount = null;
                                _couponPlanAmount = null;
                                _couponFirstMonthFree = false;
                                _couponCtrl.clear();
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
                              controller: _couponCtrl,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                hintText: 'Coupon code',
                                prefixIcon: const Icon(
                                    Icons.local_offer_outlined,
                                    size: 18),
                                suffixIcon: _couponApplied != null
                                    ? const Icon(Icons.check_circle_rounded,
                                        color: C.green, size: 18)
                                    : null,
                              ),
                            )),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _checkingCoupon ? null : _checkCoupon,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                    color: C.ink,
                                    borderRadius: BorderRadius.circular(14)),
                                child: _checkingCoupon
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
                          if (_couponApplied != null)
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
                                        _couponFirstMonthFree
                                            ? _renewalText()
                                            : 'Coupon applied: $_couponDiscount',
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
