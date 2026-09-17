import 'dart:io';

import 'package:flutter/services.dart';

const MethodChannel _alarmPermissionChannel = MethodChannel('alarm_service');

class AlarmPermissionService {
  static bool _hasCheckedFullScreenPermission = false;
  static bool _hasCheckedExactAlarmPermission = false;

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
  // Only prompts once per app session — repeatedly bouncing the user
  // to Settings on every alarm save would be worse than not asking.
  static Future<void> ensureExactAlarmPermission() async {
    if (!Platform.isAndroid || _hasCheckedExactAlarmPermission) {
      return;
    }

    try {
      final allowed =
          await _alarmPermissionChannel.invokeMethod<bool>(
            'canScheduleExactAlarms',
          ) ??
          true;

      if (!allowed) {
        await _alarmPermissionChannel.invokeMethod(
          'requestExactAlarmPermission',
        );
      }
    } catch (_) {
      // Ignore permission bridge failures and keep alarm scheduling functional.
    } finally {
      _hasCheckedExactAlarmPermission = true;
    }
  }
}
