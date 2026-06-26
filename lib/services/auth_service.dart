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

  // ── POST /user/family/add-for-user ───────────────────────
  Future<Map<String, dynamic>> addFamily({
    required String name,
    required String relation,
    String? birthdayDate,
    String? anniversaryDate,
  }) async {
    final eventType = _familyEventType(birthdayDate, anniversaryDate);
    final primaryDate = birthdayDate?.trim().isNotEmpty == true
        ? birthdayDate!.trim()
        : (anniversaryDate ?? '').trim();
    final res = await _api.safePost(
      '/user/family/add-for-user',
      data: {
        'name': name,
        'relation': relation,
        'event_type': eventType,
        'date': primaryDate,
        if (birthdayDate != null && birthdayDate.trim().isNotEmpty)
          'birthday_date': birthdayDate.trim(),
        if (anniversaryDate != null && anniversaryDate.trim().isNotEmpty)
          'anniversary_date': anniversaryDate.trim(),
      },
    );
    return res ?? {'status': false, 'message': 'Network error'};
  }

  // ── POST /user/family/{id}/update ────────────────────────
  Future<Map<String, dynamic>> updateFamily({
    required int id,
    required String name,
    required String relation,
    String? birthdayDate,
    String? anniversaryDate,
  }) async {
    final eventType = _familyEventType(birthdayDate, anniversaryDate);
    final primaryDate = birthdayDate?.trim().isNotEmpty == true
        ? birthdayDate!.trim()
        : (anniversaryDate ?? '').trim();
    final res = await _api.safePost(
      '/user/family/$id/update',
      data: {
        'name': name,
        'relation': relation,
        'event_type': eventType,
        'date': primaryDate,
        if (birthdayDate != null && birthdayDate.trim().isNotEmpty)
          'birthday_date': birthdayDate.trim(),
        if (anniversaryDate != null && anniversaryDate.trim().isNotEmpty)
          'anniversary_date': anniversaryDate.trim(),
      },
    );
    return res ?? {'status': false, 'message': 'Network error'};
  }

  String _familyEventType(String? birthdayDate, String? anniversaryDate) {
    final hasBirthday = birthdayDate != null && birthdayDate.trim().isNotEmpty;
    final hasAnniversary =
        anniversaryDate != null && anniversaryDate.trim().isNotEmpty;
    if (hasBirthday && hasAnniversary) return 'both';
    if (hasAnniversary) return 'anniversary';
    return 'birthday';
  }

  Future<bool> get isLoggedIn => _api.isLoggedIn();
}
