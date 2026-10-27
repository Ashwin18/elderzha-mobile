import 'dart:async';

import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:confetti/confetti.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_routes.dart';
import '../../services/services.dart';
import '../../services/plan_state.dart';
import '../../utils/ez_dates.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _subService = SubscriptionService();
  late Razorpay _rzp;
  late ConfettiController _confettiController;

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
  bool _promoIsTrial = false;     // Early Bird free trial code
  String? _promoFirstDebit;       // 'YYYY-MM-DD' first payment (trial)
  String? _promoLaunch;           // 'YYYY-MM-DD' app opens (trial)
  bool _checkingPromo = false;
  bool _preLaunchSignup = false; // alarm/family setup is skipped before launch
  bool _paymentHandled = false;

  @override
  void initState() {
    super.initState();
    _rzp = Razorpay();
    _rzp.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _rzp.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _rzp.on(Razorpay.EVENT_EXTERNAL_WALLET, _onWallet);
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    _load();
  }

  @override
  void dispose() {
    PlanState.paymentInFlight = false;
    _rzp.clear();
    _promoCtrl.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadingPlans = true);
    final results = await Future.wait(
        [_subService.getActivePlans(), _subService.getRazorpayCredentials()]);
    final preLaunch = await OnboardingInfo.skipAlarmSetup();
    if (!mounted) return;
    setState(() {
      _preLaunchSignup = preLaunch;
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
        _promoIsTrial = data['type']?.toString() == 'trial';
        _promoFirstDebit = data['first_debit_date']?.toString();
        _promoLaunch = data['launch_date']?.toString();
      });
      _confettiController.play();
      _snack('Promo code applied!', ok: true);
    } else {
      setState(() {
        _promoApplied = null;
        _promoValue = null;
        _promoFullAmount = null;
        _promoBillingNote = null;
        _promoIsTrial = false;
        _promoFirstDebit = null;
        _promoLaunch = null;
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

    // An earlier payment that was taken but not yet confirmed must be
    // settled first — otherwise this tap could charge the user twice.
    final earlier = await _subService.settlePendingPayment();
    if (!mounted) return;
    if (earlier == 'stuck') {
      setState(() => _paying = false);
      _snack('We are still confirming your last payment. Please wait a '
          'minute and try again — you will not be charged twice.');
      return;
    }
    if (earlier == 'confirmed') {
      await PlanState.markActive();
      if (!mounted) return;
      setState(() => _paying = false);
      _goSuccess({
        'plan_name': _planName(_selPlan),
        'payment_id': '',
        'auto_pay': true,
        'first_month_free': false,
        'promo_applied': false,
      });
      return;
    }

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
      // While checkout is open, plan checks wait — coming back from a UPI
      // app must never be read as "not paid".
      PlanState.paymentInFlight = true;
      _rzp.open(opts);
    } catch (e) {
      PlanState.paymentInFlight = false;
      _snack('Could not open payment: $e');
    }
  }

  void _onSuccess(PaymentSuccessResponse r) async {
    if (_paymentHandled) return;
    _paymentHandled = true;
    if (mounted) setState(() => _paying = true);
    // Saves the payment first, then asks the server to confirm it. If the
    // network fails the saved record is finished later (next time the app
    // opens, or "I already paid — check again") instead of being lost.
    final confirmed = await _subService.finishPayment(
      purchaseId: _pendingPurchaseId ?? 0,
      subscriptionId: _pendingSubscriptionId ?? '',
      paymentId: r.paymentId ?? '',
      signature: r.signature ?? '',
    );
    PlanState.paymentInFlight = false;
    if (_promoIsTrial) {
      // Show the launch countdown straight away.
      await PlanState.setTrialLocal(
        firstDebitDate: _promoFirstDebit,
        launchDate: _promoLaunch,
        firstPaymentDisplay:
            '₹${_formatAmount(_promoFullAmount ?? _planAmount).replaceAll(RegExp(r'\.00$'), '')}',
      );
    }
    if (confirmed) {
      await SubscriptionService.markSubscriptionActiveLocal();
      await PlanState.markActive();
    }
    if (!mounted) return;
    setState(() => _paying = false);
    if (!confirmed) {
      _snack('Payment received. We are activating your plan — this can '
          'take a minute.', ok: true);
    }
    _goSuccess({
      'plan_name': _planName(_selPlan),
      'payment_id': r.paymentId,
      'auto_pay': true,
      'first_month_free': false,
      'promo_applied': _promoApplied != null,
      'promo_value': _promoValue,
      'recurring_amount': _formatAmount(_promoFullAmount ?? _planAmount),
      if (_promoIsTrial) ...{
        'trial': true,
        'promo_code': _promoApplied,
        'first_debit_date': _promoFirstDebit,
        'launch_date': _promoLaunch,
        'first_payment': '₹${_formatAmount(_promoFullAmount ?? _planAmount).replaceAll(RegExp(r'\.00$'), '')}',
      },
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
    PlanState.paymentInFlight = false;
    if (!mounted) return;
    setState(() => _paying = false);
    _snack('Payment failed: ${r.message ?? 'Unknown'}');
  }

  void _onWallet(ExternalWalletResponse r) {
    if (!mounted) return;
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
    return Stack(children: [
    Scaffold(
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
                      Row(children: [
                        GestureDetector(
                          // Before launch there is no alarm setup to go back
                          // to, so the arrow is hidden.
                          onTap: _preLaunchSignup
                              ? null
                              : () => Navigator.pushReplacementNamed(
                                  context, AppRoutes.alarmSetup),
                          child: Opacity(
                            opacity: _preLaunchSignup ? 0 : 1,
                            child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                                color: C.white, shape: BoxShape.circle),
                            child: const Icon(Icons.arrow_back_ios_new_rounded,
                                size: 16, color: C.ink),
                          ),
                          ),
                        ),
                        Expanded(
                          child: Image.asset('assets/images/logo.png',
                              height: 54,
                              errorBuilder: (_, __, ___) => Text('ElderZha',
                                  textAlign: TextAlign.center,
                                  style: poppins(24,
                                      w: FontWeight.w800, c: C.ink))),
                        ),
                        const SizedBox(width: 40),
                      ]),
                      const SizedBox(height: 10),
                      Text('Almost there! 🎉',
                          style:
                              poppins(13, w: FontWeight.w600, c: C.yellowDeep)),
                      const SizedBox(height: 2),
                      Text('Choose your plan',
                          style: poppins(27,
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
                          _promoSection(),
                          if (_promoApplied != null) _offerBanner(),
                          if (_promoApplied != null && _promoIsTrial)
                            _trialBreakdown(),
                          const SizedBox(height: 14),
                          ..._plans.map<Widget>(_planCard),
                          if (_promoApplied != null && _promoIsTrial) ...[
                            const SizedBox(height: 4),
                            _setupAmountNotice(),
                          ],
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
                                      : Text(_promoIsTrial
                                          ? '🎁 Start free trial · ₹0 plan fee today'
                                          : '⚡ Subscribe with Razorpay',
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
    ),
    // Confetti burst — plays when a promo code is successfully applied
    Align(
      alignment: Alignment.topCenter,
      child: ConfettiWidget(
        confettiController: _confettiController,
        blastDirectionality: BlastDirectionality.explosive,
        shouldLoop: false,
        numberOfParticles: 30,
        gravity: 0.3,
        colors: const [C.yellow, C.green, C.ink, Colors.pinkAccent, Colors.blueAccent],
      ),
    ),
    ]);
  }

  String _rs(double v) =>
      '₹${_formatAmount(v).replaceAll(RegExp(r'\.00$'), '')}';

  void _clearPromo() {
    _promoApplied = null;
    _promoValue = null;
    _promoFullAmount = null;
    _promoBillingNote = null;
    _promoIsTrial = false;
    _promoFirstDebit = null;
    _promoLaunch = null;
  }

  // "Have a promo code?" card, or the green "Promo code applied!" strip.
  Widget _promoSection() {
    if (_promoApplied != null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: C.greenLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: C.green.withOpacity(.25)),
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration:
                const BoxDecoration(color: C.green, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text('Promo code applied!',
                  style: poppins(14, w: FontWeight.w800, c: C.ink))),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
            decoration: BoxDecoration(
                color: C.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.bd)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_promoApplied!,
                  style: poppins(13, w: FontWeight.w800, c: C.ink)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() {
                  _clearPromo();
                  _promoCtrl.clear();
                }),
                child: const Icon(Icons.cancel_outlined,
                    size: 20, color: C.txl),
              ),
            ]),
          ),
        ]),
      );
    }
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1EC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF7CFC2)),
        ),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: const Color(0xFFE8334F),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.percent_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Have a promo code?',
                  style: poppins(15, w: FontWeight.w800, c: C.ink)),
              Text('Enter it below to unlock your special offer.',
                  style: poppins(12, c: C.txm, h: 1.35)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child: TextField(
          controller: _promoCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'Enter promo code',
            prefixIcon: Icon(Icons.local_offer_outlined, size: 18),
          ),
        )),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _checkingPromo ? null : _validatePromo,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: C.ink, borderRadius: BorderRadius.circular(14)),
            child: _checkingPromo
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text('Apply',
                    style:
                        poppins(14, w: FontWeight.w700, c: Colors.white)),
          ),
        ),
      ]),
    ]);
  }

  // Big green offer banner shown after a code is applied.
  Widget _offerBanner() {
    final plan = _rs(_promoFullAmount ?? _planAmount);
    final first = parseYmd(_promoFirstDebit);
    final String big;
    final String small;
    if (_promoIsTrial) {
      big = 'FREE TRIAL';
      small = first == null
          ? 'Then just $plan/month'
          : 'Free until ${fmtDay(first)}  ·  then just $plan/month';
    } else {
      big = 'Pay ${_rs(_promoValue ?? 0)} today';
      small = 'Then just $plan/month';
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFF2FBD9), Color(0xFFDDF5C4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBFE39B)),
      ),
      child: Row(children: [
        const Icon(Icons.card_giftcard_rounded,
            size: 50, color: Color(0xFFE53935)),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(big,
                style: poppins(26,
                    w: FontWeight.w900, c: const Color(0xFF14702C), h: 1.1)),
            const SizedBox(height: 4),
            Text(small,
                style: poppins(12.5,
                    w: FontWeight.w700, c: const Color(0xFF1F4D2B), h: 1.35)),
          ]),
        ),
      ]),
    );
  }

  static const _features = <(IconData, Color, String)>[
    (Icons.directions_run_rounded, Color(0xFFF59E0B), 'Physical\nFitness'),
    (Icons.restaurant_rounded, Color(0xFFE53935), 'Food\nReminder'),
    (Icons.medication_rounded, Color(0xFF3B82F6), 'Medical\nReminder'),
    (Icons.personal_injury_rounded, Color(0xFFE53935), 'Fall\nDetection'),
    (Icons.menu_book_rounded, Color(0xFF0E9AA7), 'Learning\n& Fun'),
    (Icons.event_note_rounded, Color(0xFF6D4AD0), 'Daily\nRoutine'),
    (Icons.sentiment_satisfied_alt_rounded, Color(0xFFF59E0B), 'Happiness'),
    (Icons.verified_user_rounded, Color(0xFF22A85A), 'Independence'),
  ];

  Widget _featureGrid() => Column(children: [
        for (var r = 0; r < 2; r++)
          Padding(
            padding: EdgeInsets.only(top: r == 0 ? 0 : 8),
            child: Row(children: [
              for (var c = 0; c < 4; c++)
                Expanded(
                  child: Container(
                    margin: EdgeInsets.only(left: c == 0 ? 0 : 6),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                        color: C.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: C.bd.withOpacity(.6))),
                    child: Column(children: [
                      Icon(_features[r * 4 + c].$1,
                          size: 28, color: _features[r * 4 + c].$2),
                      const SizedBox(height: 6),
                      Text(_features[r * 4 + c].$3,
                          textAlign: TextAlign.center,
                          style: poppins(10.5,
                              w: FontWeight.w600, c: C.ink, h: 1.2)),
                    ]),
                  ),
                ),
            ]),
          ),
      ]);

  // Explains the small AutoPay set-up amount charged by the bank/UPI app.
  Widget _setupAmountNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.yellow, width: 1.5),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline_rounded, color: C.yellowDeep, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('About the AutoPay set-up amount',
                style: poppins(13.5, w: FontWeight.w800, c: C.ink)),
            const SizedBox(height: 4),
            Text(
                'To set up AutoPay, your bank needs a small amount of '
                '₹1 to ₹5 (depends on your bank). Once the set-up is done, '
                'the same amount is refunded to you.',
                style: poppins(12, w: FontWeight.w600, c: C.txm, h: 1.45)),
          ]),
        ),
      ]),
    );
  }

  Widget _autoPayBox() {
    final first = parseYmd(_promoFirstDebit);
    final plan = _rs(_promoFullAmount ?? _planAmount);
    final String text;
    if (_promoApplied != null && _promoIsTrial) {
      text = first == null
          ? 'After your free trial, this plan renews at $plan/month. '
              'You can turn off auto pay anytime from My Profile settings.'
          : 'After your free trial ends on ${fmtDay(first)}, this plan renews '
              'at $plan/month. You can turn off auto pay anytime from My '
              'Profile settings.';
    } else if (_promoApplied != null) {
      text = '${_renewalText().replaceAll(RegExp(r'\.$'), '')}. You can turn off auto pay anytime from My '
          'Profile settings.';
    } else {
      text = 'This plan renews automatically every month. You can disable '
          'auto pay later from My Profile settings.';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.yellowMid,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.yellowBorder),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.autorenew_rounded, color: C.yellowDeep, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Monthly auto pay',
                style: poppins(14, w: FontWeight.w800, c: C.ink)),
            const SizedBox(height: 2),
            Text(text,
                style: poppins(11.5,
                    w: FontWeight.w600, c: C.yellowDeep, h: 1.4)),
          ]),
        ),
      ]),
    );
  }

  Widget _planCard(dynamic plan) {
    final sel = _selPlanId == plan['id'];
    final isYear = (plan['duration_type'] ?? plan['type'] ?? '')
        .toString()
        .toLowerCase()
        .contains('year');
    return GestureDetector(
      onTap: () => setState(() {
        _selPlanId = plan['id'];
        _clearPromo();
        _promoCtrl.clear();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: sel ? C.yellowLight : C.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: sel ? C.yellow : C.bd, width: sel ? 2 : 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                  color: sel ? C.ink : C.bg3,
                  borderRadius: BorderRadius.circular(8)),
              child: Text(
                  (sel && _promoIsTrial)
                      ? 'Pre-launch offer'
                      : (isYear ? 'Save ₹189' : 'Popular'),
                  style: poppins(10.5,
                      w: FontWeight.w700, c: sel ? C.yellow : C.txl)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(_planName(plan),
              style: poppins(18, w: FontWeight.w800, c: C.ink)),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_amount(plan),
                style: poppins(30, w: FontWeight.w900, c: C.ink, h: 1.15)),
            Padding(
                padding: const EdgeInsets.only(bottom: 5, left: 3),
                child: Text(_period(plan), style: poppins(13, c: C.txl))),
          ]),
          const SizedBox(height: 2),
          Text('Full access to all ElderZha features',
              style: poppins(13, w: FontWeight.w700, c: C.ink)),
          if (sel) ...[
            const SizedBox(height: 12),
            _featureGrid(),
            const SizedBox(height: 12),
            _autoPayBox(),
          ],
        ]),
      ),
    );
  }

  // Price breakdown shown once an Early Bird code is applied.
  Widget _trialBreakdown() {
    final plan = _promoFullAmount ?? _planAmount;
    final first = parseYmd(_promoFirstDebit);
    final amt = '₹${_formatAmount(plan)}';
    Widget row(String l, String r, {Color? c, bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(
                child: Text(l,
                    style: poppins(12.5,
                        w: bold ? FontWeight.w800 : FontWeight.w500,
                        c: c ?? C.txm))),
            Text(r,
                style: poppins(bold ? 18 : 12.5,
                    w: bold ? FontWeight.w800 : FontWeight.w600,
                    c: c ?? C.ink)),
          ]),
        );
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.bd, width: 1.5),
      ),
      child: Column(children: [
        row('Subscription (Monthly)', amt),
        row('Discount (${_promoApplied ?? ''})', '- $amt', c: C.green),
        const Divider(height: 16),
        row('Amount payable now', '₹0', bold: true),
        if (first != null) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
                'Free until ${fmtDay(first)}. Then $amt a month by AutoPay. '
                'Cancel before then and you will not be charged.',
                style: poppins(11, c: C.txl, h: 1.4)),
          ),
        ],
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
