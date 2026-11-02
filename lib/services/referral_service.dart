import 'api_client.dart';

/// Refer & Earn — talks to /user/referral, /user/referral/apply and /seen.
class ReferralService {
  static final ApiClient _api = ApiClient();

  /// {eligible, code, link, share_text, seeds_per_referral, seeds_total,
  ///  trees, unseen_seeds, stats{total,successful,in_trial,invited},
  ///  recent[{name, joined, status, seeds, image}]} or null on a network error.
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

  /// The "You earned seeds" popup was shown.
  static Future<void> markSeen() async {
    await _api.safePost('/user/referral/seen', data: {});
  }
}
