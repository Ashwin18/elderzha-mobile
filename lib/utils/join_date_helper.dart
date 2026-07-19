// lib/utils/join_date_helper.dart
//
// Single source of truth for checking whether a user can interact
// with content based on their join date.
//
// Rule:
//   Content created ON or AFTER user's join date → can interact
//   Content created BEFORE user's join date     → view only

import 'package:shared_preferences/shared_preferences.dart';

class JoinDateHelper {
  // ── Save join date after OTP verify / login ─────────────────────────────
  static Future<void> saveJoinDate(String createdAt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_join_date', createdAt);
  }

  // ── Get stored join date ─────────────────────────────────────────────────
  static Future<DateTime?> getJoinDate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user_join_date') ?? '';
    if (raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  // ── Core check ───────────────────────────────────────────────────────────
  // Returns true if the user is allowed to interact with this content.
  // contentDateStr: ISO date string from API (created_at, date, expiry_date etc.)
  static Future<bool> canInteract(String? contentDateStr) async {
    if (contentDateStr == null || contentDateStr.isEmpty) return true;
    final joinDate = await getJoinDate();
    if (joinDate == null) return true; // no join date stored → allow
    try {
      final contentDate = DateTime.parse(contentDateStr);
      // Content created on or after join date → can interact
      // Use date-only comparison (ignore time)
      final joinDay    = DateTime(joinDate.year, joinDate.month, joinDate.day);
      final contentDay = DateTime(contentDate.year, contentDate.month, contentDate.day);
      return !contentDay.isBefore(joinDay);
    } catch (_) {
      return true;
    }
  }

  // ── Sync version (when join date already loaded in memory) ───────────────
  static bool canInteractSync(String? contentDateStr, DateTime? joinDate) {
    if (contentDateStr == null || contentDateStr.isEmpty) return true;
    if (joinDate == null) return true;
    try {
      final contentDate = DateTime.parse(contentDateStr);
      final joinDay     = DateTime(joinDate.year, joinDate.month, joinDate.day);
      final contentDay  = DateTime(contentDate.year, contentDate.month, contentDate.day);
      return !contentDay.isBefore(joinDay);
    } catch (_) {
      return true;
    }
  }

  // ── Clear on logout ──────────────────────────────────────────────────────
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_join_date');
  }
}
