import 'dart:io';

import 'package:dio/dio.dart';

import 'api_client.dart';

/// Covers:
///   POST /user/store/medical-settings   ← save medical alarms
///   GET  /user/get/medical/records       ← fetch saved alarms
///   GET  /user/get/user-reminders/{id}   ← public: get reminders by user id
///   POST /user/reminder/store            ← create custom reminder
///   GET  /user/reminder/list             ← list all reminders
///   POST /user/reminder/update/{id}      ← toggle / edit reminder

class AlarmService {
  final _api = ApiClient();

  // ── POST /user/store/medical-settings ────────────────────
  // Saves medical + food alarm times
  // Payload mirrors what the wizard collects:
  // {
  //   morning_before_food: "08:00 AM",
  //   morning_after_food:  "09:30 AM",
  //   afternoon_before_food: "01:00 PM",
  //   afternoon_after_food:  "02:30 PM",
  //   night_before_food:   "08:00 PM",
  //   night_after_food:    "09:30 PM",
  //   breakfast_time:      "08:30 AM",
  //   lunch_time:          "01:30 PM",
  //   dinner_time:         "08:30 PM",
  // }
  Future<Map<String, dynamic>> saveMedicalSettings(
      Map<String, dynamic> payload) async {
    final res =
        await _api.safePost('/user/store/medical-settings', data: payload);
    return res ?? {'status': false, 'message': 'Network error'};
  }

  Future<Map<String, dynamic>> saveMedicalSettingsMultipart({
    required Map<String, dynamic> payload,
    File? medicalFile,
    File? foodFile,
    File? alarmTone,
  }) async {
    final form = FormData.fromMap({
      ...payload,
      if (medicalFile != null)
        'medical_file': await MultipartFile.fromFile(medicalFile.path),
      if (foodFile != null)
        'food_file': await MultipartFile.fromFile(foodFile.path),
      if (alarmTone != null)
        'alaram_tone': await MultipartFile.fromFile(alarmTone.path),
    });
    final res = await _api.safeMultipartPost('/user/store/medical-settings',
        data: form);
    return res ?? {'status': false, 'message': 'Network error'};
  }

  // ── GET /user/get/medical/records ─────────────────────────
  Future<Map<String, dynamic>?> getMedicalRecords() =>
      _api.safeGet('/user/get/medical/records');

  // ── GET /user/get/user-reminders/{user_id} ────────────────
  // Public — no auth needed
  Future<Map<String, dynamic>?> getUserReminders(int userId) =>
      _api.safeGet('/user/get/user-reminders/$userId');

  // ── POST /user/reminder/store ─────────────────────────────
  Future<Map<String, dynamic>> storeReminder({
    required String title,
    required String time,
    required String type, // 'medical' | 'food' | 'family' | 'custom'
    String? date, // for one-time reminders
    bool repeat = true,
    String repeatType = 'once',
  }) async {
    final res = await _api.safePost('/user/reminder/store', data: {
      'title': title,
      'time': time,
      'type': type,
      if (date != null) 'date': date,
      'repeat': repeat ? 1 : 0,
      'repeat_type': repeatType,
    });
    return res ?? {'status': false, 'message': 'Network error'};
  }

  // ── GET /user/reminder/list ───────────────────────────────
  Future<Map<String, dynamic>?> listReminders() =>
      _api.safeGet('/user/reminder/list');

  // ── POST /user/reminder/update/{id} ──────────────────────
  Future<Map<String, dynamic>> updateReminder({
    required int id,
    String? title,
    String? time,
    bool? enabled,
    String? repeatType,
  }) async {
    final res = await _api.safePost('/user/reminder/update/$id', data: {
      if (title != null) 'title': title,
      if (time != null) 'time': time,
      if (enabled != null) 'is_active': enabled ? 1 : 0,
      if (repeatType != null) 'repeat_type': repeatType,
      if (repeatType != null) 'repeat': repeatType == 'once' ? 0 : 1,
    });
    return res ?? {'status': false, 'message': 'Network error'};
  }

  Future<Map<String, dynamic>> deleteReminder(int id) async {
    final paths = [
      '/user/reminder/delete/$id',
      '/user/reminder/$id/delete',
      '/user/reminder/destroy/$id',
      '/user/reminder/remove/$id',
    ];

    Map<String, dynamic>? last;
    for (final path in paths) {
      final res = await _api.safePost(path);
      if (res == null) continue;
      last = res;
      if (res['status'] != false) return res;
    }

    final disabled = await updateReminder(id: id, enabled: false);
    return disabled['status'] == false && last != null ? last : disabled;
  }
}
