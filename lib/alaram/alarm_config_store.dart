import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AlarmConfigStore {
  static const String _key = 'elderzha_alarm_config';

  static Future<void> save(Map<String, dynamic> config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(config));
  }

  static Future<Map<String, dynamic>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {};
  }

  static bool hasMedical(Map<String, dynamic> config) {
    if (!_enabled(config['medical_alarm'])) return false;
    return _filled(config['morning_before_food']) ||
        _filled(config['morning_after_food']) ||
        _filled(config['m_before_food']) ||
        _filled(config['m_after_food']) ||
        _filled(config['afternoon_before_food']) ||
        _filled(config['afternoon_after_food']) ||
        _filled(config['af_before_food']) ||
        _filled(config['af_after_food']) ||
        _filled(config['night_before_food']) ||
        _filled(config['night_after_food']) ||
        _filled(config['n_before_food']) ||
        _filled(config['n_after_food']);
  }

  static bool hasFood(Map<String, dynamic> config) {
    if (!_enabled(config['food_alarm'] ?? config['food_alaram'])) return false;
    return _filled(config['breakfast_time']) ||
        _filled(config['bf_time']) ||
        _filled(config['lunch_time']) ||
        _filled(config['l_time']) ||
        _filled(config['dinner_time']) ||
        _filled(config['d_time']);
  }

  static bool _enabled(dynamic value) {
    if (value == null) return true;
    if (value == true) return true;
    if (value is num) return value != 0;
    final text = value.toString().toLowerCase().trim();
    return text == '1' || text == 'true' || text == 'yes' || text == 'active';
  }

  static bool _filled(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isNotEmpty && text.toLowerCase() != 'null';
  }
}
