import 'dart:io';

import 'package:dio/dio.dart';

import 'api_client.dart';

/// Covers:
///   GET  /user/active/daily/acivity          ← master check-in questions
///   POST /user/daily/activity/store          ← submit daily check-in
///   GET  /user/daily/activity/view/{id}      ← single check-in detail
///   GET  /user/daily/activity/month          ← monthly calendar view
///   GET  /user/get/today/activity            ← today's check-in status
///   GET  /user/activities/home               ← home feed activities
///   GET  /user/activity/list                 ← all user activities
///   GET  /user/get/activity/details/{id}     ← activity replies
///   POST /user/activity/reply                ← submit reply
///   POST /user/activity/reply-share          ← reply + share
///   GET  /user/activity-posts/{activity_id}  ← posts per activity
///   GET  /user/get/dashboard                 ← dashboard data

class ActivityService {
  final _api = ApiClient();

  // ── GET /user/active/daily/acivity ───────────────────────
  // Returns check-in question master data (moods, places, people, etc.)
  Future<Map<String, dynamic>?> getDailyActivityMaster() async =>
      await _api.safeGet('/user/active/daily/activity') ??
      await _api.safeGet('/user/active/daily/acivity');

  // ── GET /user/get/today/activity ─────────────────────────
  // Returns today's check-in if already submitted
  Future<Map<String, dynamic>?> getTodayActivity() =>
      _api.safeGet('/user/get/today/activity');

  // ── POST /user/daily/activity/store ──────────────────────
  // Submit the 5-question check-in
  // payload: { mood, people[], places[], activities[], weather, sleep_time, notes }
  Future<Map<String, dynamic>> storeDailyActivity({
    required String mood,
    required List<String> people,
    required List<String> places,
    required List<String> activities,
    required String weather,
    String? sleepTime,
    String? notes,
  }) async {
    final res = await _api.safePost(
      '/user/daily/activity/store',
      data: {
        'mood': mood,
        'people': people,
        'places': places,
        'activities': activities,
        'weather': weather,
        if (sleepTime != null) 'sleep_time': sleepTime,
        if (notes != null) 'notes': notes,
      },
    );
    return res ?? {'status': false, 'message': 'Network error'};
  }

  // ── GET /user/daily/activity/view/{id} ───────────────────
  Future<Map<String, dynamic>?> getDailyActivityById(int id) =>
      _api.safeGet('/user/daily/activity/view/$id');

  // ── GET /user/daily/activity/month ───────────────────────
  // Returns month's check-in calendar data
  // params: { month: 6, year: 2026 }
  Future<Map<String, dynamic>?> getMonthlyActivities({int? month, int? year}) =>
      _api.safeGet(
        '/user/daily/activity/month',
        params: {
          if (month != null) 'month': month,
          if (year != null) 'year': year,
        },
      );

  // ── GET /user/activities/home ─────────────────────────────
  Future<Map<String, dynamic>?> getHomeActivities() =>
      _api.safeGet('/user/activities/home');

  // ── GET /user/activity/list ───────────────────────────────
  Future<Map<String, dynamic>?> listUserActivities() =>
      _api.safeGet('/user/activity/list');

  // ── GET /user/get/activity/details/{id} ──────────────────
  Future<Map<String, dynamic>?> getActivityReplies(int id) =>
      _api.safeGet('/user/get/activity/details/$id');

  // ── POST /user/activity/reply ─────────────────────────────
  Future<Map<String, dynamic>> submitReply({
    required int postId,
    required String replyText,
    File? attachment,
    String? attachmentType,
  }) async {
    Map<String, dynamic>? res;
    if (attachment != null) {
      final form = FormData.fromMap({
        'activity_id': postId,
        'status': 'completed',
        'notes': replyText,
        'upload_image': await MultipartFile.fromFile(attachment.path),
      });
      res = await _api.safeMultipartPost('/user/activity/reply', data: form);
    } else {
      res = await _api.safePost(
        '/user/activity/reply',
        data: {
          'activity_id': postId,
          'status': 'completed',
          'notes': replyText,
        },
      );
    }
    return res ?? {'status': false, 'message': 'Network error'};
  }

  // ── POST /user/activity/reply-share ───────────────────────
  // Submit an activity reply for admin approval and sharing.
  Future<Map<String, dynamic>> submitReplyAndShare({
    required int postId,
    required String replyText,
    File? attachment,
  }) async {
    Map<String, dynamic>? res;
    if (attachment != null) {
      final form = FormData.fromMap({
        'activity_id': postId,
        'status': 'completed',
        'notes': replyText,
        'upload_image': await MultipartFile.fromFile(attachment.path),
      });
      res = await _api.safeMultipartPost('/user/activity/reply-share',
          data: form);
    } else {
      res = await _api.safePost(
        '/user/activity/reply-share',
        data: {
          'activity_id': postId,
          'status': 'completed',
          'notes': replyText,
        },
      );
    }
    return res ?? {'status': false, 'message': 'Network error'};
  }

  // ── GET /user/post/like/{post_id} ─────────────────────────
  Future<Map<String, dynamic>?> likePost(int postId) =>
      _api.safeGet('/user/post/like/$postId');

  // ── GET /user/adminpost/like/{post_id} ────────────────────
  Future<Map<String, dynamic>?> likeAdminPost(int postId) =>
      _api.safeGet('/user/adminpost/like/$postId');

  // ── GET /user/save/community/post/{id} ───────────────────
  Future<Map<String, dynamic>?> saveCommunityPost(int id) =>
      _api.safeGet('/user/save/community/post/$id');

  // ── GET /user/get/dashboard ───────────────────────────────
  Future<Map<String, dynamic>?> getDashboard() =>
      _api.safeGet('/user/get/dashboard');

  // ── GET /user/feed/{type} ─────────────────────────────────
  // type: 'all' | 'feed' | 'polls' | 'activities'
  Future<Map<String, dynamic>?> getCombinedFeed(String type) =>
      _api.safeGet('/user/feed/$type');

  // ── GET /user/activity-posts/{activity_id} ───────────────
  Future<Map<String, dynamic>?> getActivityPosts(int activityId) =>
      _api.safeGet('/user/activity-posts/$activityId');
}
