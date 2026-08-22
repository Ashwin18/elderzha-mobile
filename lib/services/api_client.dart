import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ─────────────────────────────────────────────────────────────────────────────
///  ElderZha API Client
///  Base URL : https://elderzhacopy.elderzha.online/api/
///  Token key: auth_token  (matches original app — SharedPreferences)
/// ─────────────────────────────────────────────────────────────────────────────

class ApiClient {
  static const String baseUrl = 'https://elderzhacopy.elderzha.online/api';

  // ⚠️  Token key MUST match original app — 'auth_token' (not ez_auth_token)
  static const String _tokenKey = 'auth_token';

  // Native code (FallSOSActivity — runs independently of the Flutter engine,
  // even if the app was killed) cannot read Flutter's own shared_preferences
  // storage on newer plugin versions (they moved to Android DataStore).
  // So the token is explicitly mirrored into a native-only cache file
  // every time it changes.
  static const MethodChannel _nativeChannel = MethodChannel('alarm_service');

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio _dio;

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          debugPrint('→ ${options.method} ${options.path}');
          return handler.next(options);
        },
        onResponse: (res, handler) {
          debugPrint('← ${res.statusCode} ${res.requestOptions.path}');
          return handler.next(res);
        },
        onError: (e, handler) {
          debugPrint(
            '✗ ${e.response?.statusCode} ${e.requestOptions.path}: ${e.message}',
          );
          return handler.next(e);
        },
      ),
    );
  }

  // ── Token — SharedPreferences (key = 'auth_token') ────────────────────────
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await _syncTokenToNative(token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await _syncTokenToNative(null);
  }

  /// Mirrors the current token into native storage. Safe to call anytime —
  /// e.g. on every app start, so already-logged-in users get their token
  /// cached natively without needing to log out and back in.
  Future<void> _syncTokenToNative(String? token) async {
    try {
      await _nativeChannel.invokeMethod('cacheAuthTokenNative', {'token': token});
    } catch (_) {
      // Non-fatal — SOS still works if this happens to fail, it'll just
      // retry on the next app open/login.
    }
  }

  /// Call once on app startup to make sure native fall-detection code has
  /// the latest token, even for users who were already logged in before
  /// this native cache existed.
  Future<void> syncCurrentTokenToNative() async {
    final token = await getToken();
    await _syncTokenToNative(token);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ── HTTP helpers ───────────────────────────────────────────────────────────
  Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      _dio.get(path, queryParameters: params);

  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);

  Future<Response> delete(String path, {dynamic data}) =>
      _dio.delete(path, data: data);

  Future<Response> multipartPost(String path, {required FormData data}) =>
      _dio.post(
        path,
        data: data,
        options: Options(contentType: 'multipart/form-data'),
      );

  Future<Map<String, dynamic>?> safeGet(
    String path, {
    Map<String, dynamic>? params,
  }) async {
    try {
      final res = await get(path, params: params);
      return res.data as Map<String, dynamic>?;
    } on DioException catch (e) {
      debugPrint('safeGet [$path] error: ${e.message}');
      return _errorBody(e);
    }
  }

  Future<Map<String, dynamic>?> safePost(String path, {dynamic data}) async {
    try {
      final res = await post(path, data: data);
      return res.data as Map<String, dynamic>?;
    } on DioException catch (e) {
      debugPrint('safePost [$path] error: ${e.message}');
      return _errorBody(e);
    }
  }

  Future<Map<String, dynamic>?> safeDelete(String path, {dynamic data}) async {
    try {
      final res = await delete(path, data: data);
      return res.data as Map<String, dynamic>?;
    } on DioException catch (e) {
      debugPrint('safeDelete [$path] error: ${e.message}');
      return _errorBody(e);
    }
  }

  Future<Map<String, dynamic>?> safeMultipartPost(
    String path, {
    required FormData data,
  }) async {
    try {
      final res = await multipartPost(path, data: data);
      return res.data as Map<String, dynamic>?;
    } on DioException catch (e) {
      debugPrint('safeMultipartPost [$path] error: ${e.message}');
      return _errorBody(e);
    }
  }

  Map<String, dynamic>? _errorBody(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    final code = e.response?.statusCode;
    if (code == 401) {
      return {'status': false, 'message': 'OTP wrongly entered'};
    }
    if (data != null && data.toString().trim().isNotEmpty) {
      return {'status': false, 'message': data.toString()};
    }
    return null;
  }
}
