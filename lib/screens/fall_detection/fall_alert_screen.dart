// lib/screens/fall_detection/fall_alert_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/fall_detection/fall_alert_service.dart';

class FallAlertScreen extends StatefulWidget {
  const FallAlertScreen({super.key});
  @override
  State<FallAlertScreen> createState() => _FallAlertScreenState();
}

class _FallAlertScreenState extends State<FallAlertScreen>
    with TickerProviderStateMixin {
  int _countdown = 30;
  Timer? _timer;
  bool _sending = false;
  bool _cancelled = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.12).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) { t.cancel(); _sendSOS(); }
    });
  }

  Future<void> _imFine() async {
    _timer?.cancel();
    setState(() => _cancelled = true);
    final user = context.read<AuthProvider>().user;
    await FallAlertService().logFalseAlarm(
        userId: user?['id']?.toString() ?? '');
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _sendSOS() async {
    if (_sending || _cancelled) return;
    setState(() => _sending = true);
    Position? position;
    try {
      final permitted = await Geolocator.checkPermission();
      if (permitted == LocationPermission.always ||
          permitted == LocationPermission.whileInUse) {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)));
      }
    } catch (_) {}
    final user = context.read<AuthProvider>().user;
    final locationUrl = position != null
        ? 'https://maps.google.com/?q=${position.latitude},${position.longitude}'
        : null;
    await FallAlertService().sendFallAlert(
      userId:      user?['id']?.toString() ?? '',
      userName:    '${user?['first_name'] ?? ''} ${user?['last_name'] ?? ''}'.trim(),
      latitude:    position?.latitude,
      longitude:   position?.longitude,
      locationUrl: locationUrl,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
          builder: (_) => FallSOSSentScreen(locationUrl: locationUrl)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFCC0000),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _sending ? _buildSending() : _buildAlert(),
          ),
        ),
      ),
    );
  }

  Widget _buildAlert() => Column(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Column(children: [
        const SizedBox(height: 20),
        ScaleTransition(
          scale: _pulse,
          child: Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle),
            child: const Icon(Icons.warning_rounded,
                size: 60, color: Colors.white),
          ),
        ),
        const SizedBox(height: 24),
        Text('Fall Detected!',
            style: GoogleFonts.poppins(fontSize: 32,
                fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 8),
        Text('Are you okay?',
            style: GoogleFonts.poppins(
                fontSize: 18, color: Colors.white70)),
      ]),
      Column(children: [
        Text('Sending SOS in',
            style: GoogleFonts.poppins(
                fontSize: 14, color: Colors.white70)),
        const SizedBox(height: 12),
        Stack(alignment: Alignment.center, children: [
          SizedBox(width: 120, height: 120,
            child: CircularProgressIndicator(
              value: _countdown / 30,
              strokeWidth: 8,
              backgroundColor: Colors.white24,
              color: _countdown <= 10 ? Colors.orange : Colors.white,
            ),
          ),
          Text('$_countdown',
              style: GoogleFonts.poppins(fontSize: 42,
                  fontWeight: FontWeight.w800, color: Colors.white)),
        ]),
        const SizedBox(height: 8),
        Text('seconds',
            style: GoogleFonts.poppins(
                fontSize: 14, color: Colors.white70)),
      ]),
      Column(children: [
        GestureDetector(
          onTap: _imFine,
          child: Container(
            width: double.infinity, height: 64,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF2E7D32), size: 28),
                const SizedBox(width: 10),
                Text("I'm Fine",
                    style: GoogleFonts.poppins(fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2E7D32))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _sendSOS,
          child: Container(
            width: double.infinity, height: 54,
            decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white54)),
            child: Center(child: Text('Send SOS Now',
                style: GoogleFonts.poppins(fontSize: 16,
                    fontWeight: FontWeight.w700, color: Colors.white))),
          ),
        ),
        const SizedBox(height: 20),
      ]),
    ],
  );

  Widget _buildSending() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
      const SizedBox(height: 24),
      Text('Sending SOS...',
          style: GoogleFonts.poppins(fontSize: 20,
              fontWeight: FontWeight.w800, color: Colors.white)),
      const SizedBox(height: 8),
      Text('Getting your location and notifying emergency contacts',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
              fontSize: 14, color: Colors.white70)),
    ],
  );
}

class FallSOSSentScreen extends StatelessWidget {
  final String? locationUrl;
  const FallSOSSentScreen({super.key, this.locationUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  size: 80, color: Colors.white),
              const SizedBox(height: 24),
              Text('SOS Sent!',
                  style: GoogleFonts.poppins(fontSize: 30,
                      fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 12),
              Text(
                'Emergency contacts notified via SMS.\nAdmin has been alerted.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 15, color: Colors.white70, height: 1.5),
              ),
              if (locationUrl != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.location_on_rounded,
                        color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                        'Location shared with contacts',
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: Colors.white70))),
                  ]),
                ),
              ],
              const SizedBox(height: 40),
              GestureDetector(
                onTap: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                child: Container(
                  width: double.infinity, height: 54,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14)),
                  child: Center(child: Text('Back to Home',
                      style: GoogleFonts.poppins(fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1B5E20)))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
