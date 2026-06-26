import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alarm_permission_service.dart';

const MethodChannel _alarmChannel = MethodChannel('alarm_service');

enum AlarmType { medical, food }

class DailyScheduler {
  static Future<void> cancelAllAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await _alarmChannel.invokeMethod('cancelAllAlarms');
    } catch (_) {
      final alarms = prefs.getStringList('scheduled_alarms') ?? [];

      for (final alarmString in alarms) {
        final alarm = jsonDecode(alarmString);
        final triggerAt = alarm['triggerAt'];
        if (triggerAt is int) {
          await _alarmChannel.invokeMethod('cancelAlarm', {'id': triggerAt});
        }
      }
    }

    await prefs.remove('scheduled_alarms');
  }

  static Future<void> clearStoredAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('scheduled_alarms');
  }

  /* -----------------------------------------------------------
     SCHEDULE SINGLE REMINDER
  ------------------------------------------------------------ */

  static Future<void> scheduleReminder(
    AlarmType alarmType,
    String date, // 🔥 IMPORTANT: pass actual date
    String time,
    String title,
    String scheduleType, {
    // "once" or "daily"
    String? soundUrl,
    String? imageUrl,
    String? notes,
  }) async {
    try {
      await AlarmPermissionService.ensureFullScreenIntentPermission();

      final dateParts = date.split('-');
      final timeParts = time.split(':');

      if (dateParts.length < 3 || timeParts.length < 2) return;

      DateTime scheduleDateTime = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
        timeParts.length >= 3 ? int.parse(timeParts[2]) : 0,
      );

      // ❌ Don't schedule past alarms
      if (scheduleDateTime.isBefore(DateTime.now())) return;

      final prefs = await SharedPreferences.getInstance();
      final alarmTone = prefs.getString("alarm_tone");

      final finalSoundUrl = (alarmTone != null && alarmTone.isNotEmpty)
          ? alarmTone
          : (soundUrl ?? "");

      final triggerAt = scheduleDateTime.millisecondsSinceEpoch;

      await _alarmChannel.invokeMethod('scheduleAlarm', {
        'id': triggerAt,
        'triggerAt': triggerAt,
        'title': title,
        'type': scheduleType.toLowerCase(),
        'date': date,
        'notes': notes ?? '',
        'soundUrl': finalSoundUrl,
        'imageUrl': imageUrl ?? '',
      });

      await saveAlarmToStorage({
        'alarmType': alarmType.toString().split('.').last,
        'date': date,
        'time': time,
        'title': title,
        'scheduleType': scheduleType,
        'soundUrl': finalSoundUrl,
        'imageUrl': imageUrl ?? '',
        'notes': notes ?? '',
        'triggerAt': triggerAt,
      });
    } catch (e) {
      print("DailyScheduler Error: $e");
    }
  }

  /* -----------------------------------------------------------
     SCHEDULE MULTIPLE
  ------------------------------------------------------------ */

  static Future<void> scheduleAll(List<Map<String, dynamic>> alarms) async {
    for (final alarm in alarms) {
      final alarmType = _stringToAlarmType(alarm['alarmType']);

      await scheduleReminder(
        alarmType,
        alarm['date'],
        alarm['time'],
        alarm['title'],
        alarm['scheduleType'],
        soundUrl: alarm['soundUrl'],
        imageUrl: alarm['imageUrl'],
        notes: alarm['notes'],
      );
    }
  }

  /* -----------------------------------------------------------
     CANCEL SINGLE ALARM
  ------------------------------------------------------------ */

  static Future<void> cancelAlarm(int triggerAt) async {
    await _alarmChannel.invokeMethod('cancelAlarm', {'id': triggerAt});

    final prefs = await SharedPreferences.getInstance();
    List<String> alarms = prefs.getStringList('scheduled_alarms') ?? [];

    alarms.removeWhere((alarmString) {
      final alarm = jsonDecode(alarmString);
      return alarm['triggerAt'] == triggerAt;
    });

    await prefs.setStringList('scheduled_alarms', alarms);
  }

  /* -----------------------------------------------------------
     SAVE TO LOCAL STORAGE
  ------------------------------------------------------------ */

  static Future<void> saveAlarmToStorage(Map<String, dynamic> alarm) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> alarms = prefs.getStringList('scheduled_alarms') ?? [];

    // prevent duplicates
    alarms.removeWhere((alarmString) {
      final existing = jsonDecode(alarmString);
      return existing['triggerAt'] == alarm['triggerAt'];
    });

    alarms.add(jsonEncode(alarm));

    await prefs.setStringList('scheduled_alarms', alarms);
  }

  /* -----------------------------------------------------------
     RESTORE AFTER APP RESTART
  ------------------------------------------------------------ */

  static Future<void> restoreAlarmsFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> alarms = prefs.getStringList('scheduled_alarms') ?? [];

    for (final alarmString in alarms) {
      final alarm = jsonDecode(alarmString);

      await scheduleReminder(
        _stringToAlarmType(alarm['alarmType']),
        alarm['date'],
        alarm['time'],
        alarm['title'],
        alarm['scheduleType'],
        soundUrl: alarm['soundUrl'],
        imageUrl: alarm['imageUrl'],
        notes: alarm['notes'],
      );
    }
  }

  /* -----------------------------------------------------------
     ENUM CONVERTER
  ------------------------------------------------------------ */

  static AlarmType _stringToAlarmType(String typeString) {
    try {
      return AlarmType.values.firstWhere(
        (e) => e.toString().split('.').last == typeString,
      );
    } catch (_) {
      return AlarmType.medical;
    }
  }
}
