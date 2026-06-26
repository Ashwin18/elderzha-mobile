import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_routes.dart';
import '../../widgets/ez_button.dart';

class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Args passed from payment screen after confirmation
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
            {};
    final planName = args['plan_name'] as String? ?? 'Wellness Plan';
    final paymentId = args['payment_id'] as String? ?? '';
    final isAutoPay = args['auto_pay'] as bool? ?? false;
    final firstMonthFree = args['first_month_free'] as bool? ?? false;
    final recurringAmount = args['recurring_amount']?.toString() ?? '99.00';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          const _ConfettiLayer(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // Success icon
                  Container(
                    width: 90,
                    height: 90,
                    decoration: const BoxDecoration(
                      color: AppColors.greenLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      size: 52,
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Payment Successful! 🎉',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    firstMonthFree
                        ? '1st Month Rs 0, then Rs $recurringAmount/ Monthly'
                        : 'Your $planName is now active.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.inkMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  // Plan badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isAutoPay
                          ? AppColors.yellowSoft
                          : AppColors.blueLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isAutoPay
                            ? AppColors.yellowDark.withOpacity(0.3)
                            : AppColors.blue.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAutoPay
                              ? Icons.autorenew_rounded
                              : Icons.payment_rounded,
                          size: 16,
                          color:
                              isAutoPay ? AppColors.yellowDeep : AppColors.blue,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isAutoPay
                              ? 'Auto Pay enabled — renews automatically'
                              : firstMonthFree
                                  ? 'First month free coupon applied'
                                  : 'One-time payment confirmed',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isAutoPay
                                ? AppColors.yellowDeep
                                : AppColors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (paymentId.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Payment ID: $paymentId',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.inkLight,
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Alarms summary
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Your scheduled alarms',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _loadAlarmSummary(),
                    builder: (context, snap) {
                      final alarms =
                          snap.data ?? const <Map<String, dynamic>>[];
                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.bgCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: alarms.asMap().entries.map((e) {
                            final alarm = e.value;
                            final isLast = e.key == alarms.length - 1;
                            final color = _alarmColor(
                              alarm['icon']?.toString() ?? '',
                            );
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      Text(
                                        alarm['icon']?.toString() ?? '🔔',
                                        style: const TextStyle(fontSize: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          alarm['label']?.toString() ??
                                              'Reminder',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          alarm['time']?.toString() ?? '',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isLast)
                                  const Divider(
                                    height: 1,
                                    indent: 14,
                                    endIndent: 14,
                                  ),
                              ],
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),
                  EzButton(
                    label: 'Go to Home →',
                    onTap: () =>
                        Navigator.pushReplacementNamed(context, AppRoutes.home),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadAlarmSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('setup_alarm_summary');
    if (raw == null || raw.isEmpty) {
      return [
        {
          'label': 'Medical and food alarms configured',
          'time': 'Active',
          'icon': '🔔',
        },
      ];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded.whereType<Map>().map((item) {
      return item.map((key, value) => MapEntry('$key', value));
    }).toList();
  }

  Color _alarmColor(String icon) {
    if (icon.contains('🍳') || icon.contains('🍱') || icon.contains('🍽')) {
      return AppColors.green;
    }
    if (icon.contains('🎂') || icon.contains('💍')) {
      return AppColors.purple;
    }
    if (icon.contains('🌙')) return AppColors.purple;
    return AppColors.orange;
  }
}

class _ConfettiLayer extends StatefulWidget {
  const _ConfettiLayer();

  @override
  State<_ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiLayerState extends State<_ConfettiLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _pieces = const [
    (0.06, 0.10, AppColors.yellowDark, 8.0),
    (0.18, 0.02, AppColors.green, 7.0),
    (0.30, 0.12, AppColors.blue, 6.0),
    (0.44, 0.05, AppColors.yellowDeep, 9.0),
    (0.58, 0.14, AppColors.red, 7.0),
    (0.72, 0.04, AppColors.green, 8.0),
    (0.86, 0.11, AppColors.yellowDark, 6.0),
    (0.96, 0.03, AppColors.blue, 7.0),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final size = MediaQuery.of(context).size;
          final t = Curves.easeOut.transform(_controller.value);
          return Stack(
            children: [
              for (final p in _pieces)
                Positioned(
                  left: size.width * p.$1,
                  top: size.height * (p.$2 + .25 * t),
                  child: Opacity(
                    opacity: (1 - t).clamp(0, 1),
                    child: Transform.rotate(
                      angle: t * 5.8,
                      child: Container(
                        width: p.$4,
                        height: p.$4 * 1.7,
                        decoration: BoxDecoration(
                          color: p.$3,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
