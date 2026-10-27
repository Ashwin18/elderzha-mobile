import 'api_client.dart';

/// Asks the server (GET /user/onboarding-info) two things:
///   prelaunch         — an Early Bird launch is still ahead, so sign-up skips
///                       alarm and family setup (they happen at launch).
///   alarm_setup_done  — this user already has an alarm setup / family member.
/// If the server can't be reached the answers fall back to the normal flow
/// (prelaunch = false), so a network problem never changes what people see.
class OnboardingInfo {
  static final ApiClient _api = ApiClient();

  static Future<Map<String, dynamic>?> fetch() async {
    final res = await _api.safeGet('/user/onboarding-info');
    if (res != null && res['status'] == true && res['data'] is Map) {
      return Map<String, dynamic>.from(res['data'] as Map);
    }
    return null;
  }

  /// True while sign-up should skip alarm and family setup.
  static Future<bool> skipAlarmSetup() async =>
      (await fetch())?['prelaunch'] == true;
}
