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
    await _scheduleSetupAlarmsAfterPayment();
  }

  @override
  Widget build(BuildContext context) {
    // Args passed from payment screen after confirmation
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
            {};
    final paymentId = args['payment_id'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          const _ConfettiLayer(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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

                    if (paymentId.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Payment ID: $paymentId',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.inkLight,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 36),
                    EzButton(
                      label: 'Go to Home →',
                      onTap: () => Navigator.pushNamedAndRemoveUntil(
                          context, AppRoutes.home, (route) => false),
                    ),
                  ],
                ),
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
