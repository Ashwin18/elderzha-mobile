import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'api_client.dart';

/// One of the 10 life areas rated in the 100-Day Challenge.
class ChallengeArea {
  final String key;
  final String label;
  final String question;
  final IconData icon;
  final Color color;
  const ChallengeArea(this.key, this.label, this.question, this.icon, this.color);
}

const kChallengeAreas = <ChallengeArea>[
  ChallengeArea('physical', 'Physical Health & Energy',
      'How would you rate your physical health and energy today?',
      Icons.directions_run_rounded, Color(0xFFF59E0B)),
  ChallengeArea('mental', 'Mental Well-being',
      'How would you rate your mental well-being today?',
      Icons.psychology_rounded, Color(0xFF7C4DDB)),
  ChallengeArea('memory', 'Memory',
      'How confident do you feel about remembering everyday things?',
      Icons.lightbulb_rounded, Color(0xFF3B82F6)),
  ChallengeArea('happiness', 'Happiness',
      'How happy and positive do you feel in your daily life?',
      Icons.sentiment_satisfied_alt_rounded, Color(0xFFF5B400)),
  ChallengeArea('social', 'Social Connection',
      'How connected do you feel with family and friends?',
      Icons.groups_rounded, Color(0xFFE8334F)),
  ChallengeArea('learning', 'Learning',
      'How often do you learn or try something new?',
      Icons.menu_book_rounded, Color(0xFF22A85A)),
  ChallengeArea('routine', 'Daily Routine',
      'How well are you maintaining a healthy daily routine?',
      Icons.event_note_rounded, Color(0xFF6D4AD0)),
  ChallengeArea('independence', 'Independence',
      'How confident do you feel managing your everyday activities?',
      Icons.verified_user_rounded, Color(0xFF2563EB)),
  ChallengeArea('engagement', 'Engagement',
      'How actively do you participate in activities you enjoy?',
      Icons.palette_rounded, Color(0xFFE8334F)),
  ChallengeArea('overall', 'Overall Life Satisfaction',
      'How satisfied are you with your life these days?',
      Icons.favorite_rounded, Color(0xFFF97316)),
];

/// Keeps what the server last told us about the user's challenge, so Home
/// and the compulsory Day 1 step can react without waiting on the network.
class ChallengeState {
  static final ApiClient _api = ApiClient();

  /// {baseline_done, day100_done, day_number, total_days, day100_unlocked,
  ///  days_left, baseline_date, day100_date} — null until first loaded.
  static final ValueNotifier<Map<String, dynamic>?> status =
      ValueNotifier<Map<String, dynamic>?>(null);

  static Map<String, dynamic>? _data(Map<String, dynamic>? res) {
    if (res != null && res['status'] == true && res['data'] is Map) {
      return Map<String, dynamic>.from(res['data'] as Map);
    }
    return null;
  }

  static Future<Map<String, dynamic>?> load() async {
    final d = _data(await _api.safeGet('/user/challenge/status'));
    if (d != null) status.value = d;
    return d;
  }

  /// Returns null on success, or the message to show the user.
  static Future<String?> submitBaseline(Map<String, int> scores) async {
    final res = await _api.safePost('/user/challenge/baseline',
        data: {'scores': scores});
    final d = _data(res);
    if (d != null) {
      status.value = d;
      return null;
    }
    return (res?['message'] ?? 'Could not save. Please try again.').toString();
  }

  static Future<String?> submitDay100(
      Map<String, int> scores, String comment) async {
    final res = await _api.safePost('/user/challenge/day100',
        data: {'scores': scores, 'comment': comment});
    final d = _data(res);
    if (d != null) {
      status.value = d;
      return null;
    }
    return (res?['message'] ?? 'Could not save. Please try again.').toString();
  }

  static Future<Map<String, dynamic>?> report() async =>
      _data(await _api.safeGet('/user/challenge/report'));

  static bool get baselineMissing =>
      status.value != null && status.value!['baseline_done'] != true;

  static void reset() => status.value = null;
}
