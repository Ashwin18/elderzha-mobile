import 'api_client.dart';

/// Refer a Friend — talks to /user/referral and /user/referral/apply.
class ReferralService {
  static final ApiClient _api = ApiClient();

  /// {eligible, code, link, share_text, stats{total,successful,in_trial},
  ///  recent[{name, joined, status, image}]} or null on a network error.
  static Future<Map<String, dynamic>?> load() async {
    final res = await _api.safeGet('/user/referral');
    if (res != null && res['status'] == true && res['data'] is Map) {
      return Map<String, dynamic>.from(res['data'] as Map);
    }
    return null;
  }

  /// Returns null when the code was applied, otherwise the message to show.
  static Future<String?> applyCode(String code) async {
    final res = await _api.safePost('/user/referral/apply', data: {'code': code});
    if (res == null) return 'Could not reach the server. Please try again.';
    if (res['status'] == true) return null;
    return (res['message'] ?? 'Could not apply the code.').toString();
  }
}
