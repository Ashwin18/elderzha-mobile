import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/services.dart';

class AuthProvider extends ChangeNotifier {
  final _authService = AuthService();

  bool _isLoggedIn = false;
  bool _loading = false;
  Map<String, dynamic>? _user;
  String? _error;

  bool get isLoggedIn => _isLoggedIn;
  bool get loading => _loading;
  Map<String, dynamic>? get user => _user;
  String? get error => _error;

  String get userName =>
      _firstText(['name', 'full_name', 'user_name']) ?? 'User';
  String get userPhone =>
      _firstText(['phone', 'mobile', 'mobile_number']) ?? '';
  String get userEmail => _firstText(['email']) ?? '';
  String get userDob =>
      _firstText(['dob', 'date_of_birth', 'birth_date']) ?? '';
  String get userGender => _firstText(['gender', 'sex']) ?? '';

  Future<void> checkAuth() async {
    // Use same key as original: 'auth_token'
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    _isLoggedIn = token.isNotEmpty;
    if (_isLoggedIn) await loadUser();
    notifyListeners();
  }

  // POST /user/phone-login
  Future<bool> phoneLogin(String phone) async {
    _loading = true;
    _error = null;
    notifyListeners();
    final res = await _authService.phoneLogin(phone);
    _loading = false;
    if (res['status'] != true) {
      _error = res['message'] ?? 'Failed to send OTP';
      notifyListeners();
      return false;
    }
    notifyListeners();
    return true;
  }

  // POST /user/verify-otp
  Future<bool> verifyOtp(String phone, String otp) async {
    _loading = true;
    _error = null;
    notifyListeners();
    final res = await _authService.verifyOtp(phone: phone, otp: otp);
    _loading = false;
    if (res['status'] != true) {
      _error = res['message'] ?? 'Invalid OTP';
      notifyListeners();
      return false;
    }
    _isLoggedIn = true;
    _user = _normalizeUser(res);
    notifyListeners();

    // Sync FCM token stored from Firebase init
    _syncStoredFCMToken();
    return true;
  }

  Future<void> _syncStoredFCMToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var fcmToken = prefs.getString('fcm_device_token') ?? '';
      if (fcmToken.isEmpty) {
        fcmToken = await FirebaseMessaging.instance.getToken() ?? '';
        if (fcmToken.isNotEmpty) {
          await prefs.setString('fcm_device_token', fcmToken);
        }
      }
      if (fcmToken.isNotEmpty) {
        await _authService.updateFcmToken(fcmToken);
        debugPrint('FCM token synced after login');
      }
    } catch (e) {
      debugPrint('FCM sync error: $e');
    }
  }

  // GET /user/get/user/details
  Future<void> loadUser() async {
    final res = await _authService.getUserDetails();
    if (res != null) {
      _user = _normalizeUser(res);
      notifyListeners();
    }
  }

  Map<String, dynamic>? _normalizeUser(Map<String, dynamic>? res) {
    if (res == null) return null;
    dynamic node = res['user'] ?? res['profile'] ?? res['data'];
    if (node is Map && node['user'] is Map) node = node['user'];
    if (node is Map && node['profile'] is Map) node = node['profile'];
    if (node is Map && node['data'] is Map) node = node['data'];
    if (node is Map) return Map<String, dynamic>.from(node);
    return Map<String, dynamic>.from(res);
  }

  String? _firstText(List<String> keys) {
    final user = _user;
    if (user == null) return null;
    for (final key in keys) {
      final value = user[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  // POST /user/profile/update
  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String phone,
    String? email,
    String? dob,
    String? gender,
    File? photo,
    bool submitForAdmin = false,
  }) async {
    final res = await _authService.updateProfile(
      name: name,
      phone: phone,
      email: email,
      dob: dob,
      gender: gender,
      photo: photo,
      submitForAdmin: submitForAdmin,
    );
    if (res['status'] == true || res['data'] != null) await loadUser();
    return res;
  }

  // POST /user/logout
  Future<void> logout() async {
    await _authService.logout();
    final prefs = await SharedPreferences.getInstance();
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('FCM token delete error: $e');
    }
    await prefs.remove('fcm_device_token');
    await prefs.remove('seen_notification_ids');
    await SubscriptionService.clearSubscriptionActiveLocal();
    _isLoggedIn = false;
    _user = null;
    notifyListeners();
  }
}
