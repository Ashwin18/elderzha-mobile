import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../services/services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.onOpenReminder,
    this.onOpenSpike,
  });

  final VoidCallback? onOpenReminder;
  final VoidCallback? onOpenSpike;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _actSvc = ActivityService();

  bool _checkInDone = false;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  // API data
  List _monthData = []; // from /daily/activity/month
  List _homeActivities = []; // from /activities/home
  List _reminders = []; // from /user/reminder/list
  Map<String, dynamic>? _medicalRecord;
  Map<String, dynamic>? _todayActivity;
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final results = await Future.wait([
      _actSvc.getMonthlyActivities(
        month: _focusedMonth.month,
        year: _focusedMonth.year,
      ), // GET /user/daily/activity/month
      _actSvc.getTodayActivity(), // GET /user/get/today/activity
      _actSvc.getHomeActivities(), // GET /user/activities/home
      AlarmService().listReminders(), // GET /user/reminder/list
      AlarmService().getMedicalRecords(), // GET /user/get/medical/records
      NotificationService()
          .getNotifications(), // GET /user/notification/history
    ]);
    if (!mounted) return;
    setState(() {
      _monthData = _extractList(results[0]);
      _checkInDone = _hasData(results[1]);
      _todayActivity = _extractMap(results[1]);
      _homeActivities = _extractList(results[2]);
      _reminders = _extractList(results[3]);
      _medicalRecord = _extractMap(results[4]);
      _notificationCount = _extractNotificationCount(results[5]);
    });
  }

  bool _hasData(Map<String, dynamic>? res) {
    if (res == null) return false;
    if (res['status'] == false) return false;
    final data = res['data'];
    if (data == null || data == false) return false;
    if (data is List) return data.isNotEmpty;
    if (data is Map) return data.isNotEmpty;
    if (data is String) return data.trim().isNotEmpty;
    return data == true;
  }

  Map<String, dynamic>? _extractMap(Map<String, dynamic>? res) {
    if (res == null || res['status'] == false || res['data'] == false) {
      return null;
    }
    final data = res['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  List _extractList(Map<String, dynamic>? res) {
    if (res == null) return [];
    final keys = [
      'data',
      'items',
      'list',
      'activities',
      'reminders',
      'records'
    ];
    for (final key in keys) {
      final value = res[key];
      if (value is List) return value;
      if (value is Map) {
        for (final nested in keys) {
          final nestedValue = value[nested];
          if (nestedValue is List) return nestedValue;
        }
      }
    }
    return [];
  }

  Future<void> _openCheckIn() async {
    final result = await Navigator.pushNamed(context, AppRoutes.checkIn);
    if (!mounted) return;
    if (result == true) {
      setState(() {
        _checkInDone = true;
        final now = DateTime.now();
        _selectedDay = now;
        _focusedMonth = DateTime(now.year, now.month);
      });
      await _loadAll();
    }
  }

  int _extractNotificationCount(Map<String, dynamic>? res) {
    if (res == null || res['status'] == false) return 0;
    final explicit = int.tryParse((res['unread_count'] ??
            res['notification_count'] ??
            res['count'] ??
            res['total'] ??
            res['data']?['unread_count'] ??
            res['data']?['count'] ??
            '')
        .toString());
    if (explicit != null) return explicit;

    final out = <Map<String, dynamic>>[];
    _collectNotifications(res, out);
    return out.length;
  }

  void _collectNotifications(dynamic value, List<Map<String, dynamic>> out) {
    if (value is List) {
      for (final item in value) {
        _collectNotifications(item, out);
      }
      return;
    }
    if (value is! Map) return;
    final map = Map<String, dynamic>.from(value);
    if (_looksLikeNotification(map)) {
      out.add(map);
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
      if (child != null) _collectNotifications(child, out);
    }
  }

  bool _looksLikeNotification(Map map) {
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

  Future<void> _changeMonth(int delta) async {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
      _selectedDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    });
    await _loadAll();
  }

  // Determine day type from API data, fallback to June 2026 static map
  String _dayType(int day) {
    final cellDate = DateTime(_focusedMonth.year, _focusedMonth.month, day);
    for (final d in _monthData) {
      try {
        final date = _parseDate(
            d['date'] ?? d['activity_date'] ?? d['created_at'] ?? '');
        if (date.year == cellDate.year &&
            date.month == cellDate.month &&
            date.day == day) {
          if (_truthy(d['has_checkin']) ||
              _truthy(d['is_completed']) ||
              _truthy(d['submitted']) ||
              d['mood'] != null) {
            return 'checkin';
          }
          if (_truthy(d['has_event'])) return 'event';
        }
      } catch (_) {}
    }
    final hasReminder = _remindersForDay(cellDate).isNotEmpty;
    if (hasReminder) return 'event';
    final now = DateTime.now();
    if (_dateOnly(cellDate).isAfter(_dateOnly(now))) return 'future';
    if (cellDate.year == now.year &&
        cellDate.month == now.month &&
        day == now.day) {
      return _checkInDone ? 'checkin' : 'today';
    }
    return 'miss';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: C.bg,
      body: RefreshIndicator(
        onRefresh: _loadAll,
        color: C.yellowDark,
        child: CustomScrollView(
          slivers: [
            // White top bar
            SliverToBoxAdapter(
              child: Container(
                color: C.white,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Good morning 👋',
                                style: poppins(
                                  12,
                                  w: FontWeight.w600,
                                  c: C.txl,
                                ),
                              ),
                              Text(
                                auth.userName,
                                style: poppins(
                                  19,
                                  w: FontWeight.w700,
                                  c: C.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.notifications,
                          ),
                          child: Stack(
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(
                                  Icons.notifications_outlined,
                                  size: 24,
                                  color: C.ink,
                                ),
                              ),
                              if (_notificationCount > 0)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: C.red,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: C.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _notificationCount > 99
                                            ? '99+'
                                            : '$_notificationCount',
                                        style: poppins(
                                          8,
                                          w: FontWeight.w700,
                                          c: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () =>
                              Navigator.pushNamed(context, AppRoutes.profile),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: C.yellowMid,
                              shape: BoxShape.circle,
                              border: Border.all(color: C.yellow, width: 2),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              size: 18,
                              color: C.yellowDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _todayWellbeingCard(auth.userName),
                  const SizedBox(height: 14),
                  _secLabel(
                    Icons.calendar_today_rounded,
                    _monthTitle(_focusedMonth),
                  ),
                  _calCard(),
                  const SizedBox(height: 12),
                  _secLabel(Icons.timeline_rounded, _detailLabel()),
                  _detailCard(),
                  const SizedBox(height: 12),
                  _quickActions(),
                  if (_homeActivities.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _secLabel(
                      Icons.local_fire_department_rounded,
                      'Activities for you',
                    ),
                    ..._homeActivities
                        .take(3)
                        .map<Widget>((a) => _activityChip(a)),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _todayWellbeingCard(String userName) {
    final nextReminder = _nextReminderForToday();
    final todayCount = _remindersForDay(DateTime.now()).length;
    final activeDays = _activeDaysInFocusedMonth();
    final summary = _checkInSummary(_todayActivity);
    final mood = _field(_todayActivity, ['mood', 'mood_name', 'feeling']);
    final heroEmoji = _checkInDone
        ? (_moodEmojiForDay(DateTime.now().day).isNotEmpty
            ? _moodEmojiForDay(DateTime.now().day)
            : '✓')
        : '😊';
    final title = _checkInDone
        ? (summary.isNotEmpty
            ? 'Today feels like $summary'
            : 'Today’s check-in is saved')
        : 'Check in once, see your day clearly';
    final subtitle = _checkInDone
        ? (mood.isNotEmpty ? 'Mood logged as $mood' : 'Your day is logged')
        : 'A quick wellbeing check for $userName';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.ink,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: C.ink.withOpacity(.15),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: C.yellow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: heroEmoji == '✓'
                  ? const Icon(Icons.check_rounded, color: C.ink, size: 31)
                  : Text(heroEmoji, style: const TextStyle(fontSize: 29)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Today’s wellbeing',
                  style: poppins(11, w: FontWeight.w800, c: Colors.white54)),
              const SizedBox(height: 3),
              Text(title,
                  style: poppins(18,
                      w: FontWeight.w900, c: Colors.white, h: 1.22)),
              const SizedBox(height: 3),
              Text(subtitle, style: poppins(11, c: Colors.white60, h: 1.35)),
            ]),
          ),
        ]),
        const SizedBox(height: 13),
        Row(children: [
          _todayMetric(
            nextReminder == null
                ? '--'
                : (nextReminder['time'] ?? '--').toString(),
            'Next reminder',
          ),
          const SizedBox(width: 8),
          _todayMetric('$todayCount', 'Today'),
          const SizedBox(width: 8),
          _todayMetric('$activeDays', 'Active days'),
        ]),
        const SizedBox(height: 13),
        GestureDetector(
          onTap: _checkInDone ? null : _openCheckIn,
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: _checkInDone ? Colors.white.withOpacity(.12) : C.yellow,
              borderRadius: BorderRadius.circular(16),
              border: _checkInDone
                  ? Border.all(color: Colors.white.withOpacity(.12))
                  : null,
            ),
            child: Center(
              child: Text(
                _checkInDone
                    ? 'Check-in completed for today'
                    : 'Start daily check-in →',
                style: poppins(
                  13,
                  w: FontWeight.w900,
                  c: _checkInDone ? Colors.white70 : C.ink,
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _todayMetric(String value, String label) => Expanded(
        child: Container(
          constraints: const BoxConstraints(minHeight: 66),
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.09),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.1)),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: poppins(15, w: FontWeight.w900, c: Colors.white)),
            const SizedBox(height: 3),
            Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: poppins(9, w: FontWeight.w700, c: Colors.white54)),
          ]),
        ),
      );

  Widget _quickActions() => Row(children: [
        Expanded(
          child: _quickAction(
            Icons.mood_rounded,
            'Check-in',
            _checkInDone ? null : _openCheckIn,
            active: !_checkInDone,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _quickAction(
            Icons.notifications_active_rounded,
            'Reminder',
            widget.onOpenReminder ??
                () => Navigator.pushNamed(context, AppRoutes.reminder),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _quickAction(
            Icons.bolt_rounded,
            'Spike',
            widget.onOpenSpike ??
                () => Navigator.pushNamed(context, AppRoutes.community),
          ),
        ),
      ]);

  Widget _quickAction(IconData icon, String label, VoidCallback? onTap,
          {bool active = false}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: active ? C.yellow : C.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: active ? C.yellowDark : C.bd),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 22, color: active ? C.ink : C.txl),
            const SizedBox(height: 4),
            Text(label,
                style:
                    poppins(10, w: FontWeight.w900, c: active ? C.ink : C.txm)),
          ]),
        ),
      );

  Widget _secLabel(IconData icon, String label) => Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 8),
        child: Row(
          children: [
            Icon(icon, size: 14, color: C.yellowDark),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: poppins(11, w: FontWeight.w700, c: C.txl),
            ),
          ],
        ),
      );

  // ── Activity chip from home activities API ────────────────
  Widget _activityChip(dynamic a) {
    final name = a['title'] ?? a['name'] ?? '';
    final emoji = a['emoji'] ?? '🏃';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.bd),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: poppins(13, w: FontWeight.w600, c: C.ink),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 18, color: C.txl),
        ],
      ),
    );
  }

  // ── Calendar ──────────────────────────────────────────────
  Widget _calCard() {
    const weekdays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
    final startOffset =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday % 7;
    final daysInMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    ).day;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.bd),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => _changeMonth(-1),
                child: const Icon(
                  Icons.chevron_left_rounded,
                  size: 18,
                  color: C.txl,
                ),
              ),
              Text(
                _monthTitle(_focusedMonth),
                style: poppins(13, w: FontWeight.w700, c: C.ink),
              ),
              GestureDetector(
                onTap: () => _changeMonth(1),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: C.txl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: weekdays
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: poppins(9, w: FontWeight.w700, c: C.txl),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
            ),
            itemCount: startOffset + daysInMonth,
            itemBuilder: (_, i) {
              if (i < startOffset) return const SizedBox();
              final day = i - startOffset + 1;
              final type = _dayType(day);
              final isSel = _selectedDay.day == day;
              final moodEmoji = type == 'checkin' ? _moodEmojiForDay(day) : '';
              Color bg, fg;
              switch (type) {
                case 'checkin':
                  bg = C.greenLight;
                  fg = C.green;
                  break;
                case 'miss':
                  bg = C.bg3;
                  fg = C.txl;
                  break;
                case 'event':
                  bg = C.yellowMid;
                  fg = C.yellowDeep;
                  break;
                case 'today':
                  bg = C.ink;
                  fg = Colors.white;
                  break;
                default:
                  bg = C.bg3;
                  fg = const Color(0xFFCCCCCC);
                  break;
              }
              return GestureDetector(
                onTap: type != 'future'
                    ? () => setState(
                          () => _selectedDay = DateTime(
                            _focusedMonth.year,
                            _focusedMonth.month,
                            day,
                          ),
                        )
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: isSel && type != 'today' ? C.yellow : bg,
                    borderRadius: BorderRadius.circular(10),
                    border: isSel && type != 'today'
                        ? Border.all(color: C.yellowDark, width: 2)
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$day',
                            style: poppins(
                              11,
                              w: FontWeight.w700,
                              c: isSel && type != 'today' ? C.ink : fg,
                            ),
                          ),
                          if (moodEmoji.isNotEmpty)
                            Text(
                              moodEmoji,
                              style: const TextStyle(fontSize: 11, height: 1),
                            ),
                        ],
                      ),
                      if (type == 'checkin')
                        Positioned(
                          bottom: 2,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: C.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      if (type == 'event')
                        Positioned(
                          bottom: 2,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: C.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _leg(C.green, 'Check-in'),
              const SizedBox(width: 12),
              _leg(C.orange, 'Event'),
              const SizedBox(width: 12),
              _leg(C.txl.withOpacity(0.4), 'Missed'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _leg(Color c, String t) => Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            t,
            style: poppins(10, w: FontWeight.w600, c: C.txl),
          ),
        ],
      );

  String _moodEmojiForDay(int day) {
    final target = DateTime(_focusedMonth.year, _focusedMonth.month, day);
    Map<String, dynamic>? match;
    for (final item in _monthData) {
      if (item is! Map) continue;
      final parsed = _tryParseDate(
        (item['date'] ?? item['activity_date'] ?? item['created_at'] ?? '')
            .toString(),
      );
      if (parsed == null) continue;
      if (parsed.year == target.year &&
          parsed.month == target.month &&
          parsed.day == target.day) {
        match = Map<String, dynamic>.from(item);
        break;
      }
    }
    if (match == null &&
        target.year == DateTime.now().year &&
        target.month == DateTime.now().month &&
        target.day == DateTime.now().day) {
      match = _todayActivity;
    }
    final raw = _field(match, ['mood_emoji', 'emoji', 'mood_icon', 'icon']);
    if (raw.isNotEmpty && raw.length <= 4) return raw;
    final mood = _field(match, ['mood', 'mood_name', 'feeling']).toLowerCase();
    if (mood.contains('sad')) return '😔';
    if (mood.contains('love')) return '🥰';
    if (mood.contains('angry')) return '😤';
    if (mood.contains('fear')) return '😨';
    if (mood.contains('confus')) return '😕';
    if (mood.contains('excited')) return '🤩';
    if (mood.contains('happy')) return '😊';
    return '';
  }

  String _detailLabel() {
    final t = _dayType(_selectedDay.day);
    final d = _selectedDay.day;
    final m = _monthShort(_selectedDay);
    if (t == 'checkin') return '$m $d · Check-in entry';
    if (t == 'event') return '$m $d · Events & reminders';
    if (t == 'miss') return '$m $d · Missed';
    if (t == 'today') return 'Today · $m $d';
    return 'Reminders & Events';
  }

  Widget _detailCard() {
    final t = _dayType(_selectedDay.day);
    final d = _selectedDay.day;
    final m = _monthShort(_selectedDay);
    void close() => setState(() => _selectedDay = DateTime.now());
    final dayReminders = _remindersForSelectedDay();
    final checkIn = _checkInForSelectedDay();

    switch (t) {
      case 'checkin':
        final mood = _field(checkIn, ['mood', 'mood_name', 'feeling']);
        final weather = _field(checkIn, ['weather', 'weather_name']);
        final activity =
            _field(checkIn, ['activity', 'activities', 'activity_name']);
        final notes = _field(checkIn, ['notes', 'note', 'description']);
        final summary = _checkInSummary(checkIn);
        final rows = _checkInRows(checkIn);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF1FFF6), Color(0xFFFFFFFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: C.green, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0B000000),
                blurRadius: 14,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: C.greenLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: C.green, size: 25),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$m $d · Daily check-in saved',
                            style: poppins(14, w: FontWeight.w800, c: C.ink)),
                        const SizedBox(height: 3),
                        Text(
                          summary.isNotEmpty
                              ? 'Your day felt like $summary'
                              : 'Your check-in has been recorded',
                          style: poppins(12, c: C.txm, h: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (rows.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: rows
                      .where((row) => row.key != 'Notes')
                      .map(
                          (row) => _p('${row.key}: ${row.value}', C.bg2, C.txm))
                      .toList(),
                ),
              ],
              if (mood.isNotEmpty || weather.isNotEmpty || activity.isNotEmpty)
                const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (mood.isNotEmpty)
                    _p('Mood: $mood', C.yellowMid, C.yellowDeep),
                  if (weather.isNotEmpty)
                    _p('Weather: $weather', C.greenLight, C.green),
                  if (activity.isNotEmpty)
                    _p('Activity: $activity', C.blueLight,
                        const Color(0xFF0D47A1)),
                ],
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: C.white.withOpacity(.72),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: C.bd),
                  ),
                  child: Text(
                    notes,
                    style: poppins(12, c: C.txm, h: 1.6),
                  ),
                ),
              ],
              if (mood.isEmpty &&
                  weather.isEmpty &&
                  activity.isEmpty &&
                  notes.isEmpty)
                Text('Check-in submitted for this date',
                    style: poppins(12, c: C.txl)),
            ],
          ),
        );
      case 'event':
        return _card(
          borderColor: C.orange,
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    '$m $d · Events',
                    style: poppins(14, w: FontWeight.w700, c: C.ink),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: close,
                    child: const Icon(Icons.close, size: 16, color: C.txl),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (dayReminders.isEmpty)
                Text(
                  'No reminders returned for this date',
                  style: poppins(12, c: C.txl),
                )
              else
                ...dayReminders.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: C.blueLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.notifications_active_outlined,
                            size: 20,
                            color: C.blue,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r['title']?.toString() ?? 'Reminder',
                                style: poppins(
                                  13,
                                  w: FontWeight.w700,
                                  c: C.ink,
                                ),
                              ),
                              Text(
                                '${r['type'] ?? 'Reminder'} · ${r['time'] ?? ''}',
                                style: poppins(11, c: C.txl),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      case 'miss':
        return _card(
          dashed: true,
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: close,
                  child: const Icon(Icons.close, size: 16, color: C.txl),
                ),
              ),
              const Text('📭', style: TextStyle(fontSize: 30)),
              const SizedBox(height: 8),
              Text(
                'No check-in on $m $d',
                style: poppins(13, w: FontWeight.w700, c: C.ink),
              ),
              const SizedBox(height: 4),
              Text(
                "You didn't submit your daily check-in this day",
                style: poppins(12, c: C.txl),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      case 'today':
        return _card(
          child: Column(
            children: [
              Text(
                "Today · $m $d",
                style: poppins(13, w: FontWeight.w700, c: C.ink),
              ),
              const SizedBox(height: 6),
              Text(
                "You haven't submitted today's check-in yet",
                style: poppins(12, c: C.txl),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _openCheckIn,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: C.yellow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Do check-in now →',
                    style: poppins(13, w: FontWeight.w700, c: C.ink),
                  ),
                ),
              ),
            ],
          ),
        );
      default:
        // Default: reminders list
        return _card(
          child: Column(
            children: [
              if (dayReminders.isEmpty)
                Text('No reminders for this date', style: poppins(12, c: C.txl))
              else
                ...dayReminders.asMap().entries.map(
                      (e) => Column(
                        children: [
                          _remindRow(
                            Icons.notifications_active_outlined,
                            C.yellowLight,
                            C.yellowDark,
                            e.value['title']?.toString() ?? 'Reminder',
                            '${e.value['time'] ?? ''}',
                            e.value['type']?.toString() ?? 'Reminder',
                            C.yellowMid,
                            C.yellowDeep,
                          ),
                          if (e.key != dayReminders.length - 1)
                            const Divider(height: 1),
                        ],
                      ),
                    ),
            ],
          ),
        );
    }
  }

  Map<String, dynamic>? _nextReminderForToday() {
    final reminders = _remindersForDay(DateTime.now())
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList(growable: false);
    if (reminders.isEmpty) return null;
    reminders.sort((a, b) {
      final at = _minutesOfDay(a['time']?.toString() ?? '');
      final bt = _minutesOfDay(b['time']?.toString() ?? '');
      return at.compareTo(bt);
    });
    final now = TimeOfDay.now();
    final current = now.hour * 60 + now.minute;
    for (final reminder in reminders) {
      if (_minutesOfDay(reminder['time']?.toString() ?? '') >= current) {
        return reminder;
      }
    }
    return reminders.first;
  }

  int _activeDaysInFocusedMonth() {
    final days = <int>{};
    for (final item in _monthData) {
      if (item is! Map) continue;
      final parsed = _tryParseDate(
        (item['date'] ?? item['activity_date'] ?? item['created_at'] ?? '')
            .toString(),
      );
      if (parsed == null ||
          parsed.year != _focusedMonth.year ||
          parsed.month != _focusedMonth.month) {
        continue;
      }
      if (_truthy(item['has_checkin']) ||
          _truthy(item['is_completed']) ||
          _truthy(item['submitted']) ||
          item['mood'] != null) {
        days.add(parsed.day);
      }
    }
    final now = DateTime.now();
    if (_checkInDone &&
        now.year == _focusedMonth.year &&
        now.month == _focusedMonth.month) {
      days.add(now.day);
    }
    return days.length;
  }

  int _minutesOfDay(String raw) {
    final clean = raw.trim().toLowerCase();
    if (clean.isEmpty) return 24 * 60;
    final amPm = clean.contains('pm')
        ? 'pm'
        : clean.contains('am')
            ? 'am'
            : '';
    final digits = clean.replaceAll(RegExp(r'[^0-9:]'), '');
    final parts = digits.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 24;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    var h = hour;
    if (amPm == 'pm' && h < 12) h += 12;
    if (amPm == 'am' && h == 12) h = 0;
    return h * 60 + minute;
  }

  String _monthTitle(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _monthShort(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[date.month - 1];
  }

  List _remindersForSelectedDay() {
    return _remindersForDay(_selectedDay);
  }

  List _remindersForDay(DateTime day) {
    final dated = _reminders.where((item) {
      final raw =
          (item['date'] ?? item['event_date'] ?? item['reminder_date'] ?? '')
              .toString();
      final repeat = _truthy(item['repeat']) ||
          _truthy(item['is_repeat']) ||
          _truthy(item['is_recurring']);
      if (raw.isEmpty) return repeat;
      final parsed = _tryParseDate(raw);
      if (parsed == null) return repeat;
      return parsed.year == day.year &&
          parsed.month == day.month &&
          parsed.day == day.day;
    }).toList();

    final daily = _dailyAlarmReminders();
    return [...dated, ...daily];
  }

  List<Map<String, dynamic>> _dailyAlarmReminders() {
    final d = _medicalRecord;
    if (d == null) return [];
    final items = <Map<String, dynamic>>[];
    void add(String key, String label, String type) {
      final value = d[key];
      if (value == null || value.toString().trim().isEmpty) return;
      items.add({
        'title': label,
        'time': value.toString(),
        'type': type,
        'repeat': 1
      });
    }

    if (_truthy(d['medical_alarm'])) {
      add('morning_before_food', 'Morning medicine before food', 'Medical');
      add('morning_after_food', 'Morning medicine after food', 'Medical');
      add('afternoon_before_food', 'Afternoon medicine before food', 'Medical');
      add('afternoon_after_food', 'Afternoon medicine after food', 'Medical');
      add('night_before_food', 'Night medicine before food', 'Medical');
      add('night_after_food', 'Night medicine after food', 'Medical');
    }
    if (_truthy(d['food_alarm'])) {
      add('breakfast_time', 'Breakfast reminder', 'Food');
      add('lunch_time', 'Lunch reminder', 'Food');
      add('dinner_time', 'Dinner reminder', 'Food');
    }
    return items;
  }

  Map<String, dynamic>? _checkInForSelectedDay() {
    final now = DateTime.now();
    if (_selectedDay.year == now.year &&
        _selectedDay.month == now.month &&
        _selectedDay.day == now.day &&
        _todayActivity != null &&
        _todayActivity!.isNotEmpty) {
      return _todayActivity;
    }
    for (final item in _monthData) {
      if (item is! Map) continue;
      final parsed = _tryParseDate(
        (item['date'] ?? item['activity_date'] ?? item['created_at'] ?? '')
            .toString(),
      );
      if (parsed == null) continue;
      if (parsed.year == _selectedDay.year &&
          parsed.month == _selectedDay.month &&
          parsed.day == _selectedDay.day) {
        return Map<String, dynamic>.from(item);
      }
    }
    return null;
  }

  List<MapEntry<String, String>> _checkInRows(Map<String, dynamic>? item) {
    final rows = <MapEntry<String, String>>[];
    void add(String label, List<String> keys) {
      final value = _field(item, keys);
      if (value.isNotEmpty &&
          !rows.any((row) => row.value.toLowerCase() == value.toLowerCase())) {
        rows.add(MapEntry(label, value));
      }
    }

    add('Mood', ['mood', 'mood_name', 'feeling']);
    add('People', ['people', 'persons', 'met_people', 'people_met']);
    add('Places', ['places', 'place', 'locations']);
    add('Activity', ['activity', 'activities', 'activity_name']);
    add('Weather', ['weather', 'weather_name']);
    add('Sleep', ['sleep', 'sleep_time', 'sleeping']);
    add('Notes', ['notes', 'note', 'description']);
    return rows;
  }

  String _checkInSummary(Map<String, dynamic>? item) {
    final explicit = _field(item, ['summary', 'one_word', 'word']);
    final mood = _field(item, ['mood', 'mood_name', 'feeling']);
    final activity = _field(item, ['activity', 'activities', 'activity_name']);
    final weather = _field(item, ['weather', 'weather_name']);
    for (final value in [explicit, mood, activity, weather]) {
      final clean = value.trim();
      if (clean.isNotEmpty)
        return clean.split(',').first.trim().split(' ').first;
    }
    return '';
  }

  String _field(Map<String, dynamic>? item, List<String> keys) {
    if (item == null) return '';
    for (final key in keys) {
      final value = item[key];
      if (value == null) continue;
      if (value is List) {
        final text = value
            .map((e) => e is Map
                ? (e['name'] ?? e['label'] ?? e['title'] ?? e['value'])
                : e)
            .where((e) => e != null && e.toString().trim().isNotEmpty)
            .join(', ');
        if (text.isNotEmpty) return text;
      } else if (value is Map) {
        final text =
            value['name'] ?? value['label'] ?? value['title'] ?? value['value'];
        if (text != null && text.toString().trim().isNotEmpty)
          return text.toString();
      } else if (value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }

  DateTime _parseDate(dynamic raw) =>
      _tryParseDate(raw.toString()) ?? DateTime(1900);

  DateTime? _tryParseDate(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      final dateOnly = raw.split(' ').first.split('T').first;
      final parts = dateOnly.split('-');
      if (parts.length == 3) {
        final first = int.tryParse(parts[0]);
        final second = int.tryParse(parts[1]);
        final third = int.tryParse(parts[2]);
        if (first != null && second != null && third != null) {
          if (parts[0].length == 4) return DateTime(first, second, third);
          return DateTime(third, second, first);
        }
      }
    }
    return null;
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _truthy(dynamic value) {
    if (value == true) return true;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase().trim();
    return text == '1' || text == 'true' || text == 'yes' || text == 'active';
  }

  Widget _card({Widget? child, Color? borderColor, bool dashed = false}) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.circular(20),
          border: dashed
              ? Border.all(color: C.bd2, style: BorderStyle.solid)
              : Border.all(color: borderColor ?? C.bd),
        ),
        child: child,
      );

  Widget _remindRow(
    IconData icon,
    Color bg,
    Color fg,
    String label,
    String sub,
    String tag,
    Color tagBg,
    Color tagFg,
  ) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: fg.withOpacity(0.3)),
              ),
              child: Icon(icon, size: 18, color: fg),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: poppins(13, w: FontWeight.w700, c: C.ink),
                  ),
                  Text(sub, style: poppins(11, c: C.txl)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tagBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                tag,
                style: poppins(10, w: FontWeight.w700, c: tagFg),
              ),
            ),
          ],
        ),
      );

  Widget _p(String l, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          l,
          style: poppins(11, w: FontWeight.w700, c: fg),
        ),
      );
}
