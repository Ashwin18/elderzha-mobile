import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../alaram/alarm_config_store.dart';
import '../../alaram/daily_scheduler.dart';
import '../../alaram/family_event_scheduler.dart';
import '../../api/models/fetch_profile_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_routes.dart';
import '../../services/services.dart';
import '../../widgets/ez_button.dart';

class PaymentSuccessScreen extends StatefulWidget {
  const PaymentSuccessScreen({super.key});

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  @override
  void initState() {
    super.initState();
    _activateAndScheduleAlarms();
  }

  Future<void> _activateAndScheduleAlarms() async {
    await SubscriptionService.markSubscriptionActiveLocal();
    // Fix 6: Always fetch alarm data from API (not prefs) — works after reinstall
    try {
      final alarmRes = await AlarmService().getMedicalRecords();
      final d = alarmRes?['data'];
      if (d != null && d is Map && d.isNotEmpty) {
        // API has alarm data — use it directly instead of prefs
        await _scheduleFromApiData(Map<String, dynamic>.from(d));
        return;
      }
    } catch (_) {}
    // Fallback to prefs-based scheduling (first time setup)
    await _scheduleSetupAlarmsAfterPayment();
  }

  Future<void> _scheduleFromApiData(Map<String, dynamic> d) async {
    await DailyScheduler.cancelAllAlarms();
    await DailyScheduler.clearStoredAlarms();
    final prefs = await SharedPreferences.getInstance();
    final tone = prefs.getString('alarm_tone');
    final medImg = d['medical_file']?.toString();
    final foodImg = d['food_file']?.toString();
    // Medical
    if ((d['medical_alarm'] ?? 0) == 1) {
      final slots = {
        '💊 Elderzha • Morning Before Food': d['morning_before_food'],
        '💊 Elderzha • Morning After Food':  d['morning_after_food'],
        '💊 Elderzha • Noon Before Food':    d['afternoon_before_food'],
        '💊 Elderzha • Noon After Food':     d['afternoon_after_food'],
        '🌙 Elderzha • Night Before Food':   d['night_before_food'],
        '🌙 Elderzha • Night After Food':    d['night_after_food'],
      };
      for (final e in slots.entries) {
        if (e.value != null && e.value.toString().isNotEmpty) {
          final t = _toTOD(e.value.toString());
          if (t != null) await DailyScheduler.scheduleReminder(
            AlarmType.medical, _schDate(t), _toStr(t), e.key, 'daily',
            soundUrl: tone, imageUrl: medImg);
        }
      }
    }
    // Food
    if ((d['food_alarm'] ?? 0) == 1) {
      if ((d['breakfast_status'] ?? 0) == 1 && d['breakfast_time'] != null) {
        final t = _toTOD(d['breakfast_time'].toString());
        if (t != null) await DailyScheduler.scheduleReminder(
          AlarmType.food, _schDate(t), _toStr(t),
          '🍳 Elderzha • Breakfast Time', 'daily', soundUrl: tone, imageUrl: foodImg);
      }
      if ((d['lunch_status'] ?? 0) == 1 && d['lunch_time'] != null) {
        final t = _toTOD(d['lunch_time'].toString());
        if (t != null) await DailyScheduler.scheduleReminder(
          AlarmType.food, _schDate(t), _toStr(t),
          '🍽 Elderzha • Lunch Reminder', 'daily', soundUrl: tone, imageUrl: foodImg);
      }
      if ((d['dinner_status'] ?? 0) == 1 && d['dinner_time'] != null) {
        final t = _toTOD(d['dinner_time'].toString());
        if (t != null) await DailyScheduler.scheduleReminder(
          AlarmType.food, _schDate(t), _toStr(t),
          '🍽 Elderzha • Dinner Reminder', 'daily', soundUrl: tone, imageUrl: foodImg);
      }
    }
    await _scheduleSetupFamilyEvents();
  }

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

  Future<void> _scheduleSetupAlarmsAfterPayment() async {
    final config = await AlarmConfigStore.load();
    if (config.isEmpty) return;

    await DailyScheduler.cancelAllAlarms();
    await DailyScheduler.clearStoredAlarms();

    final tone = _firstText(config, ['alaram_tone', 'alarm_tone', 'alarmTone']);
    final medicalImage = _firstText(config, ['medical_file', 'medical_image']);
    final foodImage = _firstText(config, ['food_file', 'food_image']);

    if (_truthy(config['medical_alarm'])) {
      await _scheduleMedical(config, tone: tone, imageUrl: medicalImage);
    }
    if (_truthy(config['food_alarm'] ?? config['food_alaram'])) {
      await _scheduleFood(config, tone: tone, imageUrl: foodImage);
    }
    await _scheduleSetupFamilyEvents();
  }

  Future<void> _scheduleMedical(
    Map<String, dynamic> config, {
    required String? tone,
    required String? imageUrl,
  }) async {
    final items = [
      ['morning_before_food', 'Morning medication before food'],
      ['morning_after_food', 'Morning medication after food'],
      ['afternoon_before_food', 'Afternoon medication before food'],
      ['afternoon_after_food', 'Afternoon medication after food'],
      ['night_before_food', 'Night medication before food'],
      ['night_after_food', 'Night medication after food'],
    ];
    for (final item in items) {
      final key = item[0];
      final time = config[key]?.toString().trim() ?? '';
      if (!_filled(time)) continue;
      await DailyScheduler.scheduleReminder(
        AlarmType.medical,
        _schedDate(time),
        time,
        'ElderZha • ${item[1]}',
        'daily',
        soundUrl: tone,
        imageUrl: imageUrl,
      );
    }
  }

  Future<void> _scheduleFood(
    Map<String, dynamic> config, {
    required String? tone,
    required String? imageUrl,
  }) async {
    final items = [
      ['breakfast_time', 'Breakfast reminder'],
      ['lunch_time', 'Lunch reminder'],
      ['dinner_time', 'Dinner reminder'],
    ];
    for (final item in items) {
      final key = item[0];
      final time = config[key]?.toString().trim() ?? '';
      if (!_filled(time)) continue;
      await DailyScheduler.scheduleReminder(
        AlarmType.food,
        _schedDate(time),
        time,
        'ElderZha • ${item[1]}',
        'daily',
        soundUrl: tone,
        imageUrl: imageUrl,
      );
    }
  }

  Future<void> _scheduleSetupFamilyEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('setup_family_members');
    if (raw == null || raw.trim().isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return;

    final members = <FamilyMember>[];
    for (final entry in decoded.whereType<Map>().toList().asMap().entries) {
      final item = entry.value;
      final name = item['name']?.toString() ?? '';
      final relation = item['relation']?.toString() ?? '';
      void add(String suffix, String eventName, String date) {
        if (!_filled(date)) return;
        members.add(FamilyMember(
          id: 'setup-${entry.key}-$suffix',
          type: '',
          status: '1',
          name: name,
          eventDate: date,
          relation: Event(id: '0', name: relation),
          event:
              Event(id: suffix == 'anniversary' ? '2' : '1', name: eventName),
        ));
      }

      add('birthday', 'Birthday', item['birthday_date']?.toString() ?? '');
      add('anniversary', 'Anniversary',
          item['anniversary_date']?.toString() ?? '');
    }
    if (members.isNotEmpty) {
      await FamilyEventScheduler.syncFamilyEventReminders(members);
    }
  }

  String _schedDate(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    var dt = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      hour,
      minute,
    );
    if (dt.isBefore(DateTime.now())) dt = dt.add(const Duration(days: 1));
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  String? _firstText(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (_filled(value)) return value;
    }
    return null;
  }

  bool _truthy(dynamic value) {
    if (value == true) return true;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase().trim() ?? '';
    return text == '1' || text == 'true' || text == 'yes' || text == 'active';
  }

  bool _filled(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isNotEmpty && text.toLowerCase() != 'null';
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
