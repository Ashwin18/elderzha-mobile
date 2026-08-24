import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/api_client.dart';

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
  final _api = ApiClient();

  bool _monitoring = false;
  bool _loading = true;

  // SOS contact — dedicated to Fall Detection, independent of
  // Family Members entirely.
  final _sosNameCtrl = TextEditingController();
  final _sosPhoneCtrl = TextEditingController();
  bool _sosSaving = false;
  bool _sosLoaded = false;
  bool _sosDeleting = false;
  bool _sosEditing = false; // shows the form; false = read-only summary card
  String? _savedSosName;
  String? _savedSosPhone;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _loadSosContact();
    _loadSensitivity();
  }

  // Fall detection sensitivity — low/medium/high. Stored via
  // SharedPreferences using the exact key format the native
  // Kotlin side already reads elsewhere in this app (see
  // FallMonitorService.isMonitoringEnabled for the established
  // pattern: "flutter." prefix, same preferences file the
  // shared_preferences plugin itself writes to).
  String _sensitivity = 'medium';
  bool _sensitivityLoaded = false;

  Future<void> _loadSensitivity() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _sensitivity = prefs.getString('fall_sensitivity') ?? 'medium';
      _sensitivityLoaded = true;
    });
  }

  Future<void> _setSensitivity(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fall_sensitivity', value);
    if (!mounted) return;
    setState(() => _sensitivity = value);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Sensitivity set to ${value[0].toUpperCase()}${value.substring(1)}',
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.white)),
      backgroundColor: const Color(0xFF2E7D32),
    ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sosNameCtrl.dispose();
    _sosPhoneCtrl.dispose();
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

  Future<void> _loadSosContact() async {
    try {
      final res = await _api.safeGet('/user/sos-contact');
      final data = res?['data'];
      if (data is Map) {
        _sosNameCtrl.text = data['name']?.toString() ?? '';
        _sosPhoneCtrl.text = data['phone']?.toString() ?? '';
        _savedSosName = data['name']?.toString();
        _savedSosPhone = data['phone']?.toString();
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _sosLoaded = true;
        // Start in the editable form only if nothing is saved yet.
        _sosEditing = _savedSosName == null || _savedSosName!.isEmpty;
      });
    }
  }

  Future<void> _saveSosContact() async {
    final name = _sosNameCtrl.text.trim();
    final phone = _sosPhoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Enter both name and phone number',
            style: poppins(12, c: C.white)),
        backgroundColor: C.red,
      ));
      return;
    }
    setState(() => _sosSaving = true);
    try {
      final res = await _api.safePost('/user/sos-contact', data: {
        'name': name,
        'phone': phone,
      });
      if (!mounted) return;
      final ok = res?['status'] == true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          ok
              ? 'SOS contact saved for emergency fall detection alerts'
              : 'Could not save: ${res?['message'] ?? 'unknown error'}',
          style: poppins(12, c: C.white),
        ),
        backgroundColor: ok ? const Color(0xFF2E7D32) : C.red,
      ));
      if (ok) {
        setState(() {
          _savedSosName = name;
          _savedSosPhone = phone;
          _sosEditing = false;
        });
      }
    } finally {
      if (mounted) setState(() => _sosSaving = false);
    }
  }

  Future<void> _deleteSosContact() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove SOS contact?', style: poppins(15, w: FontWeight.w700, c: C.ink)),
        content: Text(
          'No one will be notified automatically if a fall is detected until you add a new contact.',
          style: poppins(13, c: C.txm, h: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: poppins(13, w: FontWeight.w600, c: C.txl)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove', style: poppins(13, w: FontWeight.w700, c: C.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _sosDeleting = true);
    try {
      final res = await _api.safeDelete('/user/sos-contact');
      if (!mounted) return;
      final ok = res?['status'] == true;
      if (ok) {
        setState(() {
          _savedSosName = null;
          _savedSosPhone = null;
          _sosNameCtrl.clear();
          _sosPhoneCtrl.clear();
          _sosEditing = true;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          ok ? 'SOS contact removed' : 'Could not remove: ${res?['message'] ?? 'unknown error'}',
          style: poppins(12, c: C.white),
        ),
        backgroundColor: ok ? const Color(0xFF2E7D32) : C.red,
      ));
    } finally {
      if (mounted) setState(() => _sosDeleting = false);
    }
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

                  // ── Fall Detection Sensitivity ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: C.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: C.bd, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.tune_rounded, size: 20, color: C.ink),
                          const SizedBox(width: 8),
                          Text('Fall Sensitivity',
                              style: poppins(15, w: FontWeight.w700, c: C.ink)),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                          'High catches gentler falls but may trigger more '
                          'false alarms. Low reduces false alarms but may miss '
                          'a softer fall. Medium is recommended for most people.',
                          style: poppins(12, c: C.txm, h: 1.4),
                        ),
                        const SizedBox(height: 12),
                        if (!_sensitivityLoaded)
                          const Center(child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(color: C.yellowDark, strokeWidth: 2),
                          ))
                        else
                          Row(children: [
                            for (final level in ['low', 'medium', 'high'])
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(right: level != 'high' ? 8 : 0),
                                  child: GestureDetector(
                                    onTap: () => _setSensitivity(level),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: _sensitivity == level ? C.yellow : C.bg2,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _sensitivity == level ? C.yellowDark : C.bd,
                                        ),
                                      ),
                                      child: Text(
                                        level[0].toUpperCase() + level.substring(1),
                                        textAlign: TextAlign.center,
                                        style: poppins(12.5,
                                            w: FontWeight.w800,
                                            c: _sensitivity == level ? C.ink : C.txm),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ]),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── SOS Emergency Contact — independent of Family Members ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: C.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: C.bd, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.contact_phone_rounded,
                              size: 20, color: C.ink),
                          const SizedBox(width: 8),
                          Text('SOS Emergency Contact',
                              style: poppins(15, w: FontWeight.w700, c: C.ink)),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                          'This number gets an SMS if a fall is detected. '
                          'Separate from Family Members.',
                          style: poppins(11.5, c: C.txl, h: 1.4),
                        ),
                        const SizedBox(height: 14),
                        if (!_sosLoaded)
                          const Center(child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                color: C.yellowDark, strokeWidth: 2),
                          ))
                        else if (!_sosEditing && _savedSosName != null && _savedSosName!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: C.yellowLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: C.yellowBorder),
                            ),
                            child: Row(children: [
                              Container(
                                width: 40, height: 40,
                                decoration: const BoxDecoration(color: C.white, shape: BoxShape.circle),
                                child: const Icon(Icons.person_rounded, color: C.yellowDeep, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(_savedSosName ?? '', style: poppins(13.5, w: FontWeight.w700, c: C.ink)),
                                  Text(_savedSosPhone ?? '', style: poppins(12, c: C.txm)),
                                ]),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => setState(() => _sosEditing = true),
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: Text('Edit', style: poppins(12.5, w: FontWeight.w700)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: C.ink,
                                  side: const BorderSide(color: C.bd),
                                  minimumSize: const Size.fromHeight(42),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _sosDeleting ? null : _deleteSosContact,
                                icon: _sosDeleting
                                    ? const SizedBox(width: 14, height: 14,
                                        child: CircularProgressIndicator(color: C.red, strokeWidth: 2))
                                    : const Icon(Icons.delete_outline_rounded, size: 16, color: C.red),
                                label: Text('Delete', style: poppins(12.5, w: FontWeight.w700, c: C.red)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: C.red),
                                  minimumSize: const Size.fromHeight(42),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ]),
                        ] else ...[
                          TextField(
                            controller: _sosNameCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Contact name',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _sosPhoneCtrl,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            decoration: const InputDecoration(
                              labelText: 'Phone number',
                              prefixIcon: Icon(Icons.phone_outlined),
                              counterText: '',
                            ),
                          ),
                          const SizedBox(height: 6),
                          FilledButton(
                            onPressed: _sosSaving ? null : _saveSosContact,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              backgroundColor: C.ink,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _sosSaving
                                ? const SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : Text('Save SOS Contact',
                                    style: poppins(13, w: FontWeight.w700,
                                        c: C.yellow)),
                          ),
                          if (_savedSosName != null && _savedSosName!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _sosSaving ? null : () => setState(() {
                                _sosNameCtrl.text = _savedSosName ?? '';
                                _sosPhoneCtrl.text = _savedSosPhone ?? '';
                                _sosEditing = false;
                              }),
                              child: Text('Cancel', style: poppins(12.5, w: FontWeight.w600, c: C.txl)),
                            ),
                          ],
                        ],
                      ],
                    ),
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
