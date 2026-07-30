import 'api_client.dart';
import 'dart:io';

import 'package:dio/dio.dart';

/// Covers:
///   POST /user/phone-login
///   POST /user/verify-otp
///   POST /user/logout
///   POST /user/profile/update
///   GET  /user/get/user/details
///   GET  /user/get/profile-with-family

class AuthService {
  final _api = ApiClient();

  // ── POST /user/phone-login ────────────────────────────────
  // Sends OTP to phone number
  Future<Map<String, dynamic>> phoneLogin(String phone) async {
    try {
      final res = await _api.post('/user/phone-login', data: {'phone': phone});
      return res.data;
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  // ── POST /user/verify-otp ─────────────────────────────────
  // Verifies OTP, returns { token, user }
  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      final res = await _api.post(
        '/user/verify-otp',
        data: {'phone': phone, 'otp': otp},
      );
      final data = res.data;
      // Save token on success. Some API builds return it at root, others
      // return it inside data.
      final token =
          data['token'] ?? data['data']?['token'] ?? data['access_token'];
      if (data['status'] == true && token != null) {
        await _api.saveToken(token.toString());
      }
      return data;
    } catch (e) {
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map) {
          final message = data['message']?.toString();
          return {
            'status': false,
            'message': message == 'Invalid OTP'
                ? 'OTP wrongly entered'
                : (message ?? 'OTP wrongly entered'),
          };
        }
      }
      return {'status': false, 'message': 'OTP wrongly entered'};
    }
  }

  // ── POST /user/logout ─────────────────────────────────────
  Future<bool> logout() async {
    await updateFcmToken('');
    await _api.safePost('/user/logout');
    await _api.clearToken();
    return true;
  }

  // ── POST /user/profile/update ─────────────────────────────
  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String phone,
    String? email,
    String? dob,
    String? gender,
    File? photo,
    bool submitForAdmin = false,
  }) async {
    final profilePayload = {
      'name': name,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'phone': phone,
      if (email != null) 'email': email,
      if (dob != null) 'dob': dob,
      if (gender != null) 'gender': gender,
      if (submitForAdmin) 'profile_status': 'pending',
      if (submitForAdmin) 'submitted_to_admin': 1,
    };
    Map<String, dynamic>? res;
    if (photo != null) {
      final form = FormData.fromMap({
        ...profilePayload,
        'image': await MultipartFile.fromFile(photo.path),
      });
      res = await _api.safeMultipartPost('/user/profile/update', data: form);
    } else {
      res = await _api.safePost(
        '/user/profile/update',
        data: profilePayload,
      );
    }
    return res ?? {'status': false, 'message': 'Network error'};
  }

  // ── POST /user/device-token ───────────────────────────────
  Future<void> updateFcmToken(String fcmToken) async {
    await _api.safePost('/user/device-token', data: {'fcm_token': fcmToken});
  }

  // ── GET /user/get/user/details ────────────────────────────
  Future<Map<String, dynamic>?> getUserDetails() =>
      _api.safeGet('/user/get/user/details');

  // ── GET /user/get/profile-with-family ────────────────────
  Future<Map<String, dynamic>?> getProfileWithFamily() =>
      _api.safeGet('/user/get/profile-with-family');

  // ── GET /user/get/family/master ───────────────────────────
  Future<Map<String, dynamic>?> getFamilyMasterList() =>
      _api.safeGet('/user/get/family/master');


  // ── family_member_table ID mappings ──────────────────────────────────────
  static const Map<String, int> _relationIds = {
    'Father': 1, 'Mother': 2, 'Wife': 3, 'Husband': 4,
    'Son': 5, 'Daughter': 6, 'Grand Son': 7, 'Grand Daughter': 8,
    'Self': 11, 'Spouse': 12, 'Child': 5, 'Parent': 1,
    'Sibling': 5, 'Friend': 5, 'Other': 5,
  };
  static const int _birthdayEventId   = 9;
  static const int _anniversaryEventId = 10;

  int? _resolveRelationId(String relation) =>
      _relationIds[relation] ?? _relationIds.entries
          .firstWhere((e) => e.key.toLowerCase() == relation.toLowerCase(),
              orElse: () => const MapEntry('', 5))
          .value;

  // ── POST /user/family/add-for-user ───────────────────────
  Future<Map<String, dynamic>> addFamily({
    required String name,
    String? phone,
    required String relation,
    String? birthdayDate,
    String? anniversaryDate,
  }) async {
    final eventType = _familyEventType(birthdayDate, anniversaryDate);
    final birthdayApi = _familyDateForApi(birthdayDate);
    final anniversaryApi = _familyDateForApi(anniversaryDate);
    final primaryDate = birthdayApi.isNotEmpty ? birthdayApi : anniversaryApi;
    final res = await _api.safePost(
      '/user/family/add-for-user',
      data: {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'relation': relation,
        'relation_name': relation,
        'relation_id': _resolveRelationId(relation) ?? 5,
        'event_id': birthdayApi.isNotEmpty ? _birthdayEventId : _anniversaryEventId,
        'event_type': eventType,
        'date': primaryDate,
        'event_date': primaryDate,
        if (birthdayApi.isNotEmpty) 'birthday_date': birthdayApi,
        if (birthdayApi.isNotEmpty) 'birthday': birthdayApi,
        if (anniversaryApi.isNotEmpty) 'anniversary_date': anniversaryApi,
        if (anniversaryApi.isNotEmpty) 'anniversary': anniversaryApi,
      },
    );
    return res ?? {'status': false, 'message': 'Network error'};
  }

  // ── POST /user/family/{id}/update ────────────────────────
  Future<Map<String, dynamic>> updateFamily({
    required int id,
    required String name,
    String? phone,
    required String relation,
    int? relationId,
    int? eventId,
    String? birthdayDate,
    String? anniversaryDate,
  }) async {
    final eventType = _familyEventType(birthdayDate, anniversaryDate);
    final birthdayApi = _familyDateForApi(birthdayDate);
    final anniversaryApi = _familyDateForApi(anniversaryDate);
    final primaryDate = birthdayApi.isNotEmpty ? birthdayApi : anniversaryApi;
    final res = await _api.safePost(
      '/user/family/$id/update',
      data: {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'relation': relation,
        'relation_name': relation,
        // Use passed IDs or resolve from relation name
        'relation_id': relationId ?? _resolveRelationId(relation) ?? 5,
        if (eventId != null) 'event_id': eventId
        else if (birthdayApi.isNotEmpty) 'event_id': _birthdayEventId
        else if (anniversaryApi.isNotEmpty) 'event_id': _anniversaryEventId,
        'event_type': eventType,
        'date': primaryDate,
        'event_date': primaryDate,
        if (birthdayApi.isNotEmpty) 'birthday_date': birthdayApi,
        if (birthdayApi.isNotEmpty) 'birthday': birthdayApi,
        if (anniversaryApi.isNotEmpty) 'anniversary_date': anniversaryApi,
        if (anniversaryApi.isNotEmpty) 'anniversary': anniversaryApi,
      },
    );
    return res ?? {'status': false, 'message': 'Network error'};
  }

  Future<Map<String, dynamic>> deleteFamily(int id) async {
    for (final path in [
      '/user/family/$id/delete',
      '/user/family/delete/$id',
      '/user/family/$id/destroy',
      '/user/family/remove/$id',
    ]) {
      final res = await _api.safePost(path);
      if (res != null && res['status'] != false) return res;
    }
    return {'status': false, 'message': 'Delete endpoint unavailable'};
  }

  String _familyEventType(String? birthdayDate, String? anniversaryDate) {
    final hasBirthday = birthdayDate != null && birthdayDate.trim().isNotEmpty;
    final hasAnniversary =
        anniversaryDate != null && anniversaryDate.trim().isNotEmpty;
    if (hasBirthday && hasAnniversary) return 'both';
    if (hasAnniversary) return 'anniversary';
    return 'birthday';
  }

  String _familyDateForApi(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return '';
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
    if (iso != null) return raw;
    final indian = RegExp(r'^(\d{2})-(\d{2})-(\d{4})$').firstMatch(raw);
    if (indian != null) {
      return '${indian.group(3)}-${indian.group(2)}-${indian.group(1)}';
    }
    final slash = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(raw);
    if (slash != null) {
      return '${slash.group(3)}-${slash.group(2)}-${slash.group(1)}';
    }
    return raw;
  }

  Future<bool> get isLoggedIn => _api.isLoggedIn();
}
