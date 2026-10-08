import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';

const MethodChannel _historyChannel = MethodChannel('alarm_service');

/// One scheduled alarm occurrence and whether it rang.
class AlarmEvent {
  final String localId;
  final int alarmId;
  final String title;
  final String type;
  final DateTime scheduledFor;
  final DateTime recordedAt;
  final bool rang;
  final bool synced;
  /// What the user did: 'ok', 'snoozed', 'dismissed' — or null if nothing yet.
  final String? ack;
  final DateTime? ackAt;

  const AlarmEvent({
    required this.localId,
    required this.alarmId,
    required this.title,
    required this.type,
    required this.scheduledFor,
    required this.recordedAt,
    required this.rang,
    required this.synced,
    this.ack,
    this.ackAt,
  });

  factory AlarmEvent.fromJson(Map<String, dynamic> j) => AlarmEvent(
        localId: j['localId']?.toString() ?? '',
        alarmId: (j['alarmId'] as num?)?.toInt() ?? 0,
        title: j['title']?.toString() ?? '',
        type: j['type']?.toString() ?? '',
        scheduledFor: DateTime.fromMillisecondsSinceEpoch(
            (j['scheduledFor'] as num?)?.toInt() ?? 0),
        recordedAt: DateTime.fromMillisecondsSinceEpoch(
            (j['recordedAt'] as num?)?.toInt() ?? 0),
        rang: j['status'] == 'rang',
        synced: j['synced'] == true,
        ack: (j['ack']?.toString().isEmpty ?? true) ? null : j['ack'].toString(),
        ackAt: (j['ackAt'] is num && (j['ackAt'] as num) > 0)
            ? DateTime.fromMillisecondsSinceEpoch((j['ackAt'] as num).toInt())
            : null,
      );

  /// "💊 Elderzha • Morning Before Food" -> "Morning Before Food"
  String get friendlyTitle {
    final parts = title.split('•');
    final t = (parts.length > 1 ? parts.last : title).trim();
    return t.isEmpty ? 'Reminder' : t;
  }

  Map<String, dynamic> toServerJson() => {
        'local_id': localId,
        'alarm_id': alarmId,
        'title': title,
        'type': type,
        'scheduled_for': scheduledFor.toUtc().toIso8601String(),
        'recorded_at': recordedAt.toUtc().toIso8601String(),
        'status': rang ? 'rang' : 'missed',
        'ack_action': ack,
        'acknowledged_at': ackAt?.toUtc().toIso8601String(),
      };
}

/// Reads the native alarm log, repairs alarms that silently stopped, and
/// reports the log to the backend so the team can see it too.
class AlarmHistoryService {
  static DateTime? _lastRun;

  /// Alarms the app has saved in Flutter's preferences. Handing them to the
  /// native side arms any that aren't armed (installs from before the native
  /// store existed, or a chain that was lost). Already-armed alarms are left
  /// alone.
  static Future<void> _seedNativeStore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('scheduled_alarms') ?? [];
      final alarms = <Map<String, dynamic>>[];
      for (final s in raw) {
        try {
          final m = Map<String, dynamic>.from(jsonDecode(s));
          alarms.add({
            'id': m['id'],
            'triggerAt': m['triggerAt'],
            'title': m['title'],
            'scheduleType': m['scheduleType'],
            'notes': m['notes'],
            'soundUrl': m['soundUrl'],
            'imageUrl': m['imageUrl'],
          });
        } catch (_) {}
      }
      if (alarms.isNotEmpty) {
        await _historyChannel.invokeMethod('seedAlarmStore', {'alarms': alarms});
      }
    } catch (e) {
      debugPrint('AlarmHistoryService: seed failed: $e');
    }
  }

  /// Newest first. Also repairs any alarm that never rang (native side).
  static Future<List<AlarmEvent>> events() async {
    try {
      final raw = await _historyChannel.invokeMethod<String>('getAlarmEvents');
      final list = jsonDecode(raw ?? '[]') as List;
      final events = list
          .whereType<Map>()
          .map((m) => AlarmEvent.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      events.sort((a, b) => b.scheduledFor.compareTo(a.scheduledFor));
      return events;
    } catch (e) {
      debugPrint('AlarmHistoryService: read failed: $e');
      return [];
    }
  }

  /// Call when Home opens. Repairs alarms, then uploads anything not yet
  /// reported. Quiet on failure — an offline phone or a backend that doesn't
  /// have the endpoint yet just means the events stay on the phone and are
  /// sent next time. Runs at most once every 10 minutes unless [force].
  static Future<void> repairAndSync({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastRun != null &&
        now.difference(_lastRun!) < const Duration(minutes: 10)) {
      return;
    }
    _lastRun = now;

    await _seedNativeStore();
    final all = await events();
    final pending = all.where((e) => !e.synced).toList();
    if (pending.isEmpty) return;

    // Oldest first, in batches, so one bad batch can't block the rest.
    pending.sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    for (var i = 0; i < pending.length; i += 50) {
      final batch =
          pending.sublist(i, i + 50 > pending.length ? pending.length : i + 50);
      try {
        final res = await ApiClient().safePost('/user/alarm-events', data: {
          'platform': 'android',
          'events': batch.map((e) => e.toServerJson()).toList(),
        });
        if (res != null && res['status'] != false) {
          await _historyChannel.invokeMethod('markAlarmEventsSynced', {
            'ids': batch.map((e) => e.localId).toList(),
          });
        } else {
          return; // endpoint missing or rejected — keep for next time
        }
      } catch (_) {
        return;
      }
    }
  }
}
