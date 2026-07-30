// lib/services/fall_detection/fall_alert_service.dart
import '../api_client.dart';

class FallAlertService {
  final _api = ApiClient();

  // POST /user/fall-alert — sends SMS + FCM + admin alert via backend
  Future<Map<String, dynamic>> sendFallAlert({
    required String userId,
    required String userName,
    double? latitude,
    double? longitude,
    String? locationUrl,
  }) async {
    final res = await _api.safePost('/user/fall-alert', data: {
      'user_id':      userId,
      'user_name':    userName,
      'latitude':     latitude?.toString() ?? '',
      'longitude':    longitude?.toString() ?? '',
      'location_url': locationUrl ?? '',
      'detected_at':  DateTime.now().toIso8601String(),
    });
    return res ?? {'status': false};
  }

  // POST /user/fall-alert/false-alarm
  Future<void> logFalseAlarm({required String userId}) async {
    await _api.safePost('/user/fall-alert/false-alarm', data: {
      'user_id': userId,
      'responded_at': DateTime.now().toIso8601String(),
    });
  }
}
