import 'package:flutter/services.dart';

import 'alarm_permission_service.dart';

const MethodChannel _alarmChannel = MethodChannel('alarm_service');

class AlarmService {
  static void printAlarmData({
    required String title,
    required DateTime time,
    required String soundUrl,
    required String imageUrl,
  }) {
    print("──────── ALARM SERVICE DATA ────────");
    print("🟢 Title     : $title");
    print("🟢 Time      : $time");
    print("🟢 Sound URL : $soundUrl");
    print("🟢 Image URL : $imageUrl");
    print("───────────────────────────────────");
  }

  static Future<void> scheduleAlarm({
    required DateTime time,
    required String title,
    required String soundUrl,
    required String imageUrl,
  }) async {
    await AlarmPermissionService.ensureFullScreenIntentPermission();

    final triggerAt = time.millisecondsSinceEpoch;
    final date = "${time.year.toString().padLeft(4, '0')}-"
        "${time.month.toString().padLeft(2, '0')}-"
        "${time.day.toString().padLeft(2, '0')}";

    await _alarmChannel.invokeMethod('scheduleAlarm', {
      'id': triggerAt,
      'triggerAt': triggerAt,
      'title': title,
      'type': 'once',
      'date': date,
      'notes': '',
      'soundUrl': soundUrl,
      'imageUrl': imageUrl,
    });
  }
}
