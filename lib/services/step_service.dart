// lib/services/step_service.dart
//
// Today's step count, backed by the device's own hardware step
// counter (Android's Sensor.TYPE_STEP_COUNTER, wrapped by the
// `pedometer` package). That sensor is maintained by the OS/hardware
// itself and keeps counting even while the app is killed or fully
// closed — so this service doesn't need a background service or any
// process of its own. It just reads the sensor's cumulative count
// (since the device last booted) whenever the app is open, and works
// out how many of those steps happened *today* using a daily baseline
// persisted in SharedPreferences: today's steps = latest reading -
// the reading stored as "start of today".
import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StepService {
  StepService._();
  static final StepService instance = StepService._();

  static const _kBaselineDateKey = 'steps_baseline_date';
  static const _kBaselineCountKey = 'steps_baseline_count';
  static const _kTodayStepsKey = 'steps_today_cached';

  StreamSubscription<StepCount>? _sub;
  final _controller = StreamController<int>.broadcast();
  bool _started = false;

  /// Today's step count. Emits the last cached value immediately (so
  /// the UI has something to show the moment the app opens, before
  /// the sensor's first reading arrives), then again every time the
  /// sensor reports a new cumulative count.
  Stream<int> get todayStepsStream => _controller.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    final prefs = await SharedPreferences.getInstance();
    _controller.add(prefs.getInt(_kTodayStepsKey) ?? 0);

    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) return;

    _sub = Pedometer.stepCountStream.listen(
      _onStepCount,
      onError: (_) {},
      cancelOnError: false,
    );
  }

  Future<void> _onStepCount(StepCount event) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final baselineDate = prefs.getString(_kBaselineDateKey);
    var baseline = prefs.getInt(_kBaselineCountKey);

    // Start a fresh baseline at the current cumulative reading when:
    // this is the very first reading ever, it's a new day since the
    // last one we saw, or the device rebooted (the hardware counter
    // resets to 0 on reboot, which would otherwise read as a huge
    // negative "today" count).
    if (baseline == null || baselineDate != today || event.steps < baseline) {
      baseline = event.steps;
      await prefs.setString(_kBaselineDateKey, today);
      await prefs.setInt(_kBaselineCountKey, baseline);
    }

    final todaySteps = event.steps - baseline;
    await prefs.setInt(_kTodayStepsKey, todaySteps);
    _controller.add(todaySteps);
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<int> cachedTodaySteps() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kTodayStepsKey) ?? 0;
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
  }
}
