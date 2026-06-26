import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/models/fetch_profile_model.dart';
import '../api/models/reminderlist_model.dart';
import 'alarm_permission_service.dart';

const MethodChannel _familyEventAlarmChannel = MethodChannel('alarm_service');

class FamilyEventScheduler {
  static const String _storageKey = 'family_event_reminders';
  static const int _defaultHour = 9;
  static const int _defaultMinute = 0;
  static const Duration _sameDayGraceWindow = Duration(minutes: 2);

  static Future<void> syncFamilyEventReminders(
    List<FamilyMember> members,
  ) async {
    await AlarmPermissionService.ensureFullScreenIntentPermission();

    final prefs = await SharedPreferences.getInstance();
    final alarmTone = prefs.getString('alarm_tone') ?? '';
    final existingEntries = _decodeEntries(
      prefs.getStringList(_storageKey) ?? const <String>[],
    );
    final nextEntries = <Map<String, dynamic>>[];
    final nextKeys = <String>{};

    for (final member in members) {
      final entry = _buildEntry(member);
      if (entry == null) {
        continue;
      }

      nextEntries.add(entry);
      nextKeys.add(entry['key'] as String);

      await _familyEventAlarmChannel.invokeMethod('scheduleAlarm', {
        'id': entry['id'],
        'triggerAt': entry['triggerAt'],
        'title': entry['title'],
        'type': 'yearly',
        'date': entry['date'],
        'notes': entry['notes'],
        'soundUrl': alarmTone,
        'imageUrl': '',
        'badgeText': entry['badgeText'],
      });
    }

    for (final entry in existingEntries) {
      final key = entry['key'] as String?;
      final id = entry['id'] as int?;

      if (key == null || id == null || nextKeys.contains(key)) {
        continue;
      }

      await _familyEventAlarmChannel.invokeMethod('cancelAlarm', {'id': id});
    }

    await prefs.setStringList(
      _storageKey,
      nextEntries.map(jsonEncode).toList(growable: false),
    );
  }

  static Future<void> clearScheduledReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final existingEntries = _decodeEntries(
      prefs.getStringList(_storageKey) ?? const <String>[],
    );

    for (final entry in existingEntries) {
      final id = entry['id'] as int?;
      if (id == null) {
        continue;
      }

      await _familyEventAlarmChannel.invokeMethod('cancelAlarm', {'id': id});
    }

    await prefs.remove(_storageKey);
  }

  static Future<List<ReminderListDatum>> getStoredReminderItems() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = _decodeEntries(
      prefs.getStringList(_storageKey) ?? const <String>[],
    );

    final reminders = entries
        .map(_toReminderListDatum)
        .whereType<ReminderListDatum>()
        .toList(growable: false);

    reminders.sort(_compareReminderItems);
    return reminders;
  }

  static List<Map<String, dynamic>> _decodeEntries(List<String> rawEntries) {
    return rawEntries
        .map((item) => jsonDecode(item))
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry('$key', value)))
        .toList(growable: false);
  }

  static ReminderListDatum? _toReminderListDatum(Map<String, dynamic> entry) {
    final id = entry['id'];
    final triggerAt = entry['triggerAt'];
    final title = (entry['title'] ?? '').toString().trim();
    final date = (entry['date'] ?? '').toString().trim();
    final notes = (entry['notes'] ?? '').toString().trim();

    if (id is! int || triggerAt is! int || title.isEmpty || date.isEmpty) {
      return null;
    }

    final reminderDateTime = DateTime.fromMillisecondsSinceEpoch(triggerAt);

    return ReminderListDatum(
      id: id,
      title: title,
      date: date,
      time: DateFormat('HH:mm').format(reminderDateTime),
      notes: notes,
      uploadFile: '',
      status: '1',
    );
  }

  static int _compareReminderItems(ReminderListDatum a, ReminderListDatum b) {
    final aDateTime = _parseReminderDateTime(a);
    final bDateTime = _parseReminderDateTime(b);
    return aDateTime.compareTo(bDateTime);
  }

  static DateTime _parseReminderDateTime(ReminderListDatum reminder) {
    final datePart = _parseEventDate(reminder.date) ?? DateTime.now();
    final timeParts = reminder.time.split(':');
    final hour = timeParts.isNotEmpty ? int.tryParse(timeParts[0]) ?? 0 : 0;
    final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;

    return DateTime(datePart.year, datePart.month, datePart.day, hour, minute);
  }

  static Map<String, dynamic>? _buildEntry(FamilyMember member) {
    final eventName = member.event.name.trim();
    final normalizedEvent = eventName.toLowerCase();
    final relationName = member.relation.name.trim();
    final normalizedRelation = relationName.toLowerCase();

    if (!_isSupportedEvent(normalizedEvent)) {
      return null;
    }

    final originalDate = _parseEventDate(member.eventDate);
    if (originalDate == null) {
      return null;
    }

    final nextOccurrence = _nextOccurrence(originalDate);
    final displayName =
        member.name.trim().isEmpty ? 'Family Member' : member.name.trim();
    final eventLabel =
        normalizedEvent.contains('anniversary') ? 'Anniversary' : 'Birthday';
    final reminderCopy = _buildReminderCopy(
      normalizedRelation,
      normalizedEvent,
      displayName,
      relationName,
    );
    final badgeText = '$eventLabel Reminder';
    final id = _stableId(
      '${member.id}:${member.event.id}:${reminderCopy['eventKey']}',
    );

    return {
      'key': '${member.id}:${member.event.id}',
      'id': id,
      'triggerAt': nextOccurrence.millisecondsSinceEpoch,
      'title': reminderCopy['title'],
      'date': DateFormat('yyyy-MM-dd').format(nextOccurrence),
      'notes': reminderCopy['notes'],
      'soundUrl': '',
      'badgeText': badgeText,
    };
  }

  static Map<String, String> _buildReminderCopy(
    String normalizedRelation,
    String normalizedEvent,
    String displayName,
    String relationName,
  ) {
    final eventLabel =
        normalizedEvent.contains('anniversary') ? 'Anniversary' : 'Birthday';

    if (normalizedEvent.contains('anniversary')) {
      return {
        'eventKey': 'anniversary',
        'title': 'Wedding Anniversary',
        'notes':
            "Don't forget! Today is your wedding anniversary - make it special.",
      };
    }

    if (normalizedRelation == 'self' && normalizedEvent.contains('birth')) {
      return {
        'eventKey': 'birthday',
        'title': 'My Birthday',
        'notes': "Don't forget! Today is your birthday - make it special.",
      };
    }

    if ((normalizedRelation == 'spouse' ||
            normalizedRelation == 'husband' ||
            normalizedRelation == 'wife') &&
        normalizedEvent.contains('birth')) {
      final spouseLabel =
          relationName.trim().isEmpty ? 'Spouse' : relationName.trim();
      return {
        'eventKey': 'birthday',
        'title': "$spouseLabel's Birthday",
        'notes':
            "Don't forget! Today is your $spouseLabel's birthday - make it special.",
      };
    }

    final lowerEventLabel = eventLabel.toLowerCase();
    return {
      'eventKey': lowerEventLabel,
      'title': "$displayName's $eventLabel",
      'notes':
          "Don't forget! It's $displayName's $lowerEventLabel today - make it special.",
    };
  }

  static bool _isSupportedEvent(String normalizedEvent) {
    return normalizedEvent.contains('birth') ||
        normalizedEvent.contains('anniversary');
  }

  static DateTime? _parseEventDate(String rawDate) {
    final value = rawDate.trim();
    if (value.isEmpty) {
      return null;
    }

    const patterns = <String>[
      'dd-MM-yyyy',
      'yyyy-MM-dd',
      'dd/MM/yyyy',
      'yyyy/MM/dd',
      'dd MMM yyyy',
      'd MMM yyyy',
      'dd MMMM yyyy',
      'd MMMM yyyy',
    ];

    for (final pattern in patterns) {
      try {
        return DateFormat(pattern).parseStrict(value);
      } catch (_) {
        continue;
      }
    }

    return DateTime.tryParse(value);
  }

  static DateTime _nextOccurrence(DateTime originalDate) {
    final now = DateTime.now();
    var candidate = _occurrenceForYear(
      originalDate.month,
      originalDate.day,
      now.year,
    );

    candidate = DateTime(
      candidate.year,
      candidate.month,
      candidate.day,
      _defaultHour,
      _defaultMinute,
    );

    if (!candidate.isAfter(now)) {
      final isSameDay = candidate.year == now.year &&
          candidate.month == now.month &&
          candidate.day == now.day;
      final isWithinGraceWindow =
          isSameDay && now.difference(candidate) <= _sameDayGraceWindow;

      if (isWithinGraceWindow) {
        final fallback = now.add(const Duration(seconds: 15));
        return DateTime(
          fallback.year,
          fallback.month,
          fallback.day,
          fallback.hour,
          fallback.minute,
          fallback.second,
          fallback.millisecond,
          fallback.microsecond,
        );
      }

      final nextYear = _occurrenceForYear(
        originalDate.month,
        originalDate.day,
        now.year + 1,
      );

      return DateTime(
        nextYear.year,
        nextYear.month,
        nextYear.day,
        _defaultHour,
        _defaultMinute,
      );
    }

    return candidate;
  }

  static DateTime _occurrenceForYear(int month, int day, int year) {
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    final safeDay = day > lastDayOfMonth ? lastDayOfMonth : day;
    return DateTime(year, month, safeDay);
  }

  static int _stableId(String input) {
    var hash = 0x811C9DC5;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
