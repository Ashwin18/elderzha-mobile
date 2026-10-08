import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One place that decides which notifications exist: the server's history
/// plus the ones saved on the phone, de-duplicated and cleaned of API
/// envelopes ("Notification history fetched successfully") and errors.
/// The Notifications screen lists exactly this, and the bell badge on Home
/// counts exactly this, so the two can never disagree.
class NotificationList {
  NotificationList._();

  static Future<List<Map<String, dynamic>>> merged(
      Map<String, dynamic>? serverResponse) async {
    final local = await _loadLocalNotifications();
    return _dedupeNotifications([...local, ..._extractList(serverResponse)])
        .where(_isUsableNotification)
        .toList();
  }

  static List _extractList(Map<String, dynamic>? res) {
    if (res == null) return [];
    final out = <Map<String, dynamic>>[];
    _collectNotifications(res, out);
    return out;
  }

  static void _collectNotifications(
    dynamic value,
    List<Map<String, dynamic>> out, {
    String? groupDate,
  }) {
    if (value is List) {
      for (final item in value) {
        _collectNotifications(item, out, groupDate: groupDate);
      }
      return;
    }
    if (value is! Map) return;

    final map = Map<String, dynamic>.from(value);
    final nextGroup = (map['date'] ?? map['group_date'])?.toString();
    if (!_isApiEnvelope(map) && _looksLikeNotification(map)) {
      out.add({
        ...map,
        if (groupDate != null && map['group_date'] == null)
          'group_date': groupDate,
      });
      return;
    }

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
      final child = map[key];
      if (child != null) {
        _collectNotifications(child, out, groupDate: nextGroup ?? groupDate);
      }
    }
  }

  static bool _isApiEnvelope(Map map) {
    final hasListChild = [
      'data',
      'notifications',
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
    ].any((key) => map[key] is List || map[key] is Map);
    final hasStatusMessage = map.containsKey('status') &&
        (map.containsKey('message') || map.containsKey('msg'));
    return hasListChild && hasStatusMessage;
  }

  static bool _looksLikeNotification(Map map) {
    if (map['status'] == false) return false;
    if (!_isUsableNotification(Map<String, dynamic>.from(map))) return false;
    const keys = [
      'title',
      'message',
      'body',
      'notification',
      'description',
      'module_type',
      'notification_type',
      'type',
      'category',
      'timeline',
      'created_at',
    ];
    return keys.any((key) {
      final value = map[key];
      return value != null && value.toString().trim().isNotEmpty;
    });
  }

  static Future<List<Map<String, dynamic>>> _loadLocalNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    // Pushes received while the app was in the background are saved by a
    // separate isolate; reload so this screen sees them instead of its
    // older cached copy.
    await prefs.reload();
    final raw = prefs.getStringList('local_notification_history') ?? [];
    final out = <Map<String, dynamic>>[];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map) out.add(Map<String, dynamic>.from(decoded));
      } catch (_) {}
    }
    return out;
  }

  static List<Map<String, dynamic>> _dedupeNotifications(List items) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final moduleKey =
          '${map['module_type'] ?? map['notification_type'] ?? map['type'] ?? ''}:${map['module_id'] ?? map['feed_id'] ?? map['post_id'] ?? map['poll_id'] ?? map['activity_id'] ?? map['offer_id'] ?? map['coupon_id'] ?? ''}';
      final id = _cleanText(map['id'] ??
          map['notification_id'] ??
          (moduleKey == ':' ? null : moduleKey) ??
          map['created_at'] ??
          map['title'] ??
          map['message'] ??
          '');
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      out.add(map);
    }
    return out;
  }

  static String _cleanText(dynamic value) => value
      .toString()
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .trim();

  static bool _isUsableNotification(Map<String, dynamic> n) {
    final title = _cleanText(n['title'] ?? n['notification_title'] ?? '');
    final body = _cleanText(n['body'] ??
        n['message'] ??
        n['notification'] ??
        n['description'] ??
        n['response'] ??
        '');
    final combined = '$title $body'.toLowerCase();
    if (combined.trim().isEmpty) return true;
    return !combined.contains('server error') &&
        !combined.contains('client error') &&
        !combined.contains('exception') &&
        !combined.contains('invalid_grant') &&
        !combined.contains('firebase token missing') &&
        !combined.contains('notification history fetched successfully') &&
        !combined.contains('fetched successfully') &&
        !combined.contains('network error');
  }
}
