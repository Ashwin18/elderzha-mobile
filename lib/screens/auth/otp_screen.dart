import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../../alaram/daily_scheduler.dart';
import '../../alaram/family_event_scheduler.dart';
import '../../alaram/alarm_permission_service.dart';
import '../../api/models/fetch_profile_model.dart';
import '../../services/services.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_routes.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _ctrls = List.generate(4, (_) => TextEditingController());
  final _focusNodes = List.generate(4, (_) => FocusNode());
  int _cd = 30;
  Timer? _timer;
  bool _loading = false;

  String get _phone {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) return args['phone'] ?? '';
    return args as String? ?? '';
  }

  Map<String, dynamic> get _profileArgs {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      return {
        'phone': args['phone'] ?? '',
        'name': args['name'] ?? '',
        'gender': args['gender'] ?? '',
      };
    }
    return {'phone': _phone};
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNodes[0].requestFocus(),
    );
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _cd = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_cd > 0)
          _cd--;
        else
          t.cancel();
      });
    });
  }

  String get _otp => _ctrls.map((c) => c.text).join();

  void _onChange(int i, String v) {
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 1) {
      _applyOtpCode(digits);
      return;
    }
    if (v.isNotEmpty && i < 3) _focusNodes[i + 1].requestFocus();
    if (v.isEmpty && i > 0) _focusNodes[i - 1].requestFocus();
    if (_otp.length == 4) _verify();
  }

  void _applyOtpCode(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return;
    final code = digits.substring(0, 4);
    for (var i = 0; i < _ctrls.length; i++) {
      _ctrls[i].text = code[i];
    }
    FocusScope.of(context).unfocus();
    _verify();
  }

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.register,
      (route) => false,
    );
  }

  KeyEventResult _handleOtpKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.backspace) {
      return KeyEventResult.ignored;
    }
    if (_ctrls[index].text.isEmpty && index > 0) {
      _ctrls[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _verify() async {
    if (_otp.length < 4 || _loading) return;
    setState(() => _loading = true);

    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyOtp(_phone, _otp);
    if (!mounted) return;

    if (!ok) {
      setState(() => _loading = false);
      for (final c in _ctrls) c.clear();
      _focusNodes[0].requestFocus();
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'OTP wrongly entered',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Please check the 4-digit code and try again.',
            style: GoogleFonts.poppins(fontSize: 13, color: C.txm),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Try again',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: C.ink,
                ),
              ),
            ),
          ],
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              auth.error ?? 'OTP wrongly entered',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: C.red,
          ),
        );
      }
      return;
    }

    // ── POST LOGIN: Schedule all alarms ─────────────────────────────────────
    _scheduleAlarmsAfterLogin();

    await auth.loadUser();
    final profileRes = await AuthService().getProfileWithFamily();
    final profile = _extractUser(profileRes) ?? auth.user;
    if (!mounted) return;

    if (!_isProfileComplete(profile)) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.setupProfile,
        arguments: {
          ..._profileArgs,
          if (profile?['name'] != null) 'name': profile?['name'],
          if (profile?['gender'] != null) 'gender': profile?['gender'],
        },
      );
      return;
    }

    final alarm = await AlarmService().getMedicalRecords();
    if (!mounted) return;
    if (!_hasAlarmSetup(alarm)) {
      Navigator.pushReplacementNamed(context, AppRoutes.alarmSetup);
      return;
    }

    final paymentGateCompleted =
        await SubscriptionService.hasCompletedPaymentGate();
    final hasActiveSubscription = paymentGateCompleted
        ? true
        : await SubscriptionService().hasActiveSubscription();
    if (!mounted) return;
    if (hasActiveSubscription) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.payment);
    }
  }

  Map<String, dynamic>? _extractUser(Map<String, dynamic>? res) {
    dynamic node = res?['user'] ?? res?['profile'] ?? res?['data'];
    if (node is Map && node['user'] is Map) node = node['user'];
    if (node is Map && node['profile'] is Map) node = node['profile'];
    if (node is Map) return Map<String, dynamic>.from(node);
    return null;
  }

  bool _isProfileComplete(Map<String, dynamic>? user) {
    if (user == null) return false;
    final explicit = user['is_profile_updated'] ??
        user['profile_completed'] ??
        user['profile_status'];
    if (_truthy(explicit)) return true;
    final percent = int.tryParse(
          (user['profile_updated_percentage'] ??
                  user['profile_percentage'] ??
                  '')
              .toString(),
        ) ??
        0;
    if (percent >= 60) return true;
    bool hasAny(List<String> keys) =>
        keys.any((k) => (user[k]?.toString().trim().isNotEmpty ?? false));
    return hasAny(['name', 'full_name', 'user_name']) &&
        hasAny(['dob', 'date_of_birth', 'birth_date']) &&
        hasAny(['gender', 'sex']);
  }

  bool _hasAlarmSetup(Map<String, dynamic>? res) {
    dynamic data = res?['data'] ?? res;
    if (data is Map && data['data'] is Map) data = data['data'];
    if (data is! Map) return false;
    return _truthy(data['medical_alarm']) ||
        _truthy(data['food_alarm']) ||
        data['morning_before_food'] != null ||
        data['breakfast_time'] != null;
  }

  bool _truthy(dynamic value) {
    if (value == true) return true;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase().trim();
    return text == '1' ||
        text == 'true' ||
        text == 'yes' ||
        text == 'completed' ||
        text == 'approved' ||
        text == 'active';
  }

  // ── Schedule all alarms from saved API data ───────────────────────────────
  Future<void> _scheduleAlarmsAfterLogin() async {
    try {
      await AlarmPermissionService.ensureFullScreenIntentPermission();

      // 1. Get medical/food alarms from API and schedule
      final alarmRes = await AlarmService().getMedicalRecords();
      final d = alarmRes?['data'];
      if (d != null && d is Map) {
        final prefs = await SharedPreferences.getInstance();
        final tone = prefs.getString('alarm_tone');

        await DailyScheduler.cancelAllAlarms();
        await DailyScheduler.clearStoredAlarms();

        // Food alarms
        if ((d['food_alarm'] ?? 0) == 1) {
          final foodImg = d['food_file']?.toString();
          if ((d['breakfast_status'] ?? 0) == 1 &&
              d['breakfast_time'] != null) {
            final t = _toTOD(d['breakfast_time'].toString());
            if (t != null)
              await DailyScheduler.scheduleReminder(
                AlarmType.food,
                _schDate(t),
                _toStr(t),
                '🍳 Elderzha • Breakfast Time',
                'daily',
                soundUrl: tone,
                imageUrl: foodImg,
              );
          }
          if ((d['lunch_status'] ?? 0) == 1 && d['lunch_time'] != null) {
            final t = _toTOD(d['lunch_time'].toString());
            if (t != null)
              await DailyScheduler.scheduleReminder(
                AlarmType.food,
                _schDate(t),
                _toStr(t),
                '🍽 Elderzha • Lunch Reminder',
                'daily',
                soundUrl: tone,
                imageUrl: foodImg,
              );
          }
          if ((d['dinner_status'] ?? 0) == 1 && d['dinner_time'] != null) {
            final t = _toTOD(d['dinner_time'].toString());
            if (t != null)
              await DailyScheduler.scheduleReminder(
                AlarmType.food,
                _schDate(t),
                _toStr(t),
                '🍽 Elderzha • Dinner Reminder',
                'daily',
                soundUrl: tone,
                imageUrl: foodImg,
              );
          }
        }

        // Medical alarms
        if ((d['medical_alarm'] ?? 0) == 1) {
          final medImg = d['medical_file']?.toString();
          final medSlots = {
            '💊 Elderzha • Morning Before Food': d['morning_before_food'],
            '💊 Elderzha • Morning After Food': d['morning_after_food'],
            '💊 Elderzha • Noon Before Food': d['afternoon_before_food'],
            '💊 Elderzha • Noon After Food': d['afternoon_after_food'],
            '🌙 Elderzha • Night Before Food': d['night_before_food'],
            '🌙 Elderzha • Night After Food': d['night_after_food'],
          };
          for (final e in medSlots.entries) {
            if (e.value != null && e.value.toString().isNotEmpty) {
              final t = _toTOD(e.value.toString());
              if (t != null)
                await DailyScheduler.scheduleReminder(
                  AlarmType.medical,
                  _schDate(t),
                  _toStr(t),
                  e.key,
                  'daily',
                  soundUrl: tone,
                  imageUrl: medImg,
                );
            }
          }
        }
      }

      // 2. Family event alarms (birthdays + anniversaries)
      final profileRes = await AuthService().getProfileWithFamily();
      final familyList =
          profileRes?['data']?['family'] ?? profileRes?['family'] ?? [];
      if (familyList is List && familyList.isNotEmpty) {
        final members = familyList.map<FamilyMember>((m) {
          final relName = m['relation'] is Map
              ? (m['relation']['name'] ?? '')
              : (m['relation']?.toString() ?? '');
          final evName = m['event'] is Map
              ? (m['event']['name'] ?? '')
              : (m['event_type']?.toString() ?? 'Birthday');
          return FamilyMember(
            id: m['id']?.toString() ?? '0',
            type: m['type']?.toString() ?? '',
            status: m['status']?.toString() ?? '1',
            name: m['name']?.toString() ?? '',
            eventDate:
                m['event_date']?.toString() ?? m['date']?.toString() ?? '',
            relation: Event(id: '0', name: relName),
            event: Event(id: '0', name: evName),
          );
        }).toList();
        // ── FamilyEventScheduler.syncFamilyEventReminders ─────────────────
        await FamilyEventScheduler.syncFamilyEventReminders(members);
        debugPrint('Family event alarms scheduled: ${members.length} members');
      }

      debugPrint('✅ All alarms scheduled after login');
    } catch (e) {
      debugPrint('Alarm scheduling error after login: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  TimeOfDay? _toTOD(String raw) {
    final p = raw.split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _schDate(TimeOfDay t) {
    var dt = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      t.hour,
      t.minute,
    );
    if (dt.isBefore(DateTime.now())) dt = dt.add(const Duration(days: 1));
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _toStr(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  // FamilyMember.relation & event require a Named object — adapt
  void _resend() async {
    await context.read<AuthProvider>().phoneLogin(_phone);
    _startTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('OTP resent!', style: GoogleFonts.poppins()),
        backgroundColor: C.green,
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrls) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) => _goBack(),
      child: Scaffold(
        backgroundColor: C.bg,
        body: Column(
          children: [
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
                      GestureDetector(
                        onTap: _goBack,
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: C.ink,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Verify your\nnumber',
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: C.ink,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '+91 $_phone',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: C.yellowDeep,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: C.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 28),
                      Text(
                        'Enter 4-digit OTP',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: C.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sent via SMS to your mobile number',
                        style: GoogleFonts.poppins(fontSize: 12, color: C.txl),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use backspace to correct a digit',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: C.yellowDeep,
                        ),
                      ),
                      const SizedBox(height: 28),
                      AutofillGroup(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            4,
                            (i) => SizedBox(
                              width: 66,
                              height: 74,
                              child: Focus(
                                onKeyEvent: (_, event) =>
                                    _handleOtpKey(i, event),
                                child: TextField(
                                  controller: _ctrls[i],
                                  focusNode: _focusNodes[i],
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  textInputAction: i == 3
                                      ? TextInputAction.done
                                      : TextInputAction.next,
                                  autofillHints: const [
                                    AutofillHints.oneTimeCode,
                                  ],
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(
                                      i == 0 ? 4 : 1,
                                    ),
                                  ],
                                  style: GoogleFonts.poppins(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    color: C.ink,
                                  ),
                                  decoration: InputDecoration(
                                    counterText: '',
                                    filled: true,
                                    fillColor: C.bg2,
                                    contentPadding: EdgeInsets.zero,
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: C.bd,
                                        width: 1.5,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: C.yellow,
                                        width: 2.5,
                                      ),
                                    ),
                                  ),
                                  onChanged: (v) => _onChange(i, v),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _loading
                          ? const CircularProgressIndicator(color: C.ink)
                          : GestureDetector(
                              onTap: _verify,
                              child: Container(
                                width: double.infinity,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: C.ink,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    'Verify OTP',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      const SizedBox(height: 20),
                      _cd > 0
                          ? Text(
                              'Resend OTP in $_cd s',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: C.txl,
                              ),
                            )
                          : GestureDetector(
                              onTap: _resend,
                              child: Text(
                                'Resend OTP',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: C.yellowDeep,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
