import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/models/alarm_reminder_model.dart';
import 'alarm_permission_service.dart';

const MethodChannel _alarmChannel = MethodChannel('alarm_service');

class AlarmScheduler {
  // --------------------------------------------------
  // ⏰ SCHEDULE SINGLE REMINDER
  // --------------------------------------------------
  static Future<void> scheduleReminder(AlarmReminderData reminder) async {
    if (reminder.date.isEmpty || reminder.time.isEmpty) {
      return;
    }

    try {
      await AlarmPermissionService.ensureFullScreenIntentPermission();

      final dateParts = reminder.date.split('-');
      final timeParts = reminder.time.split(':');

      if (dateParts.length < 3 || timeParts.length < 2) {
        return;
      }

      final scheduleDateTime = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
        timeParts.length > 2 ? int.parse(timeParts[2]) : 0,
      );

      if (scheduleDateTime.isBefore(DateTime.now())) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final alarmTone = prefs.getString('alarm_tone');
      final finalSoundUrl = (alarmTone != null && alarmTone.isNotEmpty)
          ? alarmTone
          : (reminder.ringtone);

      final triggerAt = scheduleDateTime.millisecondsSinceEpoch;

      // 🔥 Important: Use actual type from model
      //final type = (reminder.type ?? 'once').toLowerCase();
      final type = 'once';

      await _alarmChannel.invokeMethod('scheduleAlarm', {
        'id': triggerAt,
        'triggerAt': triggerAt,
        'title': reminder.title.isEmpty ? 'Reminder' : reminder.title,
        'type': type,
        'date': reminder.date,
        'notes': reminder.notes,
        'soundUrl': finalSoundUrl,
        'imageUrl': reminder.uploadFile,
      });
    } catch (e) {
      print('AlarmScheduler error: $e');
    }
  }

  // --------------------------------------------------
  // 🔁 SCHEDULE MULTIPLE
  // --------------------------------------------------
  static Future<void> scheduleAll(List<AlarmReminderData> reminders) async {
    for (final reminder in reminders) {
      await scheduleReminder(reminder);
    }
  }

  // --------------------------------------------------
  // ❌ CANCEL REMINDER
  // --------------------------------------------------
  static Future<void> cancelReminder(int id) async {
    await _alarmChannel.invokeMethod('cancelAlarm', {'id': id});
  }

  // --------------------------------------------------
  // 🔋 BATTERY OPTIMIZATION
  // --------------------------------------------------
  static Future<void> requestBatteryOptimization() async {
    await _alarmChannel.invokeMethod('requestBatteryOptimization');
  }

  // --------------------------------------------------
  // ⏰ EXACT ALARM PERMISSION (Android 12+)
  // --------------------------------------------------
  static Future<void> requestExactAlarmPermission() async {
    await _alarmChannel.invokeMethod('requestExactAlarmPermission');
  }
}
