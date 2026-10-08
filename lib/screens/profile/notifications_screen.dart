import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/services.dart';
import '../../utils/app_routes.dart';
import '../../utils/notification_list.dart';

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
    final all = await NotificationList.merged(res);
    if (!mounted) return;
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

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  /// "Today, 3:59 PM" / "Yesterday, 9:10 AM" / "6 Oct, 8:00 PM".
  /// The server sends a ready-made label in `timeline` ("2 hours ago"), which
  /// is used as-is. Locally saved notifications only have a raw ISO timestamp
  /// ("2026-10-08T15:59:02.918503"), which used to be shown unformatted.
  String _timeText(Map n) {
    final label = (n['timeline'] ?? '').toString().trim();
    if (label.isNotEmpty && label.toLowerCase() != 'null') return label;

    final raw = (n['created_at'] ?? n['date'] ?? n['time'] ?? '').toString().trim();
    if (raw.isNotEmpty) {
      try {
        final d = DateTime.parse(raw).toLocal();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final day = DateTime(d.year, d.month, d.day);
        final diff = today.difference(day).inDays;
        final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
        final clock =
            '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
        if (diff == 0) return 'Today, $clock';
        if (diff == 1) return 'Yesterday, $clock';
        final year = d.year == now.year ? '' : ' ${d.year}';
        return '${d.day} ${_monthNames[d.month - 1]}$year, $clock';
      } catch (_) {
        return raw; // not a date we understand — show it as it came
      }
    }
    return (n['group_date'] ?? '').toString();
  }

  bool _isSameDay(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: C.bgGradient),
        child: Column(children: [
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
      ),
    );
  }

  Widget _groupLabel(String t) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        child: Text(t.toUpperCase(),
            style: poppins(11, w: FontWeight.w700, c: C.txl)),
      );

  Widget _notifRow(dynamic n) {
    if (n is! Map) return const SizedBox.shrink();
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
    final subtitle = _cleanText(n['message'] ??
        n['body'] ??
        n['description'] ??
        n['data']?['message'] ??
        '');
    final time = _timeText(n);
    if (title.isEmpty && tag.isEmpty && time.isEmpty) {
      return const SizedBox.shrink();
    }
    final gradient = _labelGradient(tag);
    final icon = _labelIcon(tag);

    return GestureDetector(
      onTap: () => _openTarget(n),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tagBg, C.white],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: gradient.last.withOpacity(.12), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: C.white, size: 22),
            ),
            Positioned(
              bottom: -4,
              right: -4,
              child: Container(
                width: 20,
                height: 20,
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: C.ink,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(BorderSide(color: C.white, width: 2)),
                ),
                child: ClipOval(
                  child: Image.asset('assets/images/app_icon.png', fit: BoxFit.cover),
                ),
              ),
            ),
          ]),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title, style: poppins(13.5, w: FontWeight.w700, c: C.ink)),
                if (subtitle.isNotEmpty && subtitle != title) ...[
                  const SizedBox(height: 3),
                  Text(subtitle, style: poppins(12, c: C.txm, h: 1.35)),
                ],
                const SizedBox(height: 6),
                Row(children: [
                  if (tag.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: gradient.last,
                          borderRadius: BorderRadius.circular(999)),
                      child: Text(tag.toUpperCase(),
                          style: poppins(9.5, w: FontWeight.w800, c: C.white)),
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

  IconData _labelIcon(String label) {
    switch (label) {
      case 'Offer':
        return Icons.card_giftcard_rounded;
      case 'Poll':
        return Icons.how_to_vote_rounded;
      case 'Activity':
        return Icons.groups_rounded;
      case 'Feed':
        return Icons.forum_rounded;
      case 'Reminder':
        return Icons.alarm_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  List<Color> _labelGradient(String label) {
    switch (label) {
      case 'Offer':
        return const [Color(0xFFFFC928), Color(0xFFB8860B)];
      case 'Poll':
        return const [Color(0xFF6FCF5A), Color(0xFF3B6D11)];
      case 'Activity':
        return const [Color(0xFF4FA8E8), Color(0xFF0C447C)];
      case 'Feed':
        return const [Color(0xFFB98CE8), Color(0xFF6B3FA0)];
      case 'Reminder':
        return const [Color(0xFFE86868), Color(0xFF9B2C2C)];
      default:
        return const [Color(0xFFB0AEA6), Color(0xFF716F68)];
    }
  }

  String _cleanText(dynamic value) => value
      .toString()
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .trim();

}
