// lib/screens/profile/family_tree_screen.dart
//
// Dedicated, full-screen home for the family tree — reached from
// a "View full tree" entry point on the Family Members screen.
//
// Rebuilt (Sep 2026) as a proper top-down hierarchical tree, native
// widgets + CustomPainter only, no background image: You & your
// Spouse on top, your Children below them, your Grandchildren below
// that — with connecting lines showing marriage (a horizontal line
// between spouses) and parent-child descent (a trunk-and-branch line
// dropping from each row's center down into the row below). Parents
// (Father/Mother), if the user has added them, appear as a smaller
// row above "You" specifically. Tapping any member still opens the
// same detail sheet as before (relation, birthday/anniversary
// countdown, "Send wishes").
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/auth_provider.dart';
import '../../services/services.dart';

// ── Theme (matches the rest of the app — gold/navy/cream, not the
// green tones from an earlier one-off client reference) ───────────
abstract final class _T {
  static const gold = Color(0xFFFFB800);
  static const goldDeep = Color(0xFFB8860B);
  static const ink = Color(0xFF1A1726);
  static const txm = Color(0xFF8A8878);
  static const cream1 = Color(0xFFFFFBEA);
  static const cream2 = Color(0xFFFFF3C4);
  static const purple = Color(0xFF8B6FE8);
  static const pink = Color(0xFFEE6B9E);
  static const green = Color(0xFF4E9E3C);
  static const orange = Color(0xFFEF9F27);
}

// (generation, emoji, accent color) per relation. Generation is
// relative to "You" at 0: negative = older (parents), positive =
// younger (children, grandchildren).
class _RelInfo {
  final int gen;
  final String emoji;
  final Color color;
  const _RelInfo(this.gen, this.emoji, this.color);
}

const Map<String, _RelInfo> _relInfo = {
  'Father': _RelInfo(-1, '👨', _T.orange),
  'Mother': _RelInfo(-1, '👩', _T.orange),
  'Spouse': _RelInfo(0, '❤️', _T.gold),
  'Son': _RelInfo(1, '👦', _T.purple),
  'Daughter': _RelInfo(1, '👧', _T.purple),
  'Son in law': _RelInfo(1, '👨', _T.purple),
  'Daughter in law': _RelInfo(1, '👩', _T.purple),
  // Backend stores these with hyphens (family_member_table), while
  // the UI chip list uses spaces — alias both spellings so this
  // lookup matches regardless of which one the API actually returns.
  'Son-in-law': _RelInfo(1, '👨', _T.purple),
  'Daughter-in-law': _RelInfo(1, '👩', _T.purple),
  'Grand Son': _RelInfo(2, '👦', _T.pink),
  'Grand Daughter': _RelInfo(2, '👧', _T.pink),
};

_RelInfo _infoFor(String relation) => _relInfo[relation] ?? const _RelInfo(1, '🧑', _T.purple);

// One node on the tree — either a real family member or the
// synthetic "You" node representing the logged-in user.
class _Node {
  final String name;
  final String relationLabel;
  final String emoji;
  final Color color;
  final int gen;
  final bool isYou;
  final dynamic raw;
  const _Node({
    required this.name,
    required this.relationLabel,
    required this.emoji,
    required this.color,
    required this.gen,
    this.isYou = false,
    this.raw,
  });
}

class FamilyTreeScreen extends StatefulWidget {
  const FamilyTreeScreen({super.key});

  @override
  State<FamilyTreeScreen> createState() => _FamilyTreeScreenState();
}

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

  void _openDetail(_Node node) {
    if (node.isYou) return; // nothing to show for the user's own node
    final m = node.raw;
    final birthday = _parseDate(
        (m['birthday_date'] ?? m['birthday'] ?? m['dob'])?.toString());
    final anniversary =
        _parseDate((m['anniversary_date'] ?? m['anniversary'])?.toString());
    final birthdayDays = _daysUntil(birthday);
    final anniversaryDays = _daysUntil(anniversary);

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
            decoration: BoxDecoration(color: node.color.withOpacity(.18), shape: BoxShape.circle),
            child: Center(child: Text(node.emoji, style: const TextStyle(fontSize: 36))),
          ),
          const SizedBox(height: 14),
          Text(node.name, style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w800, color: _T.ink)),
          const SizedBox(height: 3),
          Text(node.relationLabel, style: GoogleFonts.poppins(fontSize: 13, color: _T.txm)),
          const SizedBox(height: 20),
          if (birthday != null)
            _dateRow('🎂', 'Birthday', birthday, birthdayDays),
          if (birthday != null && anniversary != null) const SizedBox(height: 10),
          if (anniversary != null)
            _dateRow('💍', 'Anniversary', anniversary, anniversaryDays),
          if (birthday == null && anniversary == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No dates added yet', style: GoogleFonts.poppins(fontSize: 12.5, color: _T.txm)),
            ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: () => _sendWishes(node.name, birthdayDays, anniversaryDays),
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
            decoration: BoxDecoration(color: _T.gold, borderRadius: BorderRadius.circular(999)),
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
    final userName = context.watch<AuthProvider>().userName;
    return Scaffold(
      body: Container(
        // A soft gold-to-white wash instead of the old flat pale-yellow
        // fill — the flat version sat so close in tone to the gold
        // avatar rings and "You" node that everything on the page read
        // as one undifferentiated yellow. This keeps the gold accent up
        // top (matching the app's own header gradient elsewhere) and
        // eases into a calm off-white lower down, so the tree itself —
        // avatars, cards, connecting lines — has a bit of contrast to
        // sit on.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.32, 0.6, 1.0],
            colors: [
              Color(0xFFFFE7A0),
              Color(0xFFFFF3D0),
              Color(0xFFFBFAF6),
              Color(0xFFFAFAF8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
              child: Row(children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _T.ink, size: 20),
                ),
                Expanded(
                  child: Text('Our Family Tree',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: _T.ink)),
                ),
                const SizedBox(width: 40),
              ]),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _T.gold))
                  : _buildTree(userName),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildTree(String userName) {
    // Build the "You" node plus every real member, then bucket by
    // generation so each row of the tree is easy to lay out.
    final you = _Node(
      name: userName,
      relationLabel: 'You',
      emoji: '😊',
      color: _T.gold,
      gen: 0,
      isYou: true,
    );
    // The backend's own member list can include the logged-in user
    // themselves (relation "Self") alongside their actual relatives —
    // without filtering that out here, it renders as a second circle
    // for the same person right next to the "You" node built above,
    // both saying the same thing. "You" already covers it.
    final memberNodes = _members
        .where((m) => _relationOf(m).trim().toLowerCase() != 'self')
        .map((m) {
      final relation = _relationOf(m);
      final info = _infoFor(relation);
      return _Node(
        name: _nameOf(m),
        relationLabel: relation,
        emoji: info.emoji,
        color: info.color,
        gen: info.gen,
        raw: m,
      );
    }).toList();

    final byGen = <int, List<_Node>>{};
    byGen.putIfAbsent(0, () => []).add(you);
    for (final n in memberNodes) {
      byGen.putIfAbsent(n.gen, () => []).add(n);
    }
    // "You" always first in its row, so the marriage line reliably
    // connects to the very first node.
    byGen[0]!.sort((a, b) => a.isYou ? -1 : (b.isYou ? 1 : 0));

    final gensPresent = byGen.keys.toList()..sort();

    return _TreeCanvas(
      rows: [for (final g in gensPresent) byGen[g]!],
      onTapNode: _openDetail,
    );
  }
}

// Lays out each generation as a horizontally-centered row of nodes
// and paints the connecting lines between rows itself, using the
// exact same coordinate math it uses to position the node widgets —
// so the lines always meet the avatars precisely without needing
// runtime widget measurement.
class _TreeCanvas extends StatelessWidget {
  const _TreeCanvas({required this.rows, required this.onTapNode});
  final List<List<_Node>> rows;
  final void Function(_Node) onTapNode;

  static const double _avatarSize = 62;
  static const double _nodeWidth = 78;
  static const double _nodeGap = 14;
  static const double _rowHeight = 128;
  static const double _topPad = 26;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final rowWidths = rows
          .map((r) => r.length * _nodeWidth + (r.length - 1) * _nodeGap)
          .toList();
      final maxRowWidth = rowWidths.isEmpty
          ? width
          : rowWidths.reduce((a, b) => a > b ? a : b).clamp(width, double.infinity);
      final canvasWidth = maxRowWidth < width ? width : maxRowWidth;
      final canvasHeight = _topPad * 2 + rows.length * _rowHeight;

      // Precompute each node's center point (x, y) for line-drawing.
      final centers = <List<Offset>>[];
      for (var ri = 0; ri < rows.length; ri++) {
        final row = rows[ri];
        final rowWidth = rowWidths[ri];
        final startX = (canvasWidth - rowWidth) / 2 + _nodeWidth / 2;
        final y = _topPad + ri * _rowHeight + _avatarSize / 2;
        centers.add([
          for (var i = 0; i < row.length; i++)
            Offset(startX + i * (_nodeWidth + _nodeGap), y),
        ]);
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            width: canvasWidth,
            height: canvasHeight,
            child: Stack(children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _TreeLinesPainter(rows: rows, centers: centers),
                ),
              ),
              for (var ri = 0; ri < rows.length; ri++)
                for (var i = 0; i < rows[ri].length; i++)
                  Positioned(
                    left: centers[ri][i].dx - _nodeWidth / 2,
                    top: centers[ri][i].dy - _avatarSize / 2,
                    width: _nodeWidth,
                    child: _TreeAvatar(
                      node: rows[ri][i],
                      size: _avatarSize,
                      onTap: () => onTapNode(rows[ri][i]),
                    ),
                  ),
            ]),
          ),
        ),
      );
    });
  }
}

class _TreeAvatar extends StatelessWidget {
  const _TreeAvatar({required this.node, required this.size, required this.onTap});
  final _Node node;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: node.color.withOpacity(node.isYou ? 1 : .16),
            shape: BoxShape.circle,
            border: Border.all(
              color: node.isYou ? _T.goldDeep : node.color,
              width: node.isYou ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Center(
            child: Text(node.emoji, style: TextStyle(fontSize: size * 0.42)),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 76,
          child: Text(node.name.isEmpty ? node.relationLabel : node.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w800, color: _T.ink)),
        ),
        SizedBox(
          width: 76,
          child: Text(node.relationLabel,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: _T.txm)),
        ),
      ]),
    );
  }
}

// Draws: a horizontal "marriage" line between You and Spouse when
// both are in the same (generation-0) row, and a trunk-and-branch
// connector — vertical stem down from a row's center, a horizontal
// bar, then vertical drops into each node of the row below — between
// every pair of adjacent generation rows.
class _TreeLinesPainter extends CustomPainter {
  _TreeLinesPainter({required this.rows, required this.centers});
  final List<List<_Node>> rows;
  final List<List<Offset>> centers;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFE8C766)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var ri = 0; ri < rows.length; ri++) {
      final row = rows[ri];
      final rowCenters = centers[ri];

      // Marriage line — connects "You" and a Spouse sitting in the
      // same row, with a small heart marker at the midpoint.
      if (row.length >= 2) {
        final youIdx = row.indexWhere((n) => n.isYou);
        final spouseIdx = row.indexWhere((n) => n.relationLabel == 'Spouse');
        if (youIdx != -1 && spouseIdx != -1) {
          final a = rowCenters[youIdx];
          final b = rowCenters[spouseIdx];
          canvas.drawLine(a, b, linePaint);
          final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
          _drawHeart(canvas, mid);
        }
      }

      // Descent to the next row down, if any.
      if (ri + 1 >= rows.length) continue;
      final nextRow = rows[ri + 1];
      final nextCenters = centers[ri + 1];
      if (nextCenters.isEmpty) continue;

      // Parents (gen -1) connect only to "You" specifically in the row
      // below, not to the Spouse sitting next to "You" — every other
      // pair connects the whole row down to the whole row below, since
      // the flat member data has no explicit per-child parent linkage
      // to be more precise than that.
      final isParentsRow = row.isNotEmpty && row.first.gen < 0;
      List<Offset> targets = nextCenters;
      if (isParentsRow) {
        final youIdxNext = nextRow.indexWhere((n) => n.isYou);
        if (youIdxNext != -1) targets = [nextCenters[youIdxNext]];
      }
      final fromX = rowCenters.map((c) => c.dx).reduce((a, b) => a + b) / rowCenters.length;
      final fromY = rowCenters.first.dy;
      final toY = nextCenters.first.dy;
      final stemBottom = fromY + (toY - fromY) * 0.42;

      // Stem down from this row's center.
      canvas.drawLine(Offset(fromX, fromY + 30), Offset(fromX, stemBottom), linePaint);

      if (targets.length == 1) {
        // Single target — just continue straight down to it.
        canvas.drawLine(Offset(fromX, stemBottom), Offset(targets.first.dx, toY - 30), linePaint);
        continue;
      }

      final minX = targets.map((c) => c.dx).reduce((a, b) => a < b ? a : b);
      final maxX = targets.map((c) => c.dx).reduce((a, b) => a > b ? a : b);
      canvas.drawLine(Offset(minX, stemBottom), Offset(maxX, stemBottom), linePaint);
      for (final c in targets) {
        canvas.drawLine(Offset(c.dx, stemBottom), Offset(c.dx, toY - 30), linePaint);
      }
    }
  }

  void _drawHeart(Canvas canvas, Offset center) {
    final paint = Paint()..color = _T.pink;
    const s = 7.0;
    final path = Path()
      ..moveTo(center.dx, center.dy + s * 0.6)
      ..cubicTo(center.dx - s * 1.4, center.dy - s * 0.6, center.dx - s * 0.4, center.dy - s * 1.3,
          center.dx, center.dy - s * 0.4)
      ..cubicTo(center.dx + s * 0.4, center.dy - s * 1.3, center.dx + s * 1.4, center.dy - s * 0.6,
          center.dx, center.dy + s * 0.6)
      ..close();
    // White backing so the heart reads clearly over the line.
    canvas.drawCircle(center, s * 1.5, Paint()..color = Colors.white);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TreeLinesPainter oldDelegate) => true;
}
