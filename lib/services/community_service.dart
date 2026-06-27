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

  // ── GET /user/get/pools-list ──────────────────────────────
  Future<Map<String, dynamic>?> getPollsList() =>
      _api.safeGet('/user/get/pools-list');

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

  // ── GET /user/feed/{type} ─────────────────────────────────
  // type: 'all' | 'feed' | 'polls' | 'activities'
  Future<Map<String, dynamic>?> getFeed(String type) async {
    final normalized = type.toLowerCase();
    if (normalized == 'all') {
      final feed = await _firstListResponse([
        '/user/feed/all',
        '/user/feed/post',
        '/user/feeds',
      ]);
      final polls = await _firstListResponse([
        '/user/get/pools-list',
        '/user/feed/poll',
        '/user/feed/pools',
      ]);
      final activities = await _firstListResponse([
        '/user/activity/list',
        '/user/feed/activities',
        '/user/activities/home',
      ]);
      return {
        'status': true,
        'data': {
          'feed': _extractList(feed),
          'polls': _extractList(polls),
          'activities': _extractList(activities),
        },
      };
    }

    final feedType = normalized == 'feed'
        ? 'post'
        : normalized == 'polls'
            ? 'pools'
            : normalized;
    final candidates = <String>[
      if (normalized == 'all') '/user/feed/all',
      if (normalized == 'all') '/user/feed/post',
      if (normalized == 'polls') '/user/get/pools-list',
      if (normalized == 'activities') '/user/activity/list',
      if (normalized == 'activities') '/user/feed/activities',
      if (normalized == 'activities') '/user/activities/home',
      '/user/feed/$feedType',
      if (normalized == 'polls') '/user/feed/poll',
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
