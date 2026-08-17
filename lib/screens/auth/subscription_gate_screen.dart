// lib/screens/auth/subscription_gate_screen.dart
// Full-screen paywall shown when plan expires.
// Cannot be dismissed. User must renew to continue.
// Promo codes are for NEW users only (registration) — not shown here.
// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_routes.dart';
import '../../services/services.dart';

class SubscriptionGateScreen extends StatefulWidget {
  const SubscriptionGateScreen({super.key});
  @override
  State<SubscriptionGateScreen> createState() => _SubscriptionGateScreenState();
}

class _SubscriptionGateScreenState extends State<SubscriptionGateScreen> {
  final _svc = SubscriptionService();
  late Razorpay _rzp;

  bool _loadingPlans = true;
  bool _paying       = false;
  bool _paymentHandled = false;
  List _plans   = [];
  int? _selPlanId;
  String? _rzpKey;
  int?    _pendingPurchaseId;
  String? _pendingSubscriptionId;

  @override
  void initState() {
    super.initState();
    _rzp = Razorpay();
    _rzp.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _rzp.on(Razorpay.EVENT_PAYMENT_ERROR,   _onError);
    _rzp.on(Razorpay.EVENT_EXTERNAL_WALLET, _onWallet);
    _load();
  }

  @override
  void dispose() {
    _rzp.clear();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadingPlans = true);
    final results = await Future.wait([
      _svc.getActivePlans(),
      _svc.getRazorpayCredentials(),
    ]);
    if (!mounted) return;
    setState(() {
      _plans  = _extractList(results[0]);
      _rzpKey = results[1]?['key_id'] ??
          results[1]?['RAZORPAY_KEY'] ??
          results[1]?['data']?['key_id'];
      if (_plans.isNotEmpty) _selPlanId = _plans[0]['id'];
      _loadingPlans = false;
    });
  }

  Future<void> _pay() async {
    if (_selPlanId == null || _rzpKey == null) {
      _snack('Payment not ready. Please try again.');
      return;
    }
    setState(() => _paying = true);

    // All users get real AutoPay — creates an actual recurring
    // Razorpay subscription (previously called the one-time-purchase
    // endpoint here, meaning renewals never actually set up real
    // recurring billing). No promo code on this screen — promo codes
    // are for new users at registration only.
    final res = await _svc.createSubscription(planId: _selPlanId!);
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
        'name':    data['user_name'],
        'contact': data['user_phone'],
      },
      'theme': {'color': '#FFCC01'},
    });
  }

  void _openRzp(Map<String, dynamic> opts) {
    try { _rzp.open(opts); } catch (e) { _snack('Could not open payment: $e'); }
  }

  void _onSuccess(PaymentSuccessResponse r) async {
    if (_paymentHandled) return;
    _paymentHandled = true;
    setState(() => _paying = true);
    try {
      final conf = _svc.confirmSubscription(
        purchaseId: _pendingPurchaseId ?? 0,
        razorpaySubscriptionId: _pendingSubscriptionId ?? '',
        razorpayPaymentId: r.paymentId ?? '',
        razorpaySignature: r.signature ?? '',
      );
      await conf.timeout(const Duration(seconds: 8),
          onTimeout: () => {'status': true});
    } catch (_) {}
    if (!mounted) return;
    await SubscriptionService.markSubscriptionActiveLocal();
    setState(() => _paying = false);
    _goHome();
  }

  void _onError(PaymentFailureResponse r) {
    setState(() { _paying = false; _paymentHandled = false; });
    _snack('Payment failed: ${r.message ?? 'Unknown error'}');
  }

  void _onWallet(ExternalWalletResponse r) =>
      setState(() => _paying = false);

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.home, (route) => false);
  }

  void _snack(String msg, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: poppins(13)),
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
  String _planName(dynamic p) => p is Map
      ? (p['name'] ?? p['plan_name'] ?? p['type'] ?? 'Plan').toString()
      : 'Plan';
  String _amount(dynamic p) =>
      '₹${p['amount'] ?? p['price'] ?? p['plan_amount'] ?? ''}';
  String _period(dynamic p) =>
      '/${p['duration_type'] ?? p['type'] ?? 'month'}';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Cannot dismiss — must subscribe
      child: Scaffold(
        backgroundColor: C.bg,
        body: Column(children: [
          Container(
            width: double.infinity,
            color: C.yellow,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Lock icon
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: C.ink, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.lock_rounded, color: C.yellow, size: 22),
                    ),
                    const SizedBox(height: 14),
                    Text('Subscription required',
                        style: poppins(26, w: FontWeight.w800, c: C.ink, h: 1.2)),
                    const SizedBox(height: 6),
                    Text('Your plan has expired. Renew to continue using ElderZha.',
                        style: poppins(13, w: FontWeight.w500, c: C.yellowDeep)),
                  ]),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: C.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28), topRight: Radius.circular(28)),
              ),
              child: _loadingPlans
                  ? const Center(child: CircularProgressIndicator(color: C.yellowDark))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Plan cards
                          ..._plans.map<Widget>((plan) {
                            final sel = _selPlanId == plan['id'];
                            return GestureDetector(
                              onTap: () => setState(() => _selPlanId = plan['id']),
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
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_planName(plan),
                                        style: poppins(15, w: FontWeight.w700, c: C.ink)),
                                    Row(crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(_amount(plan),
                                            style: poppins(24, w: FontWeight.w800, c: C.yellowDeep)),
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 3, left: 3),
                                          child: Text(_period(plan), style: poppins(12, c: C.txl)),
                                        ),
                                      ]),
                                    const SizedBox(height: 6),
                                    Row(children: [
                                      const Icon(Icons.autorenew_rounded,
                                          size: 14, color: C.txl),
                                      const SizedBox(width: 5),
                                      Text('Renews automatically',
                                          style: poppins(11, c: C.txl)),
                                    ]),
                                  ]),
                              ),
                            );
                          }),

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
                              child: Center(child: _paying
                                  ? const SizedBox(width: 22, height: 22,
                                      child: CircularProgressIndicator(
                                          color: C.yellow, strokeWidth: 2))
                                  : Text('⚡ Renew with Razorpay',
                                      style: poppins(14, w: FontWeight.w700,
                                          c: Colors.white))),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Center(child: Text(
                              'Secured by Razorpay · 256-bit encryption',
                              style: poppins(11, c: C.txl))),
                        ]),
                    ),
            ),
          ),
        ]),
      ),
    );
  }
}
