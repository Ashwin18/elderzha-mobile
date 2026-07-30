import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FallSensitivity { low, medium, high }

class FallDetectionService {
  static final FallDetectionService _i = FallDetectionService._();
  factory FallDetectionService() => _i;
  FallDetectionService._();

  StreamSubscription<AccelerometerEvent>? _sub;
  bool _isRunning = false;
  Function? _onFall;

  static const Map<FallSensitivity, Map<String, double>> _thresh = {
    FallSensitivity.low:    {'ff': 0.30, 'impact': 4.0, 'ms': 150},
    FallSensitivity.medium: {'ff': 0.50, 'impact': 3.0, 'ms': 100},
    FallSensitivity.high:   {'ff': 0.70, 'impact': 2.0, 'ms':  80},
  };

  bool _ffDetected = false;
  DateTime? _ffTime;
  final List<double> _buf = [];
  bool _alertShowing = false; // prevent double trigger

  static Future<FallSensitivity> getSensitivity() async {
    final p = await SharedPreferences.getInstance();
    final n = p.getString('fall_sensitivity') ?? 'medium';
    return FallSensitivity.values.firstWhere(
        (e) => e.name == n, orElse: () => FallSensitivity.medium);
  }

  static Future<void> setSensitivity(FallSensitivity s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('fall_sensitivity', s.name);
  }

  static Future<bool> isEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('fall_detection_enabled') ?? true;
  }

  static Future<void> setEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('fall_detection_enabled', v);
  }

  Future<void> start({required Function onFallDetected}) async {
    if (_isRunning) return;
    if (!await isEnabled()) return;
    _onFall = onFallDetected;
    _isRunning = true;
    final sens = await getSensitivity();
    final t = _thresh[sens]!;
    final ff = t['ff']!;
    final impact = t['impact']!;
    final ms = t['ms']!.toInt();

    _sub = accelerometerEventStream(
            samplingPeriod: SensorInterval.normalInterval)
        .listen((e) {
      final g = sqrt(e.x * e.x + e.y * e.y + e.z * e.z) / 9.81;
      _buf.add(g);
      if (_buf.length > 20) _buf.removeAt(0);

      // Step 1 — freefall
      if (!_ffDetected && g < ff) {
        _ffDetected = true;
        _ffTime = DateTime.now();
        return;
      }
      // Step 2 — impact after freefall
      if (_ffDetected && g > impact) {
        final elapsed =
            DateTime.now().difference(_ffTime!).inMilliseconds;
        if (elapsed >= ms && elapsed <= 2000) {
          final avg = _buf.isEmpty ? 1.0
              : _buf.reduce((a, b) => a + b) / _buf.length;
          if (avg < 1.5 && !_alertShowing) {
            _alertShowing = true;
            _onFall!();
            Future.delayed(const Duration(seconds: 35),
                () => _alertShowing = false);
          }
        }
        _reset();
        return;
      }
      // Reset if freefall not followed by impact within 2s
      if (_ffDetected &&
          DateTime.now().difference(_ffTime!).inMilliseconds > 2000) {
        _reset();
      }
    });
  }

  void _reset() {
    _ffDetected = false;
    _ffTime = null;
    _buf.clear();
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _isRunning = false;
    _reset();
  }

  bool get isRunning => _isRunning;
}
