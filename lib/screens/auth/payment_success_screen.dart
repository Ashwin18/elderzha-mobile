import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../alaram/alarm_config_store.dart';
import '../../alaram/alarm_permission_service.dart';
import '../../alaram/daily_scheduler.dart';
import '../../alaram/family_event_scheduler.dart';
import '../../api/models/fetch_profile_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_routes.dart';
import '../../utils/ez_dates.dart';
import '../../services/services.dart';
import '../../widgets/ez_button.dart';
import 'benefits_showcase_screen.dart';

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
    // Same Android 14 full-screen-intent check already done on every
    // returning login (otp_screen.dart) — was missing here entirely,
    // meaning a brand-new user's very first alarms could silently
    // degrade to normal notifications until their next login (if ever).
    await AlarmPermissionService.ensureFullScreenIntentPermission();
    await AlarmPermissionService.ensureExactAlarmPermission();
    await AlarmPermissionService.ensureBatteryOptimizationExemption();
    // This is the ONLY place a brand-new user's default wizard alarms
    // ever get scheduled — there's no retry if it fails here, and until
    // now nothing marked whether it actually succeeded. If anything
    // threw partway through (a slow tone download, a MethodChannel
    // hiccup), the user landed on this "all set!" screen with zero
    // alarms actually scheduled, and no way to know. Record success/
    // failure so otp_screen.dart can retry on the next login as a
    // safety net rather than leaving it permanently unscheduled.
    try {
      await _scheduleSetupAlarmsAfterPayment();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('setup_alarms_scheduled_ok', true);
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('setup_alarms_scheduled_ok', false);
      debugPrint('PaymentSuccessScreen: alarm scheduling failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Args passed from payment screen after confirmation
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
            {};
    final paymentId = args['payment_id'] as String? ?? '';
    // Early Bird free trial: nothing was charged, the app opens on launch day.
    final isTrial = args['trial'] == true;
    final firstPay = parseYmd(args['first_debit_date']);
    final launch = parseYmd(args['launch_date']);
    final firstPayAmt = '${args['first_payment'] ?? ''}';

    if (isTrial) {
      return _trialScaffold(
        context,
        promoCode: '${args['promo_code'] ?? ''}',
        firstPay: firstPay,
        launch: launch,
        firstPayAmt: firstPayAmt,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          const _ConfettiLayer(),
          SafeArea(
            child: SingleChildScrollView(
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
                    isTrial ? "You're in, Early Bird! 🎉" : "You're all set! 🎉",
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isTrial
                        ? (launch != null
                            ? 'ElderZha opens fully on ${fmtDay(launch)}'
                            : 'ElderZha opens fully on launch day')
                        : 'Every feature below is unlocked now',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.inkLight,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  if (isTrial) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.greenLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        firstPay == null
                            ? 'Your free trial is on. Nothing was charged today. '
                                'Cancel any time before your first payment and you will not be charged.'
                            : 'Your free trial is on. Nothing was charged today. '
                                '${firstPayAmt.isEmpty ? 'Your first payment' : firstPayAmt} '
                                'will be taken by AutoPay on ${fmtDay(firstPay)}. '
                                'Cancel any time before then and you will not be charged.',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                          height: 1.45,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],

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

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: BenefitsList(unlocked: !isTrial),
                  ),

                  const SizedBox(height: 12),
                  EzButton(
                    label: 'Go to Home →',
                    onTap: () => Navigator.pushNamedAndRemoveUntil(
                        context, AppRoutes.home, (route) => false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Early Bird free-trial confirmation: nothing was charged today.
  Widget _trialScaffold(
    BuildContext context, {
    required String promoCode,
    required DateTime? firstPay,
    required DateTime? launch,
    required String firstPayAmt,
  }) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: C.bgGradient)),
          const _ConfettiLayer(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
              child: Column(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                        color: C.white, shape: BoxShape.circle),
                    child: Stack(alignment: Alignment.center, children: [
                      const Icon(Icons.card_giftcard_rounded,
                          size: 54, color: C.yellowDark),
                      Positioned(
                        right: 18,
                        bottom: 18,
                        child: Container(
                          decoration: const BoxDecoration(
                              color: C.green, shape: BoxShape.circle),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(Icons.check_rounded,
                              size: 18, color: Colors.white),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  Text('Free Trial\nActivated!',
                      textAlign: TextAlign.center,
                      style: poppins(30, w: FontWeight.w800, c: C.ink, h: 1.15)),
                  if (promoCode.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: 'Promo code ',
                            style: poppins(13, c: C.txm)),
                        TextSpan(
                            text: promoCode,
                            style: poppins(13, w: FontWeight.w800, c: C.ink)),
                        TextSpan(
                            text: ' applied successfully.',
                            style: poppins(13, c: C.txm)),
                      ]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: C.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: C.bd),
                    ),
                    child: Column(children: [
                      Text('₹0 Paid Now',
                          style: poppins(24, w: FontWeight.w800, c: C.ink)),
                      const SizedBox(height: 2),
                      Text('Your free trial is reserved.',
                          style: poppins(12.5, c: C.txm)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: C.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: C.yellowBorder, width: 1.5),
                    ),
                    child: Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            color: C.yellowMid,
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.calendar_month_rounded,
                            color: C.yellowDeep),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Full ElderZha experience opens on',
                                style: poppins(12, c: C.txm)),
                            Text(
                                launch != null
                                    ? fmtDayLong(launch)
                                    : 'launch day',
                                style: poppins(16,
                                    w: FontWeight.w800, c: C.ink)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Text('Get ready to explore all features on launch day!',
                      textAlign: TextAlign.center,
                      style: poppins(12.5, c: C.txm)),
                  if (firstPay != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      '${firstPayAmt.isEmpty ? 'Your first payment' : firstPayAmt} '
                      'will be taken by AutoPay on ${fmtDay(firstPay)}. '
                      'Cancel before then and you will not be charged.',
                      textAlign: TextAlign.center,
                      style: poppins(11.5, c: C.txl, h: 1.4),
                    ),
                  ],
                  const SizedBox(height: 22),
                  EzButton(
                    label: 'Go to Countdown',
                    onTap: () => Navigator.pushNamedAndRemoveUntil(
                        context, AppRoutes.home, (route) => false),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRoutes.subscription),
                    child: Text('View Subscription Details',
                        style: poppins(13,
                            w: FontWeight.w600,
                            c: const Color(0xFF2563EB))),
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

    // Separate medical/food tones — these are the CURRENT keys
    // alarm_setup_screen.dart actually saves. Falls back to the old
    // shared keys only for safety (pre-split installs).
    final legacyTone =
        _firstText(config, ['alaram_tone', 'alarm_tone', 'alarmTone']);
    final medicalTone =
        _firstText(config, ['medical_tone']) ?? legacyTone;
    final foodTone =
        _firstText(config, ['food_tone']) ?? legacyTone;
    final medicalImage = _firstText(config, ['medical_file', 'medical_image']);
    final foodImage = _firstText(config, ['food_file', 'food_image']);

    // scheduleReminder() fails soft internally (logs and returns false
    // rather than throwing) so it never crashes this screen — but that
    // also meant a real failure (a MethodChannel hiccup, a slow tone
    // download, etc.) was completely invisible to the caller: this
    // function would finish "successfully" either way, the try/catch
    // in _activateAndScheduleAlarms would mark setup_alarms_scheduled_ok
    // = true, and home_screen's safety-net retry — which only runs
    // when that flag is false — would never fire to try again. A
    // brand-new account's default alarms could end up silently never
    // actually registered with the OS. Now every attempted alarm's
    // real success/failure is counted, and a failure here is rethrown
    // so the flag (and the retry) reflect what actually happened.
    var attempted = 0;
    var failed = 0;
    if (_truthy(config['medical_alarm'])) {
      final r = await _scheduleMedical(config, tone: medicalTone, imageUrl: medicalImage);
      attempted += r.$1;
      failed += r.$2;
    }
    if (_truthy(config['food_alarm'] ?? config['food_alaram'])) {
      final r = await _scheduleFood(config, tone: foodTone, imageUrl: foodImage);
      attempted += r.$1;
      failed += r.$2;
    }
    await _scheduleSetupFamilyEvents();
    if (attempted > 0 && failed > 0) {
      throw Exception('$failed of $attempted default alarm(s) failed to schedule');
    }
  }

  // Returns (attempted, failed) so the caller can tell a real failure
  // apart from "nothing was enabled" — see note above.
  Future<(int, int)> _scheduleMedical(
    Map<String, dynamic> config, {
    required String? tone,
    required String? imageUrl,
  }) async {
    final items = [
      ['morning_before_food', 'm_before_food', 'Morning medication before food'],
      ['morning_after_food', 'm_after_food', 'Morning medication after food'],
      ['afternoon_before_food', 'af_before_food', 'Afternoon medication before food'],
      ['afternoon_after_food', 'af_after_food', 'Afternoon medication after food'],
      ['night_before_food', 'n_before_food', 'Night medication before food'],
      ['night_after_food', 'n_after_food', 'Night medication after food'],
    ];
    var attempted = 0;
    var failed = 0;
    for (final item in items) {
      final time = (config[item[0]] ?? config[item[1]])?.toString().trim() ?? '';
      if (!_filled(time)) continue;
      attempted++;
      final ok = await DailyScheduler.scheduleReminder(
        AlarmType.medical,
        _schedDate(time),
        time,
        'ElderZha • ${item[2]}',
        'daily',
        soundUrl: tone,
        imageUrl: imageUrl,
      );
      if (!ok) failed++;
    }
    return (attempted, failed);
  }

  Future<(int, int)> _scheduleFood(
    Map<String, dynamic> config, {
    required String? tone,
    required String? imageUrl,
  }) async {
    final items = [
      ['breakfast_time', 'bf_time', 'Breakfast reminder'],
      ['lunch_time', 'l_time', 'Lunch reminder'],
      ['dinner_time', 'd_time', 'Dinner reminder'],
    ];
    var attempted = 0;
    var failed = 0;
    for (final item in items) {
      final time = (config[item[0]] ?? config[item[1]])?.toString().trim() ?? '';
      if (!_filled(time)) continue;
      attempted++;
      final ok = await DailyScheduler.scheduleReminder(
        AlarmType.food,
        _schedDate(time),
        time,
        'ElderZha • ${item[2]}',
        'daily',
        soundUrl: tone,
        imageUrl: imageUrl,
      );
      if (!ok) failed++;
    }
    return (attempted, failed);
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
