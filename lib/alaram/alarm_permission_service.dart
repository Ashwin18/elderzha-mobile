import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const MethodChannel _alarmPermissionChannel = MethodChannel('alarm_service');

// Watches for the app coming back to the foreground — used to detect
// the user returning from the system "Alarms & reminders" Settings
// screen, since MainActivity.requestExactAlarmPermission() resolves
// the moment it *launches* that screen, not when the user finishes
// with it (see the wait in ensureExactAlarmPermission() below for why
// that gap matters).
class _ResumeWatcher with WidgetsBindingObserver {
  final Completer<void> _completer = Completer<void>();
  bool _disposed = false;

  _ResumeWatcher() {
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> get resumed => _completer.future;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_completer.isCompleted) {
      _completer.complete();
      dispose();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
  }
}

class AlarmPermissionService {
  static bool _hasCheckedFullScreenPermission = false;

  static Future<void> ensureFullScreenIntentPermission() async {
    if (!Platform.isAndroid || _hasCheckedFullScreenPermission) {
      return;
    }

    try {
      final allowed =
          await _alarmPermissionChannel.invokeMethod<bool>(
            'canUseFullScreenIntent',
          ) ??
          true;

      if (!allowed) {
        await _alarmPermissionChannel.invokeMethod(
          'requestFullScreenIntentPermission',
        );
      }
    } catch (_) {
      // Ignore permission bridge failures and keep alarm scheduling functional.
    } finally {
      _hasCheckedFullScreenPermission = true;
    }
  }

  // "Alarms & reminders" (Android 12+ / API 31+). Without this the OS
  // silently downgrades every scheduled alarm to an inexact one — it
  // can still fire, but delayed by minutes to hours (or dropped under
  // Doze on aggressive OEMs), which reads to the user as "the alarm
  // didn't go off". Native side used to have no handler for this call
  // at all (see MainActivity.kt), so this previously no-op'd silently.
  //
  // Re-checks the *live* OS permission state on every call (a single
  // cheap platform-channel round trip) rather than caching "already
  // asked" for the lifetime of the app — a previous version cached
  // that as a static flag set true after the very first call, which
  // meant: if a user backed out of or dismissed the Settings prompt
  // the first time this ran (typically right after signup, scheduling
  // the default alarms), every alarm scheduled for the rest of that
  // app session — including one the user explicitly edited a time for
  // in Alarms — silently skipped the permission check entirely and
  // fell back to native's own inexact-alarm fallback, with no further
  // chance to prompt them until the app was restarted. Now: if the OS
  // already reports the permission granted, this returns immediately
  // without bothering the user again; only an actually-still-missing
  // permission opens Settings.
  //
  // Bug fixed here: MainActivity's "requestExactAlarmPermission" just
  // *launches* the system Settings screen and returns immediately —
  // it doesn't wait for the user to actually flip the toggle. Callers
  // used to proceed straight to scheduling the moment that call
  // returned, so the very first (default) alarms always got scheduled
  // in the split-second window before the user had touched Settings,
  // permanently registering them as inexact even if the user granted
  // the permission a second later. Now this waits for the app to come
  // back to the foreground (i.e. the user finished with that Settings
  // screen, granted or not) before returning, capped at 90s in case
  // they back out of the flow entirely — so by the time a caller
  // schedules alarms, canScheduleExactAlarms() reflects what the user
  // actually just did.
  static Future<void> ensureExactAlarmPermission() async {
    if (!Platform.isAndroid) return;

    try {
      final allowed =
          await _alarmPermissionChannel.invokeMethod<bool>(
            'canScheduleExactAlarms',
          ) ??
          true;
      if (allowed) return;

      final watcher = _ResumeWatcher();
      await _alarmPermissionChannel.invokeMethod(
        'requestExactAlarmPermission',
      );
      await watcher.resumed.timeout(
        const Duration(seconds: 90),
        onTimeout: () {},
      );
      watcher.dispose();
    } catch (_) {
      // Ignore permission bridge failures and keep alarm scheduling functional.
    }
  }
}
