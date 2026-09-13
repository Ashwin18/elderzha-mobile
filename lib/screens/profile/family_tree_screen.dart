// lib/screens/profile/family_tree_screen.dart
//
// Dedicated, full-screen home for the family tree — reached from
// a "View full tree" entry point on the Family Members screen.
// Tapping any member opens a detail sheet showing their relation,
// birthday/anniversary with a "days until" countdown, and a
// "Send wishes" button that opens the phone's share sheet with a
// pre-filled message (WhatsApp among the options) — no WhatsApp
// API integration needed, just a standard OS share intent.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/services.dart';

class FamilyTreeScreen extends StatefulWidget {
  const FamilyTreeScreen({super.key});

  @override
  State<FamilyTreeScreen> createState() => _FamilyTreeScreenState();
}

// (row, emoji) per relation — same mapping used by the compact tree
// widget elsewhere, duplicated here since that file's helpers are
// library-private and this screen doesn't share a widget instance
// with it.
const Map<String, (int, String)> _relInfo = {
  'Father': (-1, '👨'),
  'Mother': (-1, '👩'),
  'Spouse': (0, '❤️'),
  'Son': (1, '👦'),
  'Daughter': (1, '👧'),
  'Son in law': (1, '👨'),
  'Daughter in law': (1, '👩'),
  'Grand Son': (2, '👦'),
  'Grand Daughter': (2, '👧'),
};

(int, String) _infoFor(String relation) => _relInfo[relation] ?? (0, '🧑');

class _FamilyTreeScreenState extends State<FamilyTreeScreen> {
  final _authService = AuthService();
  List _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _authService.getProfileWithFamily();
    if (!mounted) return;
    setState(() {
      _members = _extractFamily(res);
      _loading = false;
    });
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

  String _nameOf(dynamic m) => (m['name'] ?? '').toString();
  String _relationOf(dynamic m) {
    final r = m['relation'];
    if (r is Map) return (r['name'] ?? '').toString();
    return (r ?? '').toString();
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  // Next occurrence of this month/day, counting from today — used
  // for the "days until" countdown regardless of birth year.
  int? _daysUntil(DateTime? date) {
    if (date == null) return null;
    final now = DateTime.now();
    var next = DateTime(now.year, date.month, date.day);
    if (next.isBefore(DateTime(now.year, now.month, now.day))) {
      next = DateTime(now.year + 1, date.month, date.day);
    }
    return next.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  void _openDetail(dynamic m) {
    final name = _nameOf(m);
    final relation = _relationOf(m);
    final birthday = _parseDate(
        (m['birthday_date'] ?? m['birthday'] ?? m['dob'])?.toString());
    final anniversary =
        _parseDate((m['anniversary_date'] ?? m['anniversary'])?.toString());
    final birthdayDays = _daysUntil(birthday);
    final anniversaryDays = _daysUntil(anniversary);
    final info = _infoFor(relation);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE8E5DA), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Container(
            width: 76, height: 76,
            decoration: BoxDecoration(color: const Color(0xFFFFF3C4), shape: BoxShape.circle),
            child: Center(child: Text(info.$2, style: const TextStyle(fontSize: 36))),
          ),
          const SizedBox(height: 14),
          Text(name, style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w800, color: const Color(0xFF1A1726))),
          const SizedBox(height: 3),
          Text(relation, style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF8A8878))),
          const SizedBox(height: 20),
          if (birthday != null)
            _dateRow('🎂', 'Birthday', birthday, birthdayDays),
          if (birthday != null && anniversary != null) const SizedBox(height: 10),
          if (anniversary != null)
            _dateRow('💍', 'Anniversary', anniversary, anniversaryDays),
          if (birthday == null && anniversary == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No dates added yet', style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF8A8878))),
            ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: () => _sendWishes(name, birthdayDays, anniversaryDays),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(color: const Color(0xFF25D366), borderRadius: BorderRadius.circular(16)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.share_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text('Send wishes', style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _dateRow(String emoji, String label, DateTime date, int? daysUntil) {
    final dateStr = '${date.day}/${date.month}/${date.year}';
    final countdown = daysUntil == null
        ? ''
        : daysUntil == 0
            ? 'Today! 🎉'
            : daysUntil == 1
                ? 'Tomorrow'
                : 'In $daysUntil days';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFFFFF8DC), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$label · $dateStr', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF102A56))),
          ]),
        ),
        if (countdown.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: const Color(0xFFFFB800), borderRadius: BorderRadius.circular(999)),
            child: Text(countdown, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF102A56))),
          ),
      ]),
    );
  }

  void _sendWishes(String name, int? birthdayDays, int? anniversaryDays) {
    Navigator.pop(context);
    final isBirthdaySoonest =
        birthdayDays != null && (anniversaryDays == null || birthdayDays <= anniversaryDays);
    final message = isBirthdaySoonest
        ? 'Happy Birthday $name! 🎂 Wishing you a wonderful day filled with joy.'
        : 'Happy Anniversary $name! 💍 Wishing you many more years of happiness.';
    Share.share(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFBEA), Color(0xFFFFF3C4)],
          ),
        ),
        child: SafeArea(
          child: Stack(children: [
            // Soft decorative accents for a more premium feel
            const Positioned(top: 20, left: 24, child: Text('🍃', style: TextStyle(fontSize: 22))),
            const Positioned(top: 60, right: 30, child: Text('✦', style: TextStyle(fontSize: 16, color: Color(0xFFFFB800)))),
            const Positioned(bottom: 40, left: 30, child: Text('🍃', style: TextStyle(fontSize: 18))),
            Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
                child: Row(children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1726), size: 20),
                  ),
                  Expanded(
                    child: Text('Our Family Tree',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF1A1726))),
                  ),
                  const SizedBox(width: 40),
                ]),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _members.isEmpty
                        ? Center(
                            child: Text('No family members added yet',
                                style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF8A8878))),
                          )
                        : _buildTree(),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildTree() {
    final byRow = <int, List>{};
    for (final m in _members) {
      final row = _infoFor(_relationOf(m)).$1;
      byRow.putIfAbsent(row, () => []).add(m);
    }
    final rows = byRow.keys.toList()..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(children: [
        for (final row in rows) ...[
          Wrap(
            spacing: 18,
            runSpacing: 14,
            alignment: WrapAlignment.center,
            children: byRow[row]!.map((m) => _treeNode(m)).toList(),
          ),
          if (row != rows.last) Container(width: 2, height: 28, color: const Color(0xFFE8C766)),
        ],
      ]),
    );
  }

  Widget _treeNode(dynamic m) {
    final info = _infoFor(_relationOf(m));
    return GestureDetector(
      onTap: () => _openDetail(m),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE8C766), width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Center(child: Text(info.$2, style: const TextStyle(fontSize: 28))),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 74,
          child: Text(_nameOf(m),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1A1726))),
        ),
      ]),
    );
  }
}
