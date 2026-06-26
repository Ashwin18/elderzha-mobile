import 'api_client.dart';

/// Covers:
///   GET  /user/faqs                  ← FAQ list
///   GET  /user/get/issue/type        ← issue types for support
///   POST /user/store/support/ticket  ← raise support ticket
///   GET  /user/policy/{type}         ← privacy/terms policy (public)

class SupportService {
  final _api = ApiClient();

  Future<Map<String, dynamic>?> getFaqs() =>
      _api.safeGet('/user/faqs');

  Future<Map<String, dynamic>?> getIssueTypes() =>
      _api.safeGet('/user/get/issue/type');

  Future<Map<String, dynamic>> storeSupportTicket({
    required int issueTypeId,
    required String description,
  }) async {
    final res = await _api.safePost('/user/store/support/ticket', data: {
      'issue_type_id': issueTypeId,
      'description': description,
    });
    return res ?? {'status': false, 'message': 'Network error'};
  }

  // Public — no auth
  Future<Map<String, dynamic>?> getPolicy(String type) =>
      _api.safeGet('/user/policy/$type');
}
