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
  bool _loadError = false;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  // Independent from _focusedMonth (which still drives reminder-count
  // stats and monthly data fetches) — this only drives the weekly
  // strip's own navigation. Always the Sunday starting the visible week.
  DateTime _focusedWeekStart = DateTime.now().subtract(
    Duration(days: DateTime.now().weekday % 7),
  );

  // API data
  List _monthData = []; // from /daily/activity/month
  List _homeActivities = []; // from /activities/home
  List _reminders = []; // from /user/reminder/list
  Map<String, dynamic>? _medicalRecord;
  Map<String, dynamic>? _todayActivity;
  int _notificationCount = 0;
  int _todayPollCount = 0;
  int _todayActivityCount = 0;
  List _pollDays = [];
  List _activityDays = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    // Bug 4 Fix: Load critical data first, then secondary data
    setState(() => _loadError = false);
    try {
    // Phase 1 — critical (today + monthly calendar)
    final critical = await Future.wait([
      _actSvc.getTodayActivity(),       // today check-in state
      _actSvc.getMonthlyActivities(     // calendar dots
        month: _focusedMonth.month,
        year: _focusedMonth.year,
      ),
    ]).timeout(const Duration(seconds: 8), onTimeout: () => [null, null]);
    if (!mounted) return;
    setState(() {
      _checkInDone   = _hasData(critical[0]);
      _todayActivity = _extractMap(critical[0]);
      _monthData     = _extractList(critical[1]);
    });

    // Phase 2 — secondary (home activities, reminders, notifications, alarms)
    // Load in background — UI already showing from Phase 1
    final secondary = await Future.wait([
      _actSvc.getHomeActivities(),        // home activity cards
      AlarmService().listReminders(),     // reminder list
      AlarmService().getMedicalRecords(), // alarm status
      NotificationService().getNotifications(), // notification badge
    ]).timeout(const Duration(seconds: 10), onTimeout: () => [null, null, null, null]);
    if (!mounted) return;
    setState(() {
      _homeActivities    = _extractList(secondary[0]);
      _reminders         = _extractList(secondary[1]);
      _medicalRecord     = _extractMap(secondary[2]);
      _notificationCount = _extractNotificationCount(secondary[3]);
    });
    } catch (_) {
      if (mounted) setState(() => _loadError = true);
    }

    // Phase 3 — Today at a Glance counts. Deliberately outside the
    // try/catch above so a failure here never marks the whole Home
    // load as failed — this is a nice-to-have strip, not critical.
    try {
      final commSvc = CommunityService();
      final glance = await Future.wait([
        commSvc.getPollCalendar(),
        commSvc.getActivityCalendar(),
      ]).timeout(const Duration(seconds: 8), onTimeout: () => [null, null]);
      if (!mounted) return;
      final pollDays = _extractList(glance[0]);
      final activityDays = _extractList(glance[1]);
      // Counts everything scheduled for today, including items still
      // locked-but-later-today (unlocks_today: true) — the "Later
      // Today" section in the actual tabs. Only counting the
      // currently-unlocked "today" status would undercount whenever
      // admin schedules more than one activity/poll for the same day.
      bool isToday(dynamic d) =>
          d is Map &&
          (d['status'] == 'today' ||
              (d['status'] == 'locked' && d['unlocks_today'] == true));
      setState(() {
        _todayPollCount = pollDays.where(isToday).length;
        _todayActivityCount = activityDays.where(isToday).length;
        _pollDays = pollDays;
        _activityDays = activityDays;
      });
    } catch (_) {
      // Silently leave counts at 0 — strip just won't show.
    }
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

  // Check-in only opens from 8pm onward — before that, tapping any
  // of the entry points shows a friendly message instead.
  bool get _isCheckInWindowOpen => DateTime.now().hour >= 20;

  Future<void> _openCheckIn() async {
    if (!_isCheckInWindowOpen) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Daily check-in opens at 8:00 PM',
            style: poppins(12, c: C.white)),
        backgroundColor: C.ink,
      ));
      return;
    }
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
  String _dayType(DateTime cellDate) {
    for (final d in _monthData) {
      try {
        final date = _parseDate(
            d['date'] ?? d['activity_date'] ?? d['created_at'] ?? '');
        if (date.year == cellDate.year &&
            date.month == cellDate.month &&
            date.day == cellDate.day) {
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
        cellDate.day == now.day) {
      return _checkInDone ? 'checkin' : 'today';
    }
    return 'miss';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: C.bgGradient),
        child: RefreshIndicator(
        onRefresh: _loadAll,
        color: C.yellowDark,
        child: CustomScrollView(
          slivers: [
            // Header with photo background
            SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(color: C.yellow),
                    ),
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/home_header_photo.jpg',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                    ),
                    // Fades the photo into the page's own background
                    // gradient below, so the transition feels smooth
                    // rather than a hard cut.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.75, 1.0],
                            colors: [
                              Colors.transparent,
                              C.yellow.withOpacity(.25),
                              const Color(0xFFFFF3D0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Greeting and icons — explicitly positioned at a
                    // fixed top offset, sitting in the photo's own
                    // clear upper area (above the people, who sit
                    // lower in the frame) rather than relying on a
                    // Row's automatic layout, which caused alignment
                    // bugs in earlier attempts.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_timeBasedGreeting()} 👋',
                                      style: poppins(
                                        13,
                                        w: FontWeight.w600,
                                        c: C.ink,
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
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: C.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.notifications_outlined,
                                        size: 22,
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
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => Navigator.pushNamed(
                                    context, AppRoutes.profile),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: C.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person_rounded,
                                    size: 18,
                                    color: C.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _todayWellbeingCard(auth.userName),
                  if (_todayPollCount > 0 || _todayActivityCount > 0) ...[
                    const SizedBox(height: 12),
                    _todayAtGlanceStrip(),
                  ],
                  const SizedBox(height: 14),
                  _weekStrip(),
                  const SizedBox(height: 12),
                  _secLabel(Icons.timeline_rounded, _detailLabel()),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.06),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                        child: child,
                      ),
                    ),
                    child: Container(
                      key: ValueKey(_fmtDateKey(_selectedDay)),
                      child: _detailCard(),
                    ),
                  ),
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
        ? (_moodEmojiForDay(DateTime.now()).isNotEmpty
            ? _moodEmojiForDay(DateTime.now())
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
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: C.ink.withOpacity(.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFDD66), C.yellow],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: C.yellow.withOpacity(.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: heroEmoji == '✓'
                  ? const Icon(Icons.check_rounded, color: C.ink, size: 25)
                  : Text(heroEmoji, style: const TextStyle(fontSize: 23)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Today’s wellbeing',
                  style: poppins(10, w: FontWeight.w800, c: C.yellowDeep)),
              const SizedBox(height: 2),
              Text(title,
                  style: poppins(15,
                      w: FontWeight.w900, c: C.ink, h: 1.2)),
              const SizedBox(height: 2),
              Text(subtitle, style: poppins(10.5, c: C.txm, h: 1.3)),
            ]),
          ),
        ]),
        const SizedBox(height: 11),
        Row(children: [
          _todayMetric(
            nextReminder == null
                ? '--'
                : (nextReminder['time'] ?? '--').toString(),
            'Next alarm',
          ),
          const SizedBox(width: 7),
          _todayMetric('$todayCount', 'Alarms today'),
          const SizedBox(width: 7),
          _todayMetric('$activeDays', 'Alarm days'),
        ]),
        // Show all submitted check-in data as chips
        if (_checkInDone && _todayActivity != null) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            ..._buildCheckInChips(_todayActivity!),
          ]),
          const SizedBox(height: 9),
        ],
        if (!_checkInDone) ...[
          const SizedBox(height: 11),
          GestureDetector(
            onTap: _openCheckIn,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                gradient: _isCheckInWindowOpen
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFFDD66), C.yellow],
                      )
                    : null,
                color: _isCheckInWindowOpen ? null : C.bg2,
                borderRadius: BorderRadius.circular(14),
                boxShadow: _isCheckInWindowOpen
                    ? [
                        BoxShadow(
                          color: C.yellow.withOpacity(.35),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: _isCheckInWindowOpen
                    ? Text('Start daily check-in →',
                        style: poppins(12.5, w: FontWeight.w900, c: C.ink))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.lock_clock_rounded, size: 15, color: C.txm),
                        const SizedBox(width: 6),
                        Text('Check-in opens at 8:00 PM',
                            style: poppins(12.5, w: FontWeight.w700, c: C.txm)),
                      ]),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _todayMetric(String value, String label) => Expanded(
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFFBFAF5),
            borderRadius: BorderRadius.circular(14),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: poppins(13, w: FontWeight.w900, c: C.ink)),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: poppins(8, w: FontWeight.w700, c: C.txm)),
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

  // ── Today at a Glance — quick shortcut into today's Poll/Activity,
  // shown only when there's actually something today (see the
  // (_todayPollCount > 0 || _todayActivityCount > 0) check at the
  // call site) so it never sits there empty.
  Widget _todayAtGlanceStrip() => Row(children: [
        if (_todayActivityCount > 0)
          Expanded(
            child: _glancePill(
              Icons.event_available_rounded,
              _todayActivityCount == 1
                  ? '1 Activity today'
                  : '$_todayActivityCount Activities today',
              C.yellowLight,
              C.yellowDeep,
              () => _openSpikeTab(3), // Activities sub-tab
            ),
          ),
        if (_todayActivityCount > 0 && _todayPollCount > 0)
          const SizedBox(width: 10),
        if (_todayPollCount > 0)
          Expanded(
            child: _glancePill(
              Icons.how_to_vote_rounded,
              _todayPollCount == 1 ? '1 Poll today' : '$_todayPollCount Polls today',
              const Color(0xFFE8F0FE),
              const Color(0xFF1D4ED8),
              () => _openSpikeTab(2), // Polls sub-tab
            ),
          ),
      ]);

  Widget _glancePill(IconData icon, String label, Color bg, Color fg,
          VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: C.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: C.ink.withOpacity(.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(fg, Colors.white, 0.75)!,
                    Color.lerp(fg, Colors.white, 0.4)!,
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: fg),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: poppins(13, w: FontWeight.w800, c: fg, h: 1.2)),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: fg),
          ]),
        ),
      );

  // Deep-links into Spike's Polls (2) or Activities (3) sub-tab,
  // matching the same navigation pattern already used for
  // notification-tap routing elsewhere in the app.
  void _openSpikeTab(int communityTab) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.home,
      (route) => false,
      arguments: {'tab': 2, 'communityTab': communityTab},
    );
  }

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
  Widget _weekStrip() {
    const weekdays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
    final weekStart = _focusedWeekStart;
    final weekEnd = weekStart.add(const Duration(days: 6));
    final now = DateTime.now();
    final currentWeekStart = now.subtract(Duration(days: now.weekday % 7));
    final _isCurrentWeek = _dateOnly(weekStart) == _dateOnly(currentWeekStart);
    final rangeLabel = weekStart.month == weekEnd.month
        ? '${_monthShort(weekStart)} ${weekStart.day} - ${weekEnd.day}'
        : '${_monthShort(weekStart)} ${weekStart.day} - ${_monthShort(weekEnd)} ${weekEnd.day}';

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -200) {
          // Swiped left → next week
          setState(() => _focusedWeekStart = weekStart.add(const Duration(days: 7)));
        } else if (velocity > 200) {
          // Swiped right → previous week
          setState(() => _focusedWeekStart = weekStart.subtract(const Duration(days: 7)));
        }
      },
      child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: C.ink.withOpacity(.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 56,
                child: !_isCurrentWeek
                    ? GestureDetector(
                        onTap: () => setState(() => _focusedWeekStart =
                            now.subtract(Duration(days: now.weekday % 7))),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: C.yellowLight,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('Today',
                              style: poppins(10.5, w: FontWeight.w800, c: C.yellowDeep)),
                        ),
                      )
                    : null,
              ),
              Row(children: [
                GestureDetector(
                  onTap: () => setState(() =>
                      _focusedWeekStart = weekStart.subtract(const Duration(days: 7))),
                  child: const Icon(Icons.chevron_left_rounded, size: 18, color: C.txl),
                ),
                const SizedBox(width: 6),
                Text(rangeLabel, style: poppins(13, w: FontWeight.w700, c: C.ink)),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => setState(() =>
                      _focusedWeekStart = weekStart.add(const Duration(days: 7))),
                  child: const Icon(Icons.chevron_right_rounded, size: 18, color: C.txl),
                ),
              ]),
              const SizedBox(width: 56),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(7, (i) {
              final cellDate = weekStart.add(Duration(days: i));
              final type = _dayType(cellDate);
              final isSel = _dateOnly(_selectedDay) == _dateOnly(cellDate);
              final moodEmoji = type == 'checkin' ? _moodEmojiForDay(cellDate) : '';
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
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i != 6 ? 4 : 0),
                  child: GestureDetector(
                    onTap: type != 'future'
                        ? () => setState(() => _selectedDay = cellDate)
                        : null,
                    child: Container(
                      height: 62,
                      decoration: BoxDecoration(
                        gradient: type == 'today'
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF2A2438), C.ink],
                              )
                            : isSel
                                ? const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFFFFDD66), C.yellow],
                                  )
                                : null,
                        color: (isSel || type == 'today') ? null : bg,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: type == 'today'
                            ? [
                                BoxShadow(
                                  color: C.ink.withOpacity(.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : isSel
                                ? [
                                    BoxShadow(
                                      color: C.yellow.withOpacity(.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(weekdays[i],
                              style: poppins(9, w: FontWeight.w700,
                                  c: type == 'today'
                                      ? Colors.white70
                                      : isSel ? C.ink.withOpacity(.7) : fg.withOpacity(.7))),
                          const SizedBox(height: 2),
                          Text('${cellDate.day}',
                              style: poppins(13, w: FontWeight.w800,
                                  c: type == 'today'
                                      ? Colors.white
                                      : isSel ? C.ink : fg)),
                          const SizedBox(height: 2),
                          moodEmoji.isNotEmpty
                              ? Text(moodEmoji, style: const TextStyle(fontSize: 12, height: 1))
                              : SizedBox(
                                  width: 5, height: 5,
                                  child: type == 'event'
                                      ? const DecoratedBox(
                                          decoration: BoxDecoration(
                                              color: C.orange, shape: BoxShape.circle))
                                      : null,
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
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

  String _moodEmojiForDay(DateTime target) {
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
    final t = _dayType(_selectedDay);
    final d = _selectedDay.day;
    final m = _monthShort(_selectedDay);
    if (t == 'checkin') return '$m $d · Check-in entry';
    if (t == 'event') return '$m $d · Events & reminders';
    if (t == 'miss') return '$m $d · Missed';
    if (t == 'today') return 'Today · $m $d';
    return 'Reminders & Events';
  }

  Widget _detailCard() {
    final t = _dayType(_selectedDay);
    final d = _selectedDay.day;
    final m = _monthShort(_selectedDay);
    void close() => setState(() => _selectedDay = DateTime.now());
    final dayReminders = _remindersForSelectedDay();
    final checkIn = _checkInForSelectedDay();

    switch (t) {
      case 'checkin':
        final notes = _field(checkIn, ['notes', 'note', 'description']);
        final summary = _buildFullDaySummary(checkIn);
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
                              ? summary
                              : 'Your check-in has been recorded',
                          style: poppins(12, c: C.txm, h: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              _activityPollStatusSection(_selectedDay),
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
              if (rows.isEmpty && notes.isEmpty)
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
              _activityPollStatusSection(_selectedDay),
            ],
          ),
        );
      case 'today':
        return _card(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: C.yellowLight,
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/home_header_photo.jpg',
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today · $m $d",
                      style: poppins(14, w: FontWeight.w700, c: C.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "You haven't submitted today's check-in yet",
                      style: poppins(12, c: C.txl),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _openCheckIn,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
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

  String _timeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
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
    add('Places', ['places', 'place', 'locations', 'places_visited']);
    add('Activity', ['activity', 'activities', 'activity_name', 'activities_done']);
    add('Weather', ['weather', 'weather_name']);
    add('Sleep', ['sleep', 'sleep_time', 'sleeping']);
    add('Notes', ['notes', 'note', 'description']);
    return rows;
  }


  List<Widget> _buildCheckInChips(Map<String, dynamic> data) {
    final chips = <Widget>[];
    final fields = [
      {'keys': ['mood', 'mood_name', 'feeling'], 'icon': '😊', 'label': 'Mood'},
      {'keys': ['weather', 'weather_type'], 'icon': '🌤️', 'label': 'Weather'},
      {'keys': ['sleep_time', 'sleep', 'sleeping_time'], 'icon': '😴', 'label': 'Sleep'},
      {'keys': ['energy', 'energy_level'], 'icon': '⚡', 'label': 'Energy'},
      {'keys': ['exercise', 'activity_name'], 'icon': '💪', 'label': 'Exercise'},
      {'keys': ['water', 'water_intake'], 'icon': '💧', 'label': 'Water'},
      {'keys': ['pain', 'pain_level'], 'icon': '🩺', 'label': 'Pain'},
      {'keys': ['notes', 'note', 'description'], 'icon': '📝', 'label': 'Note'},
    ];
    for (final f in fields) {
      final val = _field(data, List<String>.from(f['keys'] as List));
      if (val.isEmpty) continue;
      chips.add(_checkInChip('${f['icon']} ${f['label']}: $val'));
    }
    return chips;
  }

  Widget _checkInChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: C.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: C.yellowBorder),
    ),
    child: Text(label,
        style: poppins(11, w: FontWeight.w600, c: C.txm)),
  );

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

  String _fmtDateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<Map> _activitiesOnDay(DateTime day) {
    final key = _fmtDateKey(day);
    return _activityDays
        .where((d) => d is Map && d['date']?.toString() == key)
        .cast<Map>()
        .toList();
  }

  List<Map> _pollsOnDay(DateTime day) {
    final key = _fmtDateKey(day);
    return _pollDays
        .where((d) => d is Map && d['date']?.toString() == key)
        .cast<Map>()
        .toList();
  }

  // "a, b and c" — natural comma+and joining for any list length.
  String _joinNatural(List<String> items) {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.first;
    if (items.length == 2) return '${items[0]} and ${items[1]}';
    return '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
  }

  // Richer multi-field summary (mood + people + places + activities
  // + weather + sleep), mirroring the composer built for the
  // check-in submission success screen — reused here so a past
  // day's detail reads the same way.
  String _buildFullDaySummary(Map<String, dynamic>? checkIn) {
    if (checkIn == null) return '';
    final mood = _field(checkIn, ['mood', 'mood_name', 'feeling']);
    final peopleRaw = checkIn['people_met'] ?? checkIn['people'];
    final placesRaw = checkIn['places_visited'] ?? checkIn['places'];
    final actsRaw = checkIn['activities_done'] ?? checkIn['activities'];
    final weather = _field(checkIn, ['weather', 'weather_name']);
    final sleep = _field(checkIn, ['sleep_time', 'sleep']);

    List<String> asList(dynamic raw) {
      if (raw is List) return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
      return [];
    }
    final people = asList(peopleRaw);
    final places = asList(placesRaw);
    final acts = asList(actsRaw);

    final parts = <String>[];
    if (mood.isNotEmpty) parts.add('felt $mood');
    if (people.isNotEmpty) parts.add('met ${_joinNatural(people)}');
    if (places.isNotEmpty) parts.add('visited ${_joinNatural(places)}');
    if (acts.isNotEmpty) parts.add('did ${_joinNatural(acts)}');
    String firstSentence = parts.isNotEmpty ? 'That day you ${_joinNatural(parts)}.' : '';

    final secondParts = <String>[];
    if (weather.isNotEmpty) secondParts.add('it was $weather');
    if (sleep.isNotEmpty) secondParts.add('you slept $sleep');
    String secondSentence = '';
    if (secondParts.isNotEmpty) {
      final joined = _joinNatural(secondParts);
      secondSentence = '${joined[0].toUpperCase()}${joined.substring(1)}.';
    }

    return [firstSentence, secondSentence].where((s) => s.isNotEmpty).join(' ');
  }

  // Compact section showing Activities responded/missed and Polls
  // answered/missed for a specific past day — independent of
  // whether a daily check-in was submitted that day, since these
  // are separate systems.
  Widget _activityPollStatusSection(DateTime day) {
    final activities = _activitiesOnDay(day);
    final polls = _pollsOnDay(day);
    if (activities.isEmpty && polls.isEmpty) return const SizedBox.shrink();

    final activitiesResponded = activities.where((a) => a['status'] == 'completed').length;
    final activitiesMissed = activities.where((a) => a['status'] == 'missed').length;
    final pollsAnswered = polls.where((p) {
      final poll = p['poll'];
      return p['status'] == 'past' && poll is Map && poll['has_voted'] == true;
    }).length;
    final pollsMissed = polls.where((p) {
      final poll = p['poll'];
      return p['status'] == 'past' && (poll is! Map || poll['has_voted'] != true);
    }).length;

    if (activitiesResponded == 0 && activitiesMissed == 0 && pollsAnswered == 0 && pollsMissed == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(spacing: 6, runSpacing: 6, children: [
        if (activitiesResponded > 0)
          _p('✅ $activitiesResponded activity replied', C.greenLight, const Color(0xFF145C30)),
        if (activitiesMissed > 0)
          _p('⚪ $activitiesMissed activity missed', C.bg2, C.txm),
        if (pollsAnswered > 0)
          _p('✅ $pollsAnswered poll answered', C.greenLight, const Color(0xFF145C30)),
        if (pollsMissed > 0)
          _p('⚪ $pollsMissed poll missed', C.bg2, C.txm),
      ]),
    );
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
