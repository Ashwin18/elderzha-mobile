import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/services.dart';
import '../../widgets/community_media.dart';
import 'activity_detail_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _svc = CommunityService();
  int _tab = 0;
  final _tabs = ['All', 'Feed', 'Polls', 'Activities'];
  final _types = ['all', 'feed', 'polls', 'activities'];
  List _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, _tabs.length - 1);
    _load();
  }

  // ── GET /user/feed/{type} ─────────────────────────────────
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res =
        _tab == 0 ? await _loadAllTabs() : await _svc.getFeed(_types[_tab]);
    if (!mounted) return;
    setState(() {
      _items = _extractItems(res);
      _error =
          res == null ? 'Unable to load ${_tabs[_tab].toLowerCase()}' : null;
      _loading = false;
    });
  }

  Future<Map<String, dynamic>?> _loadAllTabs() async {
    final results = await Future.wait([
      _svc.getFeed('all'),
      _svc.getFeed('feed'),
      _svc.getFeed('polls'),
      _svc.getFeed('activities'),
    ]);
    final merged = <Map<String, dynamic>>[];
    for (var i = 0; i < results.length; i++) {
      final sourceType = ['all', 'feed', 'polls', 'activities'][i];
      final oldTab = _tab;
      final list = _extractItemsFor(results[i], sourceType);
      _tab = oldTab;
      for (final raw in list) {
        if (raw is! Map || raw.isEmpty) continue;
        final item = Map<String, dynamic>.from(raw);
        item['type'] ??= sourceType == 'polls'
            ? 'poll'
            : sourceType == 'activities'
                ? 'activity'
                : 'feed';
        final key =
            '${_contentLabel(item)}-${_idOf(item)}-${item['title'] ?? item['question'] ?? item['description'] ?? item['created_at']}';
        if (!merged.any((existing) =>
            '${_contentLabel(existing)}-${_idOf(existing)}-${existing['title'] ?? existing['question'] ?? existing['description'] ?? existing['created_at']}' ==
            key)) {
          merged.add(item);
        }
      }
    }
    return {'data': merged};
  }

  List _extractItemsFor(Map<String, dynamic>? res, String type) {
    final previous = _tab;
    _tab = type == 'feed'
        ? 1
        : type == 'polls'
            ? 2
            : type == 'activities'
                ? 3
                : 0;
    final items = _extractItems(res);
    _tab = previous;
    return items;
  }

  List _extractItems(Map<String, dynamic>? res) {
    if (res == null) return [];
    final rootData = res['data'];
    if (_tab == 0 && rootData is Map) {
      final merged = <Map<String, dynamic>>[];
      final feed = rootData['feed'];
      if (feed is List) {
        merged.addAll(feed.map(_normalizeItem));
      }
      final activities = rootData['activities'];
      if (activities is List) {
        merged.addAll(activities.map(_normalizeItem));
      }
      final polls = rootData['polls'];
      if (polls is List) {
        merged.addAll(polls.map(_normalizeItem));
      }
      if (merged.isNotEmpty) return _filterForTab(merged);
    }
    final directKeys = [
      'data',
      'feeds',
      'feed',
      'posts',
      'polls',
      'activities',
      'today_activities',
      'community_posts',
      'activity',
      'items',
      'list',
    ];
    for (final key in directKeys) {
      final value = res[key];
      if (value is List)
        return _filterForTab(value.map(_normalizeItem).toList());
      if (value is Map) {
        for (final nestedKey in directKeys) {
          final nested = value[nestedKey];
          if (nested is List)
            return _filterForTab(nested.map(_normalizeItem).toList());
        }
      }
    }
    return [];
  }

  Map<String, dynamic> _normalizeItem(dynamic raw) {
    if (raw is! Map) return {};
    final item = Map<String, dynamic>.from(raw);
    final wrapperType = item['type']?.toString();
    for (final key in [
      'poll',
      'admin_post',
      'user_post',
      'post',
      'feed',
      'activity'
    ]) {
      final nested = item[key];
      if (nested is Map) {
        return {
          ...Map<String, dynamic>.from(nested),
          'type': wrapperType ?? key,
          if (item['created_at'] != null) 'created_at': item['created_at'],
        };
      }
    }
    return item;
  }

  List _filterForTab(List items) {
    if (_tab == 0) return items.where((p) => (p as Map).isNotEmpty).toList();
    return items.where((item) {
      final p = item as Map;
      if (p.isEmpty) return false;
      if (_tab == 1) return !_isPollItem(p) && !_isActivityItem(p);
      if (_tab == 2) return _isPollItem(p);
      return _isActivityItem(p);
    }).toList();
  }

  bool _isPollItem(Map p) {
    final tag = (p['type'] ?? p['post_type'] ?? p['tag'] ?? '')
        .toString()
        .toLowerCase();
    return tag.contains('poll') ||
        p['poll_id'] != null ||
        p['options'] is List ||
        p['answers'] is List;
  }

  bool _isActivityItem(Map p) {
    final tag = (p['type'] ?? p['post_type'] ?? p['tag'] ?? '')
        .toString()
        .toLowerCase();
    return tag.contains('activity') ||
        p['activity_id'] != null ||
        p['activity_title'] != null ||
        p['task_date'] != null;
  }

  String _contentLabel(Map p) {
    if (_isPollItem(p)) return 'Poll';
    if (_isActivityItem(p)) return 'Activity';
    return 'Feed';
  }

  Widget _mixLabel(String label) {
    final isActivity = label == 'Activity';
    final isPoll = label == 'Poll';
    final bg = isActivity
        ? C.greenLight
        : isPoll
            ? C.blueLight
            : C.yellowMid;
    final fg = isActivity
        ? C.green
        : isPoll
            ? const Color(0xFF0D47A1)
            : C.yellowDeep;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: poppins(10, w: FontWeight.w700, c: fg),
      ),
    );
  }

  int _idOf(Map p) =>
      int.tryParse(
          (p['activity_id'] ?? p['poll_id'] ?? p['id'] ?? p['post_id'] ?? 0)
              .toString()) ??
      0;

  String _cleanText(dynamic value) => value
      .toString()
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .trim();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(children: [
        // Yellow header with underline tabs
        Container(
          color: C.yellow,
          child: SafeArea(
              bottom: false,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                  child: Row(children: [
                    Expanded(
                        child: Text('Spike',
                            style: poppins(20, w: FontWeight.w700, c: C.ink))),
                  ]),
                ),
                // Underline tab bar
                Container(
                  decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                              color: Colors.black.withOpacity(0.1), width: 2))),
                  child: Row(
                      children: List.generate(4, (i) {
                    final sel = _tab == i;
                    return Expanded(
                        child: GestureDetector(
                      onTap: () {
                        setState(() => _tab = i);
                        _load();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(
                                    color: sel ? C.ink : Colors.transparent,
                                    width: 2))),
                        child: Center(
                            child: Text(_tabs[i],
                                style: poppins(12,
                                    w: FontWeight.w700,
                                    c: sel ? C.ink : C.txl))),
                      ),
                    ));
                  })),
                ),
              ])),
        ),
        // Body
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
                color: C.bg,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28))),
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: C.yellowDark))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: C.yellowDark,
                    child: _items.isEmpty
                        ? _emptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(14),
                            itemCount: _items.length,
                            itemBuilder: (_, i) => _postCard(_items[i]),
                          ),
                  ),
          ),
        ),
      ]),
    );
  }

  Widget _emptyState() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 90),
        Icon(
          _error == null ? Icons.forum_outlined : Icons.cloud_off_outlined,
          size: 42,
          color: C.txl,
        ),
        const SizedBox(height: 12),
        Text(
          _error ?? 'No ${_tabs[_tab].toLowerCase()} available yet',
          style: poppins(14, w: FontWeight.w700, c: C.ink),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          _error == null
              ? 'New admin updates will appear here automatically.'
              : 'Pull down to retry once the connection is available.',
          style: poppins(12, c: C.txl, h: 1.45),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _postCard(dynamic p) {
    if (p is! Map || p.isEmpty) return const SizedBox.shrink();
    final id = _idOf(p);
    final time = _displayTime(p);
    final text = _cleanText(p['text'] ??
        p['text_content'] ??
        p['description'] ??
        p['content'] ??
        p['notes'] ??
        p['question'] ??
        p['title'] ??
        p['activity_title'] ??
        '');
    final replies = int.tryParse((p['replies'] ??
                p['reply_count'] ??
                p['responses_count'] ??
                p['total_answered'] ??
                p['total_votes'] ??
                0)
            .toString()) ??
        0;
    final isPoll = p['isPoll'] as bool? ?? _isPollItem(p);
    final isActivity = _isActivityItem(p);
    final contentLabel = _contentLabel(p);
    if (isPoll) {
      final submitted = _pollSubmitted(p);
      return GestureDetector(
        onTap: () => _showPollSheet(Map<String, dynamic>.from(p)),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: C.yellowMid,
              border: Border.all(color: C.yellowBorder),
              borderRadius: BorderRadius.circular(20)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _mixLabel(contentLabel),
                  if (time.isNotEmpty) Text(time, style: poppins(11, c: C.txl)),
                ]),
            const SizedBox(height: 8),
            Text(text,
                style: poppins(13, w: FontWeight.w700, c: C.ink, h: 1.4)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('$replies responses', style: poppins(11, c: C.txl)),
              Text(submitted ? 'Submitted' : 'Vote now →',
                  style: poppins(12,
                      w: FontWeight.w700,
                      c: submitted ? C.green : C.yellowDeep)),
            ]),
          ]),
        ),
      );
    }

    if (isActivity) {
      final activityBody = CommunityMedia.bodyText(p);
      final activityTitle = _cleanText(
        p['title'] ?? p['activity_title'] ?? 'Daily activity',
      );
      return GestureDetector(
        onTap: id == 0
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActivityDetailScreen(
                      activityId: id,
                      autoOpenReply: false,
                    ),
                  ),
                ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: C.white,
              border: Border.all(color: C.bd),
              borderRadius: BorderRadius.circular(20)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: C.greenLight,
                      borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.celebration_outlined,
                      color: C.green, size: 22)),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        activityTitle.isEmpty
                            ? 'Daily activity'
                            : activityTitle,
                        style: poppins(13, w: FontWeight.w700, c: C.ink)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _mixLabel(contentLabel),
                        Text(time.toString(), style: poppins(11, c: C.txl)),
                      ],
                    ),
                  ])),
              const Icon(Icons.chevron_right_rounded, color: C.txl),
            ]),
            if (activityBody.isNotEmpty && activityBody != text) ...[
              const SizedBox(height: 8),
              Text(activityBody, style: poppins(12, c: C.txm, h: 1.45)),
            ],
            CommunityMedia(item: p, height: 170),
          ]),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: C.white,
          border: Border.all(color: C.bd),
          borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _mixLabel(contentLabel),
          const SizedBox(width: 8),
          Expanded(
            child: Text(time,
                textAlign: TextAlign.right, style: poppins(11, c: C.txl)),
          ),
        ]),
        const SizedBox(height: 10),
        if (text.isNotEmpty)
          Text(text, style: poppins(14, w: FontWeight.w700, c: C.ink, h: 1.45)),
        CommunityMedia(item: p, height: 240),
      ]),
    );
  }

  String _displayTime(Map p) {
    final candidates = [
      p['created_at'],
      p['updated_at'],
      p['date'],
      p['task_date'],
      p['scheduled_at'],
      p['time'],
    ];
    for (final value in candidates) {
      final text = value?.toString().trim() ?? '';
      if (text.isEmpty) continue;
      final lower = text.toLowerCase();
      if (lower == 'poll' ||
          lower == 'feed' ||
          lower == 'post' ||
          lower == 'activity' ||
          lower == 'activities' ||
          lower == 'polls') continue;
      return text;
    }
    return '';
  }

  Future<void> _showPollSheet(Map<String, dynamic> poll) async {
    final pollId = _idOf(poll);
    final question = _cleanText(
      poll['question'] ?? poll['title'] ?? poll['description'] ?? '',
    );
    final options = _pollOptions(poll);
    final total = _pollTotal(poll, options);
    final submitted = _pollSubmitted(poll);
    int? selected = int.tryParse((poll['user_selected'] ??
            poll['selected_option_id'] ??
            poll['answer'] ??
            '')
        .toString());
    bool submitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 18,
            left: 18,
            right: 18,
            top: 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question,
                style: poppins(16, w: FontWeight.w800, c: C.ink, h: 1.35),
              ),
              const SizedBox(height: 6),
              Text(
                submitted
                    ? '$total responses · already submitted'
                    : '$total responses',
                style: poppins(12, c: submitted ? C.green : C.txl),
              ),
              const SizedBox(height: 14),
              if (options.isEmpty)
                Text('No options returned for this poll.',
                    style: poppins(12, c: C.txl))
              else
                ...options.map((opt) {
                  final optId = int.tryParse(
                          (opt['option_id'] ?? opt['id'] ?? 0).toString()) ??
                      0;
                  final label = _cleanText(opt['option_text'] ??
                      opt['option'] ??
                      opt['label'] ??
                      opt['text'] ??
                      '');
                  final votes = int.tryParse((opt['vote_count'] ??
                              opt['votes_count'] ??
                              opt['votes'] ??
                              opt['count'] ??
                              0)
                          .toString()) ??
                      0;
                  final backendPct = double.tryParse(
                      (opt['percentage'] ?? opt['percent'] ?? '').toString());
                  final pct = backendPct != null
                      ? backendPct / 100
                      : total > 0
                          ? votes / total
                          : 0.0;
                  final on = selected == optId;
                  return GestureDetector(
                    onTap: submitting || submitted
                        ? null
                        : () => setSheetState(() => selected = optId),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: on ? C.yellowMid : C.bg2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: on ? C.yellow : C.bd, width: on ? 2 : 1),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            label,
                            style: poppins(13,
                                w: on ? FontWeight.w700 : FontWeight.w500,
                                c: C.ink),
                          ),
                        ),
                        Text(
                            votes > 0
                                ? '${(pct * 100).round()}% · $votes'
                                : '${(pct * 100).round()}%',
                            style: poppins(11, c: C.txl)),
                      ]),
                    ),
                  );
                }),
              const SizedBox(height: 8),
              if (submitted)
                Container(
                  width: double.infinity,
                  height: 46,
                  decoration: BoxDecoration(
                    color: C.greenLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'Submitted',
                      style: poppins(14, w: FontWeight.w700, c: C.green),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: selected == null || submitting || pollId == 0
                      ? null
                      : () async {
                          setSheetState(() => submitting = true);
                          final res = await _svc.submitPoll(
                              pollId: pollId, optionId: selected!);
                          if (mounted) {
                            Navigator.pop(sheetContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  res['message'] ?? 'Poll submitted',
                                  style: poppins(13),
                                ),
                                backgroundColor:
                                    res['status'] == true ? C.green : C.red,
                              ),
                            );
                            _load();
                          }
                        },
                  child: Container(
                    width: double.infinity,
                    height: 46,
                    decoration: BoxDecoration(
                      color: selected == null ? C.bg3 : C.ink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        submitting ? 'Submitting...' : 'Submit vote',
                        style: poppins(14,
                            w: FontWeight.w700,
                            c: selected == null ? C.txl : Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _pollOptions(Map<String, dynamic> poll) {
    final raw = poll['options'] ?? poll['answers'] ?? poll['poll_options'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  int _pollTotal(
      Map<String, dynamic> poll, List<Map<String, dynamic>> options) {
    final explicit = int.tryParse((poll['total_votes'] ??
            poll['total_answered'] ??
            poll['total_users'] ??
            poll['responses_count'] ??
            '')
        .toString());
    if (explicit != null) return explicit;
    return options.fold<int>(
      0,
      (sum, opt) =>
          sum +
          (int.tryParse(
                  (opt['votes_count'] ?? opt['votes'] ?? opt['count'] ?? 0)
                      .toString()) ??
              0),
    );
  }

  bool _pollSubmitted(Map poll) {
    final status = (poll['status'] ?? poll['poll_status'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    final selected = (poll['user_selected'] ??
            poll['selected_option_id'] ??
            poll['answer'] ??
            '')
        .toString()
        .trim();
    return status == 'completed' ||
        status == 'submitted' ||
        status == 'answered' ||
        selected.isNotEmpty;
  }
}
