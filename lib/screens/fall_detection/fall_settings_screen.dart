import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/fall_detection/fall_detection_service.dart';

class FallSettingsScreen extends StatefulWidget {
  const FallSettingsScreen({super.key});
  @override
  State<FallSettingsScreen> createState() => _FallSettingsScreenState();
}

class _FallSettingsScreenState extends State<FallSettingsScreen> {
  bool _enabled = true;
  FallSensitivity _sensitivity = FallSensitivity.medium;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = await FallDetectionService.isEnabled();
    final s = await FallDetectionService.getSensitivity();
    setState(() { _enabled = e; _sensitivity = s; _loading = false; });
  }

  Future<void> _toggleEnabled(bool v) async {
    await FallDetectionService.setEnabled(v);
    setState(() => _enabled = v);
    if (!v) {
      FallDetectionService().stop();
    }
  }

  Future<void> _setSensitivity(FallSensitivity s) async {
    await FallDetectionService.setSensitivity(s);
    setState(() => _sensitivity = s);
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
                  // Enable toggle
                  _card(child: Row(children: [
                    const Icon(Icons.sensors_rounded,
                        size: 24, color: C.ink),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Fall Detection',
                          style: poppins(15, w: FontWeight.w700, c: C.ink)),
                      Text(_enabled
                          ? 'Monitoring for falls — tap to disable'
                          : 'Detection is off — tap to enable',
                          style: poppins(12, c: C.txl)),
                    ])),
                    Switch(
                      value: _enabled,
                      activeColor: C.yellowDark,
                      onChanged: _toggleEnabled,
                    ),
                  ])),

                  const SizedBox(height: 14),

                  // Sensitivity
                  if (_enabled) ...[
                    Text('SENSITIVITY',
                        style: poppins(11, w: FontWeight.w700,
                            c: C.txl)),
                    const SizedBox(height: 8),
                    ...[
                      (FallSensitivity.low, '🟢 Low',
                          'Only very hard falls\nFewer false alarms'),
                      (FallSensitivity.medium, '🟡 Medium',
                          'Balanced — recommended\nMost falls detected'),
                      (FallSensitivity.high, '🔴 High',
                          'Even small stumbles\nMore false alarms possible'),
                    ].map((item) {
                      final (s, label, desc) = item;
                      final sel = _sensitivity == s;
                      return GestureDetector(
                        onTap: () => _setSensitivity(s),
                        child: _card(
                          selected: sel,
                          child: Row(children: [
                            Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(label, style: poppins(15,
                                  w: FontWeight.w700,
                                  c: sel ? C.yellowDeep : C.ink)),
                              const SizedBox(height: 2),
                              Text(desc, style: poppins(12, c: C.txl, h: 1.4)),
                            ])),
                            if (sel)
                              const Icon(Icons.check_circle_rounded,
                                  color: C.yellowDark, size: 22),
                          ]),
                        ),
                      );
                    }),

                    const SizedBox(height: 14),
                    // How it works info
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
                          '1. Phone detects sudden fall movement\n'
                          '2. 30-second countdown screen appears\n'
                          '3. Tap "I\'m Fine" to cancel\n'
                          '4. If no response → SMS sent to family members\n'
                          '5. Admin also gets an alert',
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
          color: selected ? C.yellowLight : C.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? C.yellow : C.bd,
              width: selected ? 2 : 1.5),
        ),
        child: child,
      );
}
