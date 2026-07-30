import 'dart:io' as dart_io;
import 'package:http/http.dart' as dart_http;
import 'package:path_provider/path_provider.dart' as dart_path;
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alarm_permission_service.dart';

const MethodChannel _alarmChannel = MethodChannel('alarm_service');

enum AlarmType { medical, food }

class DailyScheduler {
  static Future<void> cancelAllAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final alarms = prefs.getStringList('scheduled_alarms') ?? [];
    try {
      await _alarmChannel.invokeMethod('cancelAllAlarms');
    } catch (_) {}

    // Cancel each stored alarm individually
    for (final alarmString in alarms) {
      try {
        final alarm = jsonDecode(alarmString);
        // Gap 1 Fix: use stored 'id' first, fall back to triggerAt
        final id = alarm['id'] as int? ?? alarm['triggerAt'] as int?;
        if (id != null) {
          await _alarmChannel.invokeMethod('cancelAlarm', {'id': id});
        }
      } catch (_) {}
    }

    // Gap 8 Fix: also cancel AlarmScheduler custom reminders
    // (AlarmScheduler uses same channel but different storage key)
    final customAlarms = prefs.getStringList('alarm_scheduler_alarms') ?? [];
    for (final alarmString in customAlarms) {
      try {
        final alarm = jsonDecode(alarmString);
        final id = alarm['id'] as int?;
        if (id != null) await _alarmChannel.invokeMethod('cancelAlarm', {'id': id});
      } catch (_) {}
    }

    await prefs.remove('scheduled_alarms');
    await prefs.remove('alarm_scheduler_alarms');
    // Note: family_event_reminders handled separately by FamilyEventScheduler.clearScheduledReminders()
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

      // Gap 2 Fix: Past alarms → schedule for tomorrow (not silently drop)
      if (scheduleDateTime.isBefore(DateTime.now())) {
        if (scheduleType.toLowerCase() == 'daily') {
          scheduleDateTime = scheduleDateTime.add(const Duration(days: 1));
        } else {
          return; // 'once' past alarms are truly expired
        }
      }

      final prefs = await SharedPreferences.getInstance();
      // Gap 10 Fix: verify local tone file still exists before using
      // If it doesn't exist (e.g. after reinstall), fall back to passed soundUrl
      final alarmTone = prefs.getString("alarm_tone");
      String finalSoundUrl;
      if (alarmTone != null && alarmTone.isNotEmpty) {
        // Check if it's a local file that still exists
        if (alarmTone.startsWith('http') || alarmTone.startsWith('https')) {
          finalSoundUrl = alarmTone; // server URL — use directly
        } else {
          // Local file — verify it exists
          try {
            final file = dart_io.File(alarmTone);
            finalSoundUrl = await file.exists() ? alarmTone : (soundUrl ?? '');
          } catch (_) {
            finalSoundUrl = soundUrl ?? '';
          }
        }
      } else {
        finalSoundUrl = soundUrl ?? '';
      }

      final triggerAt = scheduleDateTime.millisecondsSinceEpoch;
      // Gap 1 Fix: unique ID based on title+time to prevent collision
      // when two alarms share the same minute (e.g. morning before+after food)
      final alarmId = (title.hashCode ^ triggerAt).abs() % 0x7FFFFFFF;

      // Gap 4 Fix: Download server tone for offline playback
      String cachedSoundUrl = finalSoundUrl;
      if (finalSoundUrl.startsWith('http://') || finalSoundUrl.startsWith('https://')) {
        try {
          final cacheDir = await dart_path.getApplicationDocumentsDirectory();
          final fileName = 'cached_alarm_tone_${finalSoundUrl.hashCode.abs()}.mp3';
          final cachedFile = dart_io.File('${cacheDir.path}/$fileName');
          if (!await cachedFile.exists()) {
            final response = await dart_http.get(Uri.parse(finalSoundUrl))
                .timeout(const Duration(seconds: 10));
            if (response.statusCode == 200) {
              await cachedFile.writeAsBytes(response.bodyBytes);
            }
          }
          if (await cachedFile.exists()) {
            cachedSoundUrl = cachedFile.path;
            // Update prefs with cached local path
            await prefs.setString('alarm_tone', cachedSoundUrl);
          }
        } catch (_) {
          cachedSoundUrl = finalSoundUrl; // fallback to URL
        }
      }

      await _alarmChannel.invokeMethod('scheduleAlarm', {
        'id': alarmId,
        'triggerAt': triggerAt,
        'title': title,
        'type': scheduleType.toLowerCase(),
        'date': date,
        'notes': notes ?? '',
        'soundUrl': cachedSoundUrl,
        'imageUrl': imageUrl ?? '',
      });

      await saveAlarmToStorage({
        'id': alarmId,
        'alarmType': alarmType.toString().split('.').last,
        'date': date,
        'time': time,
        'title': title,
        'scheduleType': scheduleType,
        'soundUrl': cachedSoundUrl,
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
      return alarm['triggerAt'] == triggerAt ||
             alarm['id'] == triggerAt; // backwards compat
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


  /// Gap 13: Timezone awareness
  /// AlarmManager uses absolute millisecond timestamps — if device timezone
  /// changes, existing alarms fire at the correct UTC time but wrong local time.
  /// Solution: reschedule all alarms after timezone change detection.
  /// This is handled by restoreAlarmsFromStorage() which recalculates times.
  
  /// Gap 12: Read alarm fired history (stored by native AlarmReceiver)
  static Future<List<Map<String, dynamic>>> getAlarmFiredLog() async {
    final prefs = await SharedPreferences.getInstance();
    // Flutter uses getStringList — getStringSet is Android/Java only
    final log = prefs.getStringList('alarm_fired_log') ?? [];
    final result = <Map<String, dynamic>>[];
    for (final entry in log) {
      try {
        result.add(Map<String, dynamic>.from(jsonDecode(entry)));
      } catch (_) {}
    }
    result.sort((a, b) => (b['firedAt'] as int).compareTo(a['firedAt'] as int));
    return result;
  }

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
