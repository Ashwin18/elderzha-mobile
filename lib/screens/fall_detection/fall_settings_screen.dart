import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

/// Fall detection now runs as a NATIVE Android foreground service —
/// survives the app being swiped from Recent Apps (does not survive
/// a manual Force Stop, which is an Android OS restriction no app
/// can work around).
class FallSettingsScreen extends StatefulWidget {
  const FallSettingsScreen({super.key});
  @override
  State<FallSettingsScreen> createState() => _FallSettingsScreenState();
}

class _FallSettingsScreenState extends State<FallSettingsScreen>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('alarm_service');

  bool _monitoring = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check status when returning from a Settings page
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final running =
          await _channel.invokeMethod<bool>('isFallMonitoringRunning') ??
              false;
      if (mounted) setState(() { _monitoring = running; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(bool value) async {
    if (value) {
      await _channel.invokeMethod('startFallMonitoring');
    } else {
      await _channel.invokeMethod('stopFallMonitoring');
    }
    await Future.delayed(const Duration(milliseconds: 300));
    await _refresh();
  }

  Future<void> _testAlert() async {
    await _channel.invokeMethod('testFallAlert');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Test SOS alert triggered — lock your screen to see it',
          style: poppins(12, c: C.white)),
      backgroundColor: C.ink,
    ));
  }

  Future<void> _openFullScreenPermission() async {
    await _channel.invokeMethod('requestFullScreenIntentPermission');
  }

  Future<void> _openBatterySettings() async {
    await _channel.invokeMethod('openBatterySettings');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(children: [
        Container(
          color: C.yellow,
          child: SafeArea(bottom: false, child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: C.ink)),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Fall Detection',
                    style: poppins(18, w: FontWeight.w700, c: C.ink)),
                Text('Auto SOS when a fall is detected',
                    style: poppins(12, c: C.yellowDeep)),
              ]),
            ]),
          )),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: C.yellowDark))
              : ListView(padding: const EdgeInsets.all(16), children: [

                  // Status + toggle
                  _card(
                    selected: _monitoring,
                    child: Row(children: [
                      Icon(
                        _monitoring ? Icons.shield_rounded : Icons.sensors_rounded,
                        size: 24,
                        color: _monitoring ? const Color(0xFF2E7D32) : C.ink,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Background Fall Detection',
                            style: poppins(15, w: FontWeight.w700, c: C.ink)),
                        Text(
                          _monitoring
                              ? 'Active — works even if the app is closed'
                              : 'Off — tap to enable',
                          style: poppins(12,
                              c: _monitoring
                                  ? const Color(0xFF2E7D32)
                                  : C.txl),
                        ),
                      ])),
                      Switch(
                        value: _monitoring,
                        activeColor: const Color(0xFF2E7D32),
                        onChanged: _toggle,
                      ),
                    ]),
                  ),

                  const SizedBox(height: 14),

                  if (_monitoring) ...[
                    // Persistent notification notice
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: C.yellowLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: C.yellowBorder),
                      ),
                      child: Row(children: [
                        const Icon(Icons.notifications_active_rounded,
                            size: 18, color: C.yellowDeep),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          'A permanent notification "ElderZha — Fall '
                          'Detection Active" will stay visible while this '
                          'is on. This is required by Android.',
                          style: poppins(11.5, c: C.yellowDeep, h: 1.4),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 14),

                    Text('RECOMMENDED SETUP',
                        style: poppins(11, w: FontWeight.w700, c: C.txl)),
                    const SizedBox(height: 8),

                    GestureDetector(
                      onTap: _openBatterySettings,
                      child: _settingRow(
                        icon: Icons.battery_charging_full_rounded,
                        title: 'Allow unrestricted battery usage',
                        desc: 'Prevents the phone from stopping monitoring '
                            'in the background. Tap → Battery → Unrestricted.',
                      ),
                    ),
                    GestureDetector(
                      onTap: _openFullScreenPermission,
                      child: _settingRow(
                        icon: Icons.fullscreen_rounded,
                        title: 'Allow full-screen alerts',
                        desc: 'Lets the SOS screen show immediately over '
                            'the lock screen when a fall is detected.',
                      ),
                    ),

                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: _testAlert,
                      icon: const Icon(Icons.warning_amber_rounded, size: 18),
                      label: Text('Test SOS Alert',
                          style: poppins(13, w: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: C.ink,
                        side: const BorderSide(color: C.bd, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: C.blueLight,
                          borderRadius: BorderRadius.circular(14)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('How it works',
                            style: poppins(13, w: FontWeight.w700,
                                c: const Color(0xFF0D47A1))),
                        const SizedBox(height: 6),
                        Text(
                          '1. Phone detects a fall pattern (impact + stillness)\n'
                          '2. 30-second countdown screen appears — works even '
                          'if the app was closed\n'
                          '3. Tap "I\'m Fine" to cancel\n'
                          '4. If no response → SMS sent to family + admin alert\n\n'
                          'Note: stops only if you manually Force Stop the app '
                          'from phone Settings — this is an Android restriction '
                          'that applies to every app, with no exception.',
                          style: poppins(12, c: const Color(0xFF1565C0), h: 1.6),
                        ),
                      ]),
                    ),
                  ],
                ]),
        ),
      ]),
    );
  }

  Widget _card({required Widget child, bool selected = false}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F5E9) : C.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? const Color(0xFF4CAF50) : C.bd,
              width: selected ? 2 : 1.5),
        ),
        child: child,
      );

  Widget _settingRow({
    required IconData icon,
    required String title,
    required String desc,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: C.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: C.bd, width: 1.5),
    ),
    child: Row(children: [
      Icon(icon, size: 20, color: C.ink),
      const SizedBox(width: 12),
      Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Text(title, style: poppins(13.5, w: FontWeight.w700, c: C.ink)),
        const SizedBox(height: 2),
        Text(desc, style: poppins(11.5, c: C.txl, h: 1.4)),
      ])),
      const Icon(Icons.chevron_right_rounded, color: C.txl),
    ]),
  );
}
