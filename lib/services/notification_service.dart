import 'api_client.dart';

/// Covers:
///   GET  /user/notification/history    ← list notifications
///   POST /user/clear-notifications     ← mark all read / clear

class NotificationService {
  final _api = ApiClient();

  Future<Map<String, dynamic>?> getNotifications() async {
    final candidates = [
      '/user/notification/history',
      '/user/notifications/history',
      '/user/notification-history',
      '/user/notifications',
      '/user/notification/list',
    ];
    Map<String, dynamic>? firstError;
    for (final path in candidates) {
      final res = await _api.safeGet(path);
      if (res == null) continue;
      if (res['status'] == false) {
        firstError ??= res;
        continue;
      }
      if (_hasNotificationList(res)) return res;
      firstError ??= res;
    }
    return firstError;
  }

  bool _hasNotificationList(dynamic value) {
    if (value is List) return true;
    if (value is! Map) return false;
    for (final key in [
      'data',
      'notifications',
      'notification',
      'notification_history',
      'histories',
      'items',
      'list',
      'history',
      'today',
      'yesterday',
      'earlier',
      'unread',
      'read',
    ]) {
      final child = value[key];
      if (child is List) return true;
      if (child is Map && _hasNotificationList(child)) return true;
    }
    return false;
  }

  Future<Map<String, dynamic>> clearNotifications() async {
    final res = await _api.safePost('/user/clear-notifications');
    return res ?? {'status': false, 'message': 'Network error'};
  }
}
