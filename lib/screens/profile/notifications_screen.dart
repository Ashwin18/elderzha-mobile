import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/services.dart';
import '../../utils/app_routes.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _svc = NotificationService();
  List _today = [], _yesterday = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _svc.getNotifications();
    final local = await _loadLocalNotifications();
    if (!mounted) return;
    final all = _dedupeNotifications([...local, ..._extractList(res)]);
    final now = DateTime.now();
    setState(() {
      _today = all
          .where((n) =>
              _isSameDay(_dateOf(n), now) ||
              n['is_today'] == true ||
              n['today'] == true)
          .toList();
      _yesterday = all.where((n) => !_today.contains(n)).toList();
      _loading = false;
    });
  }

  List _extractList(Map<String, dynamic>? res) {
    if (res == null) return [];
    final out = <Map<String, dynamic>>[];
    _collectNotifications(res, out);
    return out;
  }

  void _collectNotifications(
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
    if (_looksLikeNotification(map)) {
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

  bool _looksLikeNotification(Map map) {
    if (map['status'] == false) return false;
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

  Future<List<Map<String, dynamic>>> _loadLocalNotifications() async {
    final prefs = await SharedPreferences.getInstance();
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

  List<Map<String, dynamic>> _dedupeNotifications(List items) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final moduleKey =
          '${map['module_type'] ?? map['type'] ?? ''}:${map['module_id'] ?? ''}';
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

  DateTime? _dateOf(dynamic n) {
    if (n is! Map) return null;
    final group = (n['group_date'] ?? '').toString().toLowerCase();
    final now = DateTime.now();
    if (group == 'today') return now;
    if (group == 'yesterday') return now.subtract(const Duration(days: 1));
    final raw =
        (n['created_at'] ?? n['date'] ?? n['time'] ?? n['timeline'] ?? '')
            .toString();
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }

  bool _isSameDay(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(children: [
        Container(
          color: C.yellow,
          child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
                child: Row(children: [
                  GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: C.ink)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text('Notifications',
                          style: poppins(18, w: FontWeight.w700, c: C.ink))),
                  GestureDetector(
                    onTap: () async {
                      await _svc.clearNotifications();
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('local_notification_history');
                      _load();
                    },
                    child: Text('Mark all read',
                        style:
                            poppins(12, w: FontWeight.w700, c: C.yellowDeep)),
                  ),
                ]),
              )),
        ),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
                color: C.white,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28))),
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: C.yellowDark))
                : ListView(
                    padding: const EdgeInsets.all(14),
                    children: _today.isEmpty && _yesterday.isEmpty
                        ? [
                            const SizedBox(height: 120),
                            const Icon(Icons.notifications_none_rounded,
                                size: 44, color: C.txl),
                            const SizedBox(height: 12),
                            Text('No notifications yet',
                                style:
                                    poppins(14, w: FontWeight.w700, c: C.ink),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 6),
                            Text(
                                'Alarms, events, payments, polls, and activity updates will appear here.',
                                style: poppins(12, c: C.txl, h: 1.45),
                                textAlign: TextAlign.center),
                          ]
                        : [
                            if (_today.isNotEmpty) ...[
                              _groupLabel('Today'),
                              ..._today.map<Widget>((n) => _notifRow(n)),
                            ],
                            if (_yesterday.isNotEmpty) ...[
                              _groupLabel('Earlier'),
                              ..._yesterday.map<Widget>((n) => _notifRow(n)),
                            ],
                          ],
                  ),
          ),
        ),
      ]),
    );
  }

  Widget _groupLabel(String t) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        child: Text(t.toUpperCase(),
            style: poppins(11, w: FontWeight.w700, c: C.txl)),
      );

  Widget _notifRow(dynamic n) {
    if (n is! Map) return const SizedBox.shrink();
    final dot = n['dot'] as Color? ?? C.yellow;
    final title = _cleanText(n['title'] ??
        n['message'] ??
        n['body'] ??
        n['description'] ??
        n['notification'] ??
        n['data']?['message'] ??
        '');
    final tag = _notificationLabel(n);
    final colors = _labelColors(tag);
    final tagBg = colors.$1;
    final tagFg = colors.$2;
    final subtitle = _cleanText(n['message'] ??
        n['body'] ??
        n['description'] ??
        n['data']?['message'] ??
        '');
    final time = n['timeline'] ??
        n['time'] ??
        n['created_at'] ??
        n['date'] ??
        n['group_date'] ??
        '';
    if (title.isEmpty && tag.isEmpty && time.toString().isEmpty) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      onTap: () => _openTarget(n),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: C.bg2))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 3, right: 10),
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title, style: poppins(13, w: FontWeight.w700, c: C.ink)),
                if (subtitle.isNotEmpty && subtitle != title) ...[
                  const SizedBox(height: 3),
                  Text(subtitle, style: poppins(12, c: C.txm, h: 1.35)),
                ],
                const SizedBox(height: 4),
                Row(children: [
                  if (tag.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: tagBg,
                          borderRadius: BorderRadius.circular(999)),
                      child: Text(tag,
                          style: poppins(10, w: FontWeight.w700, c: tagFg)),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(time, style: poppins(11, c: C.txl)),
                ]),
              ])),
          const Icon(Icons.chevron_right_rounded, color: C.txl, size: 20),
        ]),
      ),
    );
  }

  void _openTarget(Map n) {
    if (_isOfferNotification(n)) {
      final offerId = _moduleId(n);
      if (offerId != 0) {
        Navigator.pushNamed(context, '/offer-detail', arguments: offerId);
        return;
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
        arguments: {'tab': 3, 'notification': Map<String, dynamic>.from(n)},
      );
      return;
    }
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.home,
      (route) => false,
      arguments: {
        'tab': 2,
        'communityTab': _communityTabOf(n),
        'notification': Map<String, dynamic>.from(n),
      },
    );
  }

  int _communityTabOf(Map n) {
    final type = _typeText(n);
    if (type.contains('poll') || type.contains('pool')) return 2;
    if (type.contains('activity')) return 3;
    if (type.contains('feed') || type.contains('post')) return 1;
    return 0;
  }

  bool _isOfferNotification(Map n) {
    final type = _typeText(n);
    return type.contains('offer') ||
        type.contains('coupon') ||
        type.contains('deal');
  }

  int _moduleId(Map n) =>
      int.tryParse((n['module_id'] ??
              n['offer_id'] ??
              n['coupon_id'] ??
              n['data']?['module_id'] ??
              n['data']?['offer_id'] ??
              0)
          .toString()) ??
      0;

  String _notificationLabel(Map n) {
    final type = _typeText(n);
    if (type.contains('offer') || type.contains('coupon')) return 'Offer';
    if (type.contains('poll') || type.contains('pool')) return 'Poll';
    if (type.contains('activity')) return 'Activity';
    if (type.contains('feed') || type.contains('post')) return 'Feed';
    if (type.contains('reminder') || type.contains('alarm')) return 'Reminder';
    return 'Update';
  }

  String _typeText(Map n) => _cleanText(n['module_type'] ??
          n['type'] ??
          n['notification_type'] ??
          n['category'] ??
          n['tag'] ??
          n['title'] ??
          n['message'] ??
          n['body'])
      .toLowerCase();

  (Color, Color) _labelColors(String label) {
    switch (label) {
      case 'Offer':
        return (C.yellowMid, C.yellowDeep);
      case 'Poll':
        return (C.blueLight, const Color(0xFF0D47A1));
      case 'Activity':
        return (C.greenLight, C.green);
      case 'Feed':
        return (C.yellowLight, C.yellowDeep);
      case 'Reminder':
        return (const Color(0xFFFFE6E6), C.red);
      default:
        return (C.bg2, C.txm);
    }
  }

  String _cleanText(dynamic value) => value
      .toString()
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .trim();
}
