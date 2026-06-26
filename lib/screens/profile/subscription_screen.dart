import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/services.dart';
import '../../widgets/yellow_header_scaffold.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _subService = SubscriptionService();
  int _tab = 0;
  bool _loading = true;
  Map<String, dynamic>? _plan;
  Map<String, dynamic>? _subStatus;
  List _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _subService.getPurchasedPlan(),
      _subService.getSubscriptionStatus(),
      _subService.getPaymentHistory(),
    ]);
    if (!mounted) return;
    setState(() {
      _plan = _extractPlan(results[0]);
      _subStatus = results[1]?['subscription'] ?? results[1]?['data'];
      _history = _extractList(results[2]);
      _loading = false;
    });
  }

  Map<String, dynamic>? _extractPlan(Map<String, dynamic>? res) {
    final data = res?['data'];
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  List _extractList(Map<String, dynamic>? res) {
    final data = res?['data'];
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'] as List;
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return YellowHeaderScaffold(
      headerHeight: 170,
      headerContent: Padding(
        padding: const EdgeInsets.fromLTRB(24, 52, 24, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Subscription',
              style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              _tabBtn('Plan', 0),
              _tabBtn('Payments', 1),
            ]),
          ),
        ]),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.yellowDark))
          : _tab == 0
              ? _planTab()
              : _paymentsTab(),
    );
  }

  Widget _tabBtn(String label, int i) {
    final sel = _tab == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: sel ? AppColors.bgCard : Colors.transparent,
              borderRadius: BorderRadius.circular(8)),
          child: Center(
              child: Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      color: sel
                          ? AppColors.ink
                          : AppColors.ink.withOpacity(0.5)))),
        ),
      ),
    );
  }

  Widget _planTab() {
    final isAutoActive = _subStatus?['auto_pay_status'] == 'active' ||
        _subStatus?['razorpay_status'] == 'active';
    final planName = _plan?['plan_name'] ??
        _plan?['name'] ??
        _plan?['type'] ??
        'No active plan';
    final amount =
        _plan?['amount'] ?? _plan?['price'] ?? _plan?['plan_amount'] ?? '0';
    final startDate = _plan?['start_date'] ?? _plan?['created_at'] ?? '';
    final endDate = _plan?['end_date'] ??
        _plan?['expiry_date'] ??
        _subStatus?['plan_expiry_date'] ??
        '';

    return ListView(padding: const EdgeInsets.all(20), children: [
      // Current plan card
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFFFCC01), Color(0xFFFFE566)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.star_rounded, color: AppColors.yellowDeep),
            const SizedBox(width: 6),
            Text('ACTIVE PLAN',
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.yellowDeep,
                    letterSpacing: 1)),
          ]),
          const SizedBox(height: 8),
          Text(planName,
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          Text('₹$amount',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.yellowDeep,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(children: [
            _planDetail('Started', startDate),
            const SizedBox(width: 20),
            _planDetail('Expires', endDate),
          ]),
          const SizedBox(height: 12),
          // Monthly renewal status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: isAutoActive ? AppColors.greenLight : AppColors.bgMuted,
                borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                  isAutoActive
                      ? Icons.autorenew_rounded
                      : Icons.autorenew_rounded,
                  size: 14,
                  color: isAutoActive ? AppColors.green : AppColors.inkMuted),
              const SizedBox(width: 4),
              Text(
                  isAutoActive
                      ? 'Monthly renewal active'
                      : 'Monthly renewal inactive',
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color:
                          isAutoActive ? AppColors.green : AppColors.inkMuted)),
            ]),
          ),
          if (isAutoActive) ...[
            const SizedBox(height: 10),
            Text(
              'This plan renews automatically every month. To disable future renewals, go to My Profile → AutoPay settings.',
              style: GoogleFonts.poppins(
                  fontSize: 12, height: 1.45, color: AppColors.yellowDeep),
            ),
          ],
        ]),
      ),
    ]);
  }

  Widget _planDetail(String label, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style:
                GoogleFonts.poppins(fontSize: 11, color: AppColors.yellowDeep)),
        Text(value.isNotEmpty ? value : '—',
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
      ]);

  Widget _paymentsTab() {
    if (_history.isEmpty) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(40),
              child: Text('No payment history',
                  style: GoogleFonts.poppins(color: AppColors.inkMuted))));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _history.length,
      itemBuilder: (_, i) {
        final p = _history[i];
        final name = p['plan_name'] ?? p['name'] ?? p['type'] ?? 'Plan';
        final date = p['purchase_date'] ?? p['created_at'] ?? p['date'] ?? '';
        final amount = p['amount'] ?? p['price'] ?? '';
        final method = p['payment_method'] ?? p['method'] ?? 'UPI';
        final status = p['payment_status'] ?? p['status'] ?? 'paid';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border)),
          child: Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.receipt_long_rounded,
                    color: AppColors.green, size: 18)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name,
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('$date • $method',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppColors.inkMuted)),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹$amount',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    borderRadius: BorderRadius.circular(4)),
                child: Text(status.toString().toUpperCase(),
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.green)),
              ),
            ]),
          ]),
        );
      },
    );
  }
}
