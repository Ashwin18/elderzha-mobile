import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/services.dart';
import '../../alaram/family_event_scheduler.dart';
import '../../api/models/fetch_profile_model.dart' show FamilyMember, Event;
import '../../widgets/yellow_header_scaffold.dart';

class FamilyMembersScreen extends StatefulWidget {
  const FamilyMembersScreen({super.key});
  @override
  State<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends State<FamilyMembersScreen> {
  final _authService = AuthService();
  List _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _authService.getProfileWithFamily();
    final fallback = await _loadSetupFamilyFallback();
    if (!mounted) return;
    final family = _mergeFamily(_extractFamily(res), fallback);
    setState(() {
      _members = family;
      _loading = false;
    });
    // Re-schedule family event alarms whenever family list updates
    _rescheduleFamilyAlarms(family);
  }

  List _extractFamily(Map<String, dynamic>? res) {
    if (res == null) return [];
    final candidates = [
      res['family'],
      res['members'],
      res['family_members'],
      res['data'] is Map ? res['data']['family'] : null,
      res['data'] is Map ? res['data']['members'] : null,
      res['data'] is Map ? res['data']['family_members'] : null,
      res['data'] is Map && res['data']['user'] is Map
          ? res['data']['user']['family']
          : null,
      res['data'] is Map && res['data']['profile'] is Map
          ? res['data']['profile']['family']
          : null,
    ];
    for (final value in candidates) {
      if (value is List) return value;
      if (value is Map) {
        for (final key in ['data', 'items', 'list', 'members']) {
          final nested = value[key];
          if (nested is List) return nested;
        }
      }
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _loadSetupFamilyFallback() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('setup_family_members');
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  List _mergeFamily(List remote, List<Map<String, dynamic>> fallback) {
    if (fallback.isEmpty) return remote;
    final seen = <String>{};
    final out = <dynamic>[];
    for (final item in [...remote, ...fallback]) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final key = [
        (map['id'] ?? '').toString(),
        (map['name'] ?? '').toString().toLowerCase().trim(),
        (map['relation'] is Map
                ? map['relation']['name']
                : map['relation'] ?? '')
            .toString()
            .toLowerCase()
            .trim(),
        _birthdayDateOf(map),
        _anniversaryDateOf(map),
      ].join('|');
      if (seen.add(key)) out.add(map);
    }
    return out;
  }

  String _eventTypeOf(dynamic m) {
    if (m is! Map) return 'birthday';
    final raw = m['event_type'] ??
        m['type'] ??
        (m['event'] is Map ? m['event']['name'] : null) ??
        m['event_name'];
    final text = raw?.toString().toLowerCase().trim() ?? '';
    return text.contains('anniversary') ? 'anniversary' : 'birthday';
  }

  String _birthdayDateOf(Map m) {
    final direct = (m['birthday_date'] ?? m['birthday'] ?? m['dob'] ?? '')
        .toString()
        .trim();
    if (direct.isNotEmpty && direct.toLowerCase() != 'null') return direct;
    final eventType = _eventTypeOf(m);
    if (eventType == 'birthday') {
      return (m['date'] ?? m['event_date'] ?? '').toString();
    }
    return '';
  }

  String _anniversaryDateOf(Map m) {
    final direct =
        (m['anniversary_date'] ?? m['anniversary'] ?? '').toString().trim();
    if (direct.isNotEmpty && direct.toLowerCase() != 'null') return direct;
    final raw = (m['event_type'] ?? m['type'] ?? '').toString().toLowerCase();
    if (raw.contains('anniversary')) {
      return (m['date'] ?? m['event_date'] ?? '').toString();
    }
    return '';
  }

  Future<void> _delete(int id) async {
    final member = _members.firstWhere(
      (m) => m is Map && (int.tryParse((m['id'] ?? 0).toString()) ?? 0) == id,
      orElse: () => null,
    );
    if (id > 0) await _authService.deleteFamily(id);
    if (member is Map)
      await _removeLocalFamily(Map<String, dynamic>.from(member));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Deleted!', style: GoogleFonts.poppins()),
        backgroundColor: AppColors.green,
        duration: const Duration(seconds: 1)));
    _load();
  }

  Future<void> _removeLocalFamily(Map<String, dynamic> member) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('setup_family_members');
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final localId = member['local_id']?.toString();
      final id = member['id']?.toString();
      final name = member['name']?.toString().toLowerCase().trim();
      final relation = member['relation'] is Map
          ? member['relation']['name']?.toString().toLowerCase().trim()
          : member['relation']?.toString().toLowerCase().trim();
      final remaining = decoded.where((item) {
        if (item is! Map) return true;
        if (localId != null && item['local_id']?.toString() == localId) {
          return false;
        }
        if (id != null && item['id']?.toString() == id) return false;
        final sameName = item['name']?.toString().toLowerCase().trim() == name;
        final itemRelation = item['relation'] is Map
            ? item['relation']['name']?.toString().toLowerCase().trim()
            : item['relation']?.toString().toLowerCase().trim();
        return !(sameName && itemRelation == relation);
      }).toList();
      await prefs.setString('setup_family_members', jsonEncode(remaining));
    } catch (_) {}
  }

  Future<void> _rescheduleFamilyAlarms(List family) async {
    final reminders = <FamilyMember>[];
    for (final item in family) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final relationName = m['relation'] is Map
          ? (m['relation']['name'] ?? '')
          : (m['relation']?.toString() ?? '');
      final baseId = m['id']?.toString() ?? '0';
      final name = m['name']?.toString() ?? '';
      final status = m['status']?.toString() ?? '1';

      void add(String suffix, String eventName, String date) {
        if (date.trim().isEmpty) return;
        reminders.add(FamilyMember(
          id: '$baseId-$suffix',
          type: m['type']?.toString() ?? '',
          status: status,
          name: name,
          eventDate: date,
          relation: Event(id: '0', name: relationName),
          event: Event(id: '0', name: eventName),
        ));
      }

      add('birthday', 'Birthday', _birthdayDateOf(m));
      add('anniversary', 'Anniversary', _anniversaryDateOf(m));
    }

    await FamilyEventScheduler.syncFamilyEventReminders(reminders);
  }

  @override
  Widget build(BuildContext context) {
    return YellowHeaderScaffold(
      headerHeight: 140,
      headerContent: Padding(
        padding: const EdgeInsets.fromLTRB(18, 48, 18, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Family members',
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          Text('Birthdays & anniversaries auto-reminded yearly',
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.yellowDeep,
                  fontWeight: FontWeight.w500)),
        ]),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.yellowDark))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Add button
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/add-member')
                          .then((_) => _load()),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                            color: AppColors.yellow,
                            borderRadius: BorderRadius.circular(14)),
                        child: Center(
                            child: Text('+ Add family member',
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink))),
                      ),
                    ),

                    if (_members.isNotEmpty) ...[
                      _secHeader(Icons.people_rounded,
                          'Family members (${_members.length})'),
                      _memberList(_members),
                      const SizedBox(height: 4),
                    ],

                    if (_members.isEmpty)
                      Center(
                          child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Column(children: [
                          const Text('👨‍👩‍👧',
                              style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 8),
                          Text('No family members added yet',
                              style: GoogleFonts.poppins(
                                  fontSize: 14, color: AppColors.inkMuted)),
                        ]),
                      )),

                    // Info banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: AppColors.yellowSoft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.yellowLight)),
                      child: Row(children: [
                        const Text('🔔', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('Auto reminders enabled',
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.yellowDeep)),
                              Text(
                                  "You'll be reminded 1 day before every birthday and anniversary",
                                  style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppColors.yellowDark)),
                            ])),
                      ]),
                    ),
                  ]),
            ),
    );
  }

  Widget _secHeader(IconData icon, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, size: 14, color: AppColors.yellowDark),
          const SizedBox(width: 6),
          Text(label.toUpperCase(),
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkLight,
                  letterSpacing: 0.8)),
        ]),
      );

  Widget _memberList(List members) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border)),
      child: Column(
        children: members.asMap().entries.map((e) {
          final m = e.value;
          final map = m is Map ? Map<String, dynamic>.from(m) : {};
          final name = map['name']?.toString() ?? '';
          final relation = map['relation'] is Map
              ? (map['relation']['name']?.toString() ?? '')
              : (map['relation']?.toString() ?? '');
          final birthday = _birthdayDateOf(map);
          final anniversary = _anniversaryDateOf(map);
          final isLast = e.key == members.length - 1;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: AppColors.yellowSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                      child: name.isNotEmpty
                          ? Text(name[0].toUpperCase(),
                              style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.yellowDeep))
                          : const Text('👤', style: TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(name,
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink)),
                      if (relation.isNotEmpty)
                        Text(relation,
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: AppColors.inkMuted)),
                      const SizedBox(height: 5),
                      Wrap(spacing: 6, runSpacing: 5, children: [
                        if (birthday.isNotEmpty)
                          _datePill('🎂 Birthday · $birthday',
                              const Color(0xFFFCE4EC), const Color(0xFFC2185B)),
                        if (anniversary.isNotEmpty)
                          _datePill('💍 Anniversary · $anniversary',
                              AppColors.purpleLight, AppColors.purple),
                      ]),
                    ])),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/add-member',
                          arguments: map)
                      .then((_) => _load()),
                  child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                          color: AppColors.bgMuted,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.edit_outlined,
                          size: 14, color: AppColors.inkMuted)),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _delete(map['id'] ?? 0),
                  child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                          color: AppColors.redLight,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.delete_outline_rounded,
                          size: 14, color: AppColors.red)),
                ),
              ]),
            ),
            if (!isLast) const Divider(height: 1, indent: 14, endIndent: 14),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _datePill(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
      );
}
