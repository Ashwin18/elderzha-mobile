// lib/services/step_service.dart
//
// Today's step count, backed by the device's own hardware step
// counter (Android's Sensor.TYPE_STEP_COUNTER). That sensor is
// maintained by the OS/hardware itself and keeps counting even while
// the app is killed or fully closed — so this service doesn't need a
// background service or any process of its own. It just reads the
// sensor's cumulative count (since the device last booted) whenever
// the app is open, and works out how many of those steps happened
// *today* using a daily baseline persisted in SharedPreferences:
// today's steps = latest reading - the reading stored as "start of
// today".
//
// Two sources feed that reading:
//  - a direct native read (MainActivity.kt's "getStepCounterReading"),
//    used once on every start() — a freshly-registered raw Android
//    SensorEventListener reports the sensor's current cumulative
//    value right away, which is what makes steps taken while the app
//    was killed show up correctly the moment it's reopened.
//  - the `pedometer` package's stream, kept running afterwards for
//    live updates while the app stays open. On its own this stream
//    can stay silent for a while right after a cold start/relaunch
//    (Android batches TYPE_STEP_COUNTER delivery, and some OEMs only
//    flush it on the next physical step) — which is exactly what made
//    the Home screen's count look frozen right after the app had been
//    killed and reopened, since there'd been no new step yet to
//    trigger it. The native one-shot read above doesn't have that gap.
//
// Display responsiveness: TYPE_STEP_COUNTER is an Android "on-change"
// sensor — it only delivers a fresh reading when the count actually
// changes, and there's no OS API to synchronously ask "what's the
// number right now". So a cold app-open right after walking with the
// app closed can show 0 for a beat: the app is waiting for the next
// physical step to trigger a delivery, and when it arrives it already
// carries the full catch-up total (not a per-step increment) — that's
// the "shows zero, then jumps to 35" behaviour. This can't be forced
// to "update on every single step" from the app side (no per-step push
// API for this sensor), but the *wait* can be shortened a lot: a burst
// of quick re-checks right after opening/resuming the app (below),
// plus a much shorter steady-state poll than before, so any pending
// reading gets picked up within a few seconds instead of up to 25.
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StepService with WidgetsBindingObserver {
  StepService._();
  static final StepService instance = StepService._();

  static const _channel = MethodChannel('alarm_service');

  static const _kBaselineDateKey = 'steps_baseline_date';
  static const _kBaselineCountKey = 'steps_baseline_count';
  static const _kTodayStepsKey = 'steps_today_cached';

  StreamSubscription<StepCount>? _sub;
  final _controller = StreamController<int>.broadcast();
  bool _started = false;

  // Extra refresh path, on top of the native one-shot read + pedometer
  // stream below. Without this, the count only ever updated on a full
  // app restart (initState → start() → one native read) — simply
  // backgrounding the app, walking around, and coming back to the
  // foreground did nothing, since the pedometer stream can stay quiet
  // for a while (see the file-level note) and nothing else re-reads
  // the sensor in between. Now: (a) every foreground resume triggers
  // a fresh native read, and (b) a timer re-reads it periodically while
  // the app stays open, so the count keeps catching up even if the
  // stream itself never fires. Shortened from 25s to 6s — cheap (each
  // tick is just a native listener registration that gives up in
  // 1.5s if nothing's pending) and cuts the worst-case staleness a lot.
  Timer? _pollTimer;
  static const _pollInterval = Duration(seconds: 6);

  // Right after opening/resuming the app, also fire a quick burst of
  // extra re-checks (every 1.5s, six times) instead of waiting for the
  // first regular poll tick — this is what actually shortens the
  // "shows 0 for a while after reopening" gap described above, since
  // it gives the sensor several fast chances to deliver its pending
  // reading in the first ~9s rather than one long wait.
  Timer? _burstTimer;
  int _burstTicksLeft = 0;

  /// Today's step count. Emits the last cached value immediately (so
  /// the UI has something to show the moment the app opens), then a
  /// fresh, authoritative reading a moment later (native one-shot
  /// read), then again every time the sensor reports a new
  /// cumulative count while the app stays open.
  Stream<int> get todayStepsStream => _controller.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    final prefs = await SharedPreferences.getInstance();
    _controller.add(prefs.getInt(_kTodayStepsKey) ?? 0);

    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) return;

    // Authoritative catch-up read — covers whatever steps were taken
    // while the app was killed/closed, without waiting on the stream.
    unawaited(_readNativeOnce());
    _startCatchUpBurst();

    _sub = Pedometer.stepCountStream.listen(
      (event) => _applyReading(event.steps),
      onError: (_) {},
      cancelOnError: false,
    );

    WidgetsBinding.instance.addObserver(this);
    _pollTimer = Timer.periodic(
      _pollInterval,
      (_) => unawaited(_readNativeOnce()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_readNativeOnce());
      _startCatchUpBurst();
    }
  }

  void _startCatchUpBurst() {
    _burstTimer?.cancel();
    _burstTicksLeft = 6;
    _burstTimer = Timer.periodic(const Duration(milliseconds: 1500), (t) {
      if (_burstTicksLeft <= 0) {
        t.cancel();
        return;
      }
      _burstTicksLeft -= 1;
      unawaited(_readNativeOnce());
    });
  }

  Future<void> _readNativeOnce() async {
    try {
      final steps = await _channel.invokeMethod<int>('getStepCounterReading');
      if (steps != null && steps >= 0) {
        await _applyReading(steps);
      }
    } catch (_) {
      // Falls back to whatever the pedometer stream reports instead.
    }
  }

  Future<void> _applyReading(int cumulativeSteps) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final baselineDate = prefs.getString(_kBaselineDateKey);
    var baseline = prefs.getInt(_kBaselineCountKey);

    // Start a fresh baseline at the current cumulative reading when:
    // this is the very first reading ever, it's a new day since the
    // last one we saw, or the device rebooted (the hardware counter
    // resets to 0 on reboot, which would otherwise read as a huge
    // negative "today" count).
    if (baseline == null || baselineDate != today || cumulativeSteps < baseline) {
      baseline = cumulativeSteps;
      await prefs.setString(_kBaselineDateKey, today);
      await prefs.setInt(_kBaselineCountKey, baseline);
    }

    final todaySteps = cumulativeSteps - baseline;
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
    _pollTimer?.cancel();
    _pollTimer = null;
    _burstTimer?.cancel();
    _burstTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }
}
