import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/services.dart';
import '../../theme/app_theme.dart';

class AutoPaySettingsScreen extends StatefulWidget {
  const AutoPaySettingsScreen({super.key});

  @override
  State<AutoPaySettingsScreen> createState() => _AutoPaySettingsScreenState();
}

class _AutoPaySettingsScreenState extends State<AutoPaySettingsScreen> {
  final _subService = SubscriptionService();
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic>? _status;
  Map<String, dynamic>? _plan;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _subService.getSubscriptionStatus(),
      _subService.getPurchasedPlan(),
    ]);
    if (!mounted) return;
    setState(() {
      _status = _extractMap(results[0]?['subscription'] ?? results[0]?['data']);
      _plan = _extractPlan(results[1]);
      _loading = false;
    });
  }

  Map<String, dynamic>? _extractMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  Map<String, dynamic>? _extractPlan(Map<String, dynamic>? res) {
    final data = res?['data'];
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  bool get _autoPayActive {
    final status = _status;
    return status?['auto_pay_status'] == 'active' ||
        status?['razorpay_status'] == 'active' ||
        status?['status'] == 'active';
  }

  String get _planName => (_plan?['plan_name'] ??
          _plan?['name'] ??
          _plan?['type'] ??
          'Monthly plan')
      .toString();

  Future<void> _disableAutoPay() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Disable AutoPay?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
        content: Text(
          'Your current subscription remains active until the paid period ends. Future monthly renewals will stop.',
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep enabled',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, color: AppColors.ink)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Disable',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _saving = true);
    final res = await _subService.cancelSubscription();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res['message']?.toString() ?? 'AutoPay disabled',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: AppColors.green,
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        Container(
          width: double.infinity,
          color: AppColors.yellow,
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
                        color: AppColors.ink, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AutoPay settings',
                          style: GoogleFonts.poppins(
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink)),
                      Text('Manage monthly renewal',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.yellowDeep)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.yellowDark))
              : ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: _autoPayActive
                                    ? AppColors.greenLight
                                    : AppColors.bgMuted,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(Icons.autorenew_rounded,
                                  color: _autoPayActive
                                      ? AppColors.green
                                      : AppColors.inkMuted),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      _autoPayActive
                                          ? 'AutoPay enabled'
                                          : 'AutoPay disabled',
                                      style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.ink)),
                                  Text(_planName,
                                      style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.inkMuted)),
                                ],
                              ),
                            ),
                            Switch(
                              value: _autoPayActive,
                              activeColor: AppColors.green,
                              inactiveThumbColor: AppColors.inkLight,
                              onChanged: _saving
                                  ? null
                                  : (enabled) {
                                      if (!enabled) {
                                        _disableAutoPay();
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Choose a subscription plan to enable AutoPay again.',
                                              style: GoogleFonts.poppins(),
                                            ),
                                            backgroundColor: AppColors.inkMuted,
                                          ),
                                        );
                                      }
                                    },
                            ),
                          ]),
                          const SizedBox(height: 16),
                          Text(
                            _autoPayActive
                                ? 'Your subscription renews automatically every month through Razorpay. Disable only if you do not want the next monthly renewal.'
                                : 'Monthly renewal is currently disabled. You can subscribe again from the payment flow when needed.',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                height: 1.5,
                                color: AppColors.inkMuted),
                          ),
                          const SizedBox(height: 18),
                          if (_saving)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: CircularProgressIndicator(
                                    color: AppColors.yellowDark),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ]),
    );
  }
}
