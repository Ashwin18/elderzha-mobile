import 'api_client.dart';

/// Covers:
///   GET  /user/get/pools-list            ← polls list
///   POST /user/poll/submit               ← submit poll vote
///   GET  /user/feed/{type}               ← combined feed (all/feed/polls/activities)
///   GET  /user/get/activity/details/{id} ← activity detail + replies
///   POST /user/activity/reply            ← submit a reply
///   POST /user/activity/reply-share      ← reply + share
///   GET  /user/post/like/{post_id}       ← like a post
///   GET  /user/adminpost/like/{post_id}  ← like admin post
///   GET  /user/save/community/post/{id}  ← save/bookmark post
///   GET  /user/activity-posts/{id}       ← posts within an activity

class CommunityService {
  final _api = ApiClient();

  // ── Short-lived cache for the calendar endpoints ────────────
  // Home's "Today at a Glance" strip and Spike's new-item dot
  // check both call these same two endpoints independently. If a
  // user bounces between Home and Spike a few times in quick
  // succession, that adds up to real redundant network calls —
  // this cache means only the FIRST call in any 20-second window
  // actually hits the network; the rest reuse that result.
  static Map<String, dynamic>? _pollCalendarCache;
  static DateTime? _pollCalendarCacheAt;
  static Map<String, dynamic>? _activityCalendarCache;
  static DateTime? _activityCalendarCacheAt;
  static const _cacheTtl = Duration(seconds: 20);

  // ── GET /user/get/pools-list ──────────────────────────────
  Future<Map<String, dynamic>?> getPollsList({int page = 1}) =>
      _api.safeGet('/user/get/pools-list?page=$page');

  // ── GET /user/poll/calendar ────────────────────────────────
  // Dedicated Today/Coming Up/History calendar for the redesigned
  // Polls tab — mirrors getActivityCalendar(). 30-day rolling
  // window since polls are broadcast-only.
  Future<Map<String, dynamic>?> getPollCalendar({bool forceRefresh = false}) async {
    final cachedAt = _pollCalendarCacheAt;
    if (!forceRefresh &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _cacheTtl) {
      return _pollCalendarCache;
    }
    final res = await _api.safeGet('/user/poll/calendar');
    _pollCalendarCache = res;
    _pollCalendarCacheAt = DateTime.now();
    return res;
  }

  // ── POST /user/poll/submit ────────────────────────────────
  Future<Map<String, dynamic>> submitPoll({
    required int pollId,
    required int optionId,
  }) async {
    final res = await _api.safePost('/user/poll/submit', data: {
      'poll_id': pollId,
      'option_id': optionId,
    });
    return res ?? {'status': false, 'message': 'Network error'};
  }

  // ── GET /user/activity/calendar ───────────────────────────
  // Dedicated 30-day locked calendar for the redesigned Activities
  // tab — separate from the generic feed, returns per-day lock
  // status (locked/today/completed/missed) with content only
  // included for unlocked days.
  Future<Map<String, dynamic>?> getActivityCalendar({bool forceRefresh = false}) async {
    final cachedAt = _activityCalendarCacheAt;
    if (!forceRefresh &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _cacheTtl) {
      return _activityCalendarCache;
    }
    final res = await _api.safeGet('/user/activity/calendar');
    _activityCalendarCache = res;
    _activityCalendarCacheAt = DateTime.now();
    return res;
  }

  // ── GET /user/feed/{type} ─────────────────────────────────
  // Backend combinedFeed accepts: 'all', 'post' (feeds+activities), 'pools' (polls)
  // Tab mapping: 'all'→'all', 'feed'→'post', 'polls'→'pools', 'activities'→'post'
  Future<Map<String, dynamic>?> getFeed(String type) async {
    final normalized = type.toLowerCase();

    // 'all' tab — call /user/feed/all which returns everything
    if (normalized == 'all') {
      return _api.safeGet('/user/feed/all');
    }

    // 'polls' tab — use dedicated polls endpoint
    if (normalized == 'polls') {
      final res = await _api.safeGet('/user/get/pools-list');
      return res;
    }

    // 'activities' tab — use dedicated activity list endpoint
    if (normalized == 'activities') {
      // /user/activity/list returns actual user-assigned activities
      // /user/feed/post returns admin_posts (feeds) — wrong for activities tab
      final res = await _api.safeGet('/user/activity/list');
      if (res != null && res['status'] == true) return res;
      // Fallback if activity/list doesn't exist
      return await _api.safeGet('/user/feed/post');
    }

    // 'feed' tab — backend uses type='post'
    if (normalized == 'feed') {
      final res = await _api.safeGet('/user/feed/post');
      return res;
    }

    // fallback
    final candidates = <String>[
      '/user/feed/$normalized',
    ];

    Map<String, dynamic>? firstEmpty;
    for (final path in candidates.toSet()) {
      final res = await _api.safeGet(path);
      final data = res?['data'];
      final hasList = data is List ||
          data is Map && data.values.any((v) => v is List) ||
          res?['feeds'] is List ||
          res?['polls'] is List ||
          res?['activities'] is List;
      if (res != null && hasList) {
        if (_listCount(res) > 0) return res;
        firstEmpty ??= res;
      }
    }
    return firstEmpty;
  }

  Future<Map<String, dynamic>?> _firstListResponse(List<String> paths) async {
    Map<String, dynamic>? firstEmpty;
    for (final path in paths) {
      final res = await _api.safeGet(path);
      if (res == null || res['status'] == false) continue;
      if (_listCount(res) > 0) return res;
      firstEmpty ??= res;
    }
    return firstEmpty;
  }

  List _extractList(dynamic value) {
    if (value is List) return value;
    if (value is! Map) return [];
    const keys = [
      'data',
      'feeds',
      'feed',
      'posts',
      'polls',
      'pools',
      'activities',
      'today_activities',
      'items',
      'list',
    ];
    for (final key in keys) {
      final child = value[key];
      if (child is List) return child;
      if (child is Map) {
        for (final nested in keys) {
          final nestedChild = child[nested];
          if (nestedChild is List) return nestedChild;
        }
      }
    }
    return [];
  }

  int _listCount(dynamic value) {
    if (value is List) return value.length;
    if (value is Map) {
      var total = 0;
      for (final child in value.values) {
        total += _listCount(child);
      }
      return total;
    }
    return 0;
  }

  // ── GET /user/get/activity/details/{id} ──────────────────
  Future<Map<String, dynamic>?> getActivityDetails(int id) =>
      _api.safeGet('/user/get/activity/details/$id');

  // ── POST /user/activity/reply ─────────────────────────────
  Future<Map<String, dynamic>> submitReply({
    required int postId,
    required String reply,
  }) async {
    final res = await _api.safePost('/user/activity/reply', data: {
      'activity_id': postId,
      'status': 'completed',
      'notes': reply,
    });
    return res ?? {'status': false, 'message': 'Network error'};
  }

  // ── POST /user/activity/reply-share ──────────────────────
  Future<Map<String, dynamic>> replyAndShare({
    required int postId,
    required String reply,
  }) async {
    final res = await _api.safePost('/user/activity/reply-share', data: {
      'activity_id': postId,
      'status': 'completed',
      'notes': reply,
    });
    return res ?? {'status': false, 'message': 'Network error'};
  }

  // ── GET /user/post/like/{post_id} ─────────────────────────
  Future<Map<String, dynamic>?> likePost(int postId) =>
      _api.safeGet('/user/post/like/$postId');

  // ── GET /user/adminpost/like/{post_id} ────────────────────
  Future<Map<String, dynamic>?> likeAdminPost(int postId) =>
      _api.safeGet('/user/adminpost/like/$postId');

  // ── GET /user/save/community/post/{id} ───────────────────
  Future<Map<String, dynamic>?> savePost(int id) =>
      _api.safeGet('/user/save/community/post/$id');

  // ── GET /user/activity-posts/{activity_id} ───────────────
  Future<Map<String, dynamic>?> getActivityPosts(int activityId) =>
      _api.safeGet('/user/activity-posts/$activityId');
}
