// lib/screens/auth/autopay_setup_screen.dart
//
// Turns AutoPay on for a plan the user has ALREADY paid for (people who
// bought before AutoPay existed, or who switched it off). Nothing is charged
// for the plan today — the Razorpay subscription is created to start billing
// exactly when the current plan ends, so the plan just keeps renewing.
// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../services/plan_state.dart';
import '../../services/services.dart';
import '../../theme/app_theme.dart';

class AutoPaySetupScreen extends StatefulWidget {
  const AutoPaySetupScreen({super.key});
  @override
  State<AutoPaySetupScreen> createState() => _AutoPaySetupScreenState();
}

class _AutoPaySetupScreenState extends State<AutoPaySetupScreen> {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  final _svc = SubscriptionService();
  late Razorpay _rzp;

  bool _busy = false;
  bool _done = false;
  bool _handled = false;
  String? _error;
  int? _purchaseId;
  String? _subscriptionId;

  @override
  void initState() {
    super.initState();
    _rzp = Razorpay();
    _rzp.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _rzp.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _rzp.on(Razorpay.EVENT_EXTERNAL_WALLET, _onWallet);
    PlanState.loadStatus();
  }

  @override
  void dispose() {
    PlanState.paymentInFlight = false;
    _rzp.clear();
    super.dispose();
  }

  DateTime? get _end {
    final t = '${PlanState.status.value?['plan_expiry_date'] ?? ''}';
    if (t.isEmpty || t == 'null') return null;
    return DateTime.tryParse(t.replaceFirst(' ', 'T'));
  }

  String _fmt(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  Future<void> _start() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final planId = int.tryParse('${PlanState.status.value?['plan_id'] ?? ''}');
    final res = await _svc.enableAutoPay(planId: planId);
    if (!mounted) return;
    if (res['status'] != true) {
      setState(() {
        _busy = false;
        _error = (res['message'] ?? 'Could not set up AutoPay. Please try again.')
            .toString();
      });
      return;
    }

    final data = res['data'] is Map ? res['data'] as Map : {};
    final subId = data['subscription_id']?.toString();
    final purchaseId = int.tryParse('${data['purchase_id'] ?? ''}');
    var key = data['razorpay_key']?.toString();
    if (key == null || key.isEmpty) {
      final creds = await _svc.getRazorpayCredentials();
      key = (creds?['key_id'] ??
              creds?['RAZORPAY_KEY'] ??
              creds?['data']?['key_id'])
          ?.toString();
    }
    if (!mounted) return;
    if (subId == null || purchaseId == null || key == null || key.isEmpty) {
      setState(() {
        _busy = false;
        _error = 'Could not set up AutoPay. Please try again.';
      });
      return;
    }
    _subscriptionId = subId;
    _purchaseId = purchaseId;
    _handled = false;

    try {
      PlanState.paymentInFlight = true;
      _rzp.open({
        'key': key,
        'subscription_id': subId,
        'name': 'ElderZha',
        'description': data['description'] ?? 'ElderZha AutoPay',
        'prefill': {
          'name': data['user_name'],
          'contact': data['user_phone'],
        },
        'theme': {'color': '#FFCC01'},
      });
    } catch (e) {
      PlanState.paymentInFlight = false;
      setState(() {
        _busy = false;
        _error = 'Could not open the payment screen: $e';
      });
    }
  }

  void _onSuccess(PaymentSuccessResponse r) async {
    if (_handled) return;
    _handled = true;
    // Same safe path as a normal payment: saved first, retried if the
    // network drops, never lost.
    final confirmed = await _svc.finishPayment(
      purchaseId: _purchaseId ?? 0,
      subscriptionId: _subscriptionId ?? '',
      paymentId: r.paymentId ?? '',
      signature: r.signature ?? '',
    );
    PlanState.paymentInFlight = false;
    await PlanState.loadStatus();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (confirmed) {
        _done = true;
      } else {
        _error = 'AutoPay was authorised. We are finishing the set-up — '
            'this can take a minute. You can leave this screen.';
      }
    });
  }

  void _onError(PaymentFailureResponse r) {
    PlanState.paymentInFlight = false;
    if (!mounted) return;
    setState(() {
      _busy = false;
      _handled = false;
      _error = 'AutoPay was not set up: ${r.message ?? 'cancelled'}';
    });
  }

  void _onWallet(ExternalWalletResponse r) {
    if (!mounted) return;
    setState(() => _busy = false);
  }

  Widget _point(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: C.yellowDeep),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: poppins(13, c: C.txm, h: 1.45))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final end = _end;
    final endText = end == null ? 'the end of your current plan' : _fmt(end);
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(children: [
        Container(
          width: double.infinity,
          color: C.yellow,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: C.ink, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Set up AutoPay',
                          style: poppins(23, w: FontWeight.w800)),
                      Text('Never miss a renewal',
                          style: poppins(12,
                              w: FontWeight.w600, c: C.yellowDeep)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(18), children: [
            if (_done)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: C.greenLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 52, color: C.green),
                  const SizedBox(height: 10),
                  Text('AutoPay is on',
                      style: poppins(20, w: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                      'Your plan will renew automatically on $endText. '
                      'You do not need to do anything.',
                      textAlign: TextAlign.center,
                      style: poppins(13, c: C.txm, h: 1.45)),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: C.ink,
                          borderRadius: BorderRadius.circular(14)),
                      child: Text('Done',
                          style: poppins(14,
                              w: FontWeight.w700, c: Colors.white)),
                    ),
                  ),
                ]),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: C.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: C.bd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How it works',
                        style: poppins(15, w: FontWeight.w800)),
                    const SizedBox(height: 12),
                    _point(Icons.payments_outlined,
                        'Nothing is charged for your plan today — it is already paid until $endText.'),
                    _point(Icons.autorenew_rounded,
                        'On $endText your plan renews automatically, so polls, activities and alarms never stop.'),
                    _point(Icons.account_balance_outlined,
                        'Your bank or UPI app will ask you to approve the AutoPay once. Some banks may make a tiny verification charge, which is refunded.'),
                    _point(Icons.cancel_outlined,
                        'You can switch AutoPay off any time from Profile.'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: C.redLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child:
                      Text(_error!, style: poppins(12, c: C.red, h: 1.4)),
                ),
                const SizedBox(height: 12),
              ],
              GestureDetector(
                onTap: _busy ? null : _start,
                child: Container(
                  width: double.infinity,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: C.ink, borderRadius: BorderRadius.circular(14)),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: C.yellow, strokeWidth: 2))
                      : Text('Set up AutoPay',
                          style: poppins(15,
                              w: FontWeight.w700, c: Colors.white)),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                  child: Text('Secured by Razorpay',
                      style: poppins(11, c: C.txl))),
            ],
          ]),
        ),
      ]),
    );
  }
}
