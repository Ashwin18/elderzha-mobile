// lib/screens/alarm_permission/alarm_permission_screen.dart
import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_routes.dart';

class AlarmPermissionScreen extends StatefulWidget {
  const AlarmPermissionScreen({super.key});

  static Future<bool> shouldShow() async {
    if (!Platform.isAndroid) return false;
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('alarm_permissions_granted') ?? false);
  }

  static Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alarm_permissions_granted', true);
  }

  @override
  State<AlarmPermissionScreen> createState() => _AlarmPermissionScreenState();
}

class _AlarmPermissionScreenState extends State<AlarmPermissionScreen> {
  bool _overlayGranted      = false;
  bool _batteryGranted      = false;
  bool _exactAlarmGranted   = false;
  bool _notificationGranted = false;
  bool _checking            = true;

  @override
  void initState() {
    super.initState();
    _checkAll();
  }

  Future<void> _checkAll() async {
    setState(() => _checking = true);
    _overlayGranted      = await Permission.systemAlertWindow.isGranted;
    _batteryGranted      = await Permission.ignoreBatteryOptimizations.isGranted;
    _notificationGranted = await Permission.notification.isGranted;
    _exactAlarmGranted   = await _checkExactAlarm();
    if (mounted) setState(() => _checking = false);
  }

  Future<bool> _checkExactAlarm() async {
    try { return await Permission.scheduleExactAlarm.isGranted; }
    catch (_) { return true; }
  }

  bool get _allGranted =>
      _overlayGranted && _batteryGranted &&
      _exactAlarmGranted && _notificationGranted;

  Future<void> _grantOverlay() async {
    // Android 14 fix: MANAGE_OVERLAY_PERMISSION shows app list
    // Open App Details directly, user taps "Display over other apps"
    try {
      await AndroidIntent(
        action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
        data: 'package:com.batechnology.elderzha',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      ).launch();
      // Show instruction to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Tap "Display over other apps" and turn it ON',
              style: GoogleFonts.poppins(fontSize: 13)),
          duration: const Duration(seconds: 5),
          backgroundColor: const Color(0xFF2D1B69),
        ));
      }
      await Future.delayed(const Duration(seconds: 4));
      await _checkAll();
    } catch (_) {
      try {
        await Permission.systemAlertWindow.request();
        await _checkAll();
      } catch (_) {}
    }
  }

  Future<void> _grantBattery() async {
    try {
      // Try direct dialog first
      await Permission.ignoreBatteryOptimizations.request();
      if (_batteryGranted) { await _checkAll(); return; }
    } catch (_) {}
    try {
      // Open app details for manual grant
      await AndroidIntent(
        action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
        data: 'package:com.batechnology.elderzha',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      ).launch();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Tap Battery → select "Unrestricted"',
              style: GoogleFonts.poppins(fontSize: 13)),
          duration: const Duration(seconds: 5),
          backgroundColor: const Color(0xFF1B5E20),
        ));
      }
      await Future.delayed(const Duration(seconds: 4));
    } catch (_) {}
    await _checkAll();
  }

  Future<void> _grantExactAlarm() async {
    // First try direct permission request dialog
    try {
      final status = await Permission.scheduleExactAlarm.request();
      if (status.isGranted) { await _checkAll(); return; }
    } catch (_) {}
    // Fallback: open app's alarm settings directly
    try {
      await AndroidIntent(
        action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
        data: 'package:com.batechnology.elderzha',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      ).launch();
      await Future.delayed(const Duration(seconds: 2));
    } catch (_) {}
    await _checkAll();
  }

  Future<void> _grantNotification() async {
    await Permission.notification.request();
    await _checkAll();
  }

  Future<void> _grantAll() async {
    // Show guide dialog before opening settings
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Grant Permissions',
            style: poppins(16, w: FontWeight.w700, c: C.ink)),
        content: Text(
          'We will open ElderZha settings pages one by one.\n\n'
          '1. Notifications → Tap Allow\n'
          '2. App Details → Tap "Display over other apps" → ON\n'
          '3. App Details → Tap Battery → Unrestricted\n'
          '4. Alarms → Tap Allow\n\n'
          'A hint will appear for each step. Tap OK to begin.',
          style: poppins(13, c: C.txm, h: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: poppins(14, w: FontWeight.w700, c: C.yellowDark)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (!_notificationGranted) await _grantNotification();
    if (!_overlayGranted)      await _grantOverlay();
    if (!_batteryGranted)      await _grantBattery();
    if (!_exactAlarmGranted)   await _grantExactAlarm();
  }

  Future<void> _continue() async {
    await AlarmPermissionScreen.markDone();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: C.bg,
        body: Column(children: [
          // Header
          Container(
            color: C.yellow,
            width: double.infinity,
            child: SafeArea(bottom: false, child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                      color: C.ink, borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: Text('⏰',
                      style: TextStyle(fontSize: 26))),
                ),
                const SizedBox(height: 16),
                Text('Enable Alarm\nPermissions',
                    style: poppins(28, w: FontWeight.w800, c: C.ink, h: 1.15)),
                const SizedBox(height: 6),
                Text('Required for alarms to work on this device',
                    style: poppins(13, c: C.yellowDeep, w: FontWeight.w600)),
              ]),
            )),
          ),

          Expanded(child: _checking
            ? const Center(child: CircularProgressIndicator(color: C.yellowDark))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  const SizedBox(height: 4),

                  // Info
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: C.yellow),
                    ),
                    child: Row(children: [
                      const Text('💡', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        'Grant all 4 permissions for alarms to show full '
                        'screen on locked phone and sound to never cut off.',
                        style: poppins(12, c: const Color(0xFF5D4037), h: 1.5),
                      )),
                    ]),
                  ),

                  const SizedBox(height: 16),

                  _permCard(
                    icon: '🖥️',
                    title: 'Display over other apps',
                    desc: 'Tap Allow → Settings opens → find ElderZha → '
                          'toggle ON',
                    granted: _overlayGranted,
                    onGrant: _grantOverlay,
                  ),
                  _permCard(
                    icon: '🔋',
                    title: 'Battery — Unrestricted',
                    desc: 'Tap Allow → Settings opens → tap ElderZha → '
                          'select Unrestricted',
                    granted: _batteryGranted,
                    onGrant: _grantBattery,
                  ),
                  _permCard(
                    icon: '⏰',
                    title: 'Alarms & reminders',
                    desc: 'Tap Allow → system dialog appears → '
                          'tap Allow to confirm',
                    granted: _exactAlarmGranted,
                    onGrant: _grantExactAlarm,
                  ),
                  _permCard(
                    icon: '🔔',
                    title: 'Notifications',
                    desc: 'Shows alarm in notification tray '
                          'as backup',
                    granted: _notificationGranted,
                    onGrant: _grantNotification,
                  ),

                  const SizedBox(height: 20),

                  if (!_allGranted) ...[
                    GestureDetector(
                      onTap: _grantAll,
                      child: Container(
                        width: double.infinity, height: 58,
                        decoration: BoxDecoration(
                            color: C.ink,
                            borderRadius: BorderRadius.circular(16)),
                        child: Center(child: Text('Grant All Permissions →',
                            style: poppins(17, w: FontWeight.w800, c: C.yellow))),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _continue,
                      child: Center(child: Text(
                        'Skip (alarms may not work reliably)',
                        style: poppins(12, c: C.txl),
                      )),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF4CAF50)),
                      ),
                      child: Row(children: [
                        const Text('✅', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          'All permissions granted! Alarms will work '
                          'reliably on this device.',
                          style: poppins(13, c: const Color(0xFF2E7D32),
                              w: FontWeight.w600),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _continue,
                      child: Container(
                        width: double.infinity, height: 58,
                        decoration: BoxDecoration(
                            color: C.ink,
                            borderRadius: BorderRadius.circular(16)),
                        child: Center(child: Text('Continue to Home →',
                            style: poppins(17, w: FontWeight.w800, c: C.yellow))),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ]),
              ),
          ),
        ]),
      ),
    );
  }

  Widget _permCard({
    required String icon,
    required String title,
    required String desc,
    required bool granted,
    required VoidCallback onGrant,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: C.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: granted ? const Color(0xFF4CAF50) : C.bd,
        width: granted ? 2 : 1.5,
      ),
    ),
    child: Row(children: [
      Text(icon, style: const TextStyle(fontSize: 26)),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: poppins(14, w: FontWeight.w700, c: C.ink)),
          const SizedBox(height: 3),
          Text(desc, style: poppins(11, c: C.txl, h: 1.4)),
        ],
      )),
      const SizedBox(width: 8),
      granted
        ? const Text('✅', style: TextStyle(fontSize: 22))
        : GestureDetector(
            onTap: onGrant,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: C.ink, borderRadius: BorderRadius.circular(10)),
              child: Text('Allow',
                  style: poppins(12, w: FontWeight.w700, c: C.yellow)),
            ),
          ),
    ]),
  );
}
