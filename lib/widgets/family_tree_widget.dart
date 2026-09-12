import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

// ── Relationship → generation row + display data ──────────────
// Row: negative = above you (older generation), 0 = same row,
// positive = below you (younger generation). Used both for the
// compact tree's vertical placement and to group the expanded
// view's sections.
class _RelInfo {
  final int row;
  final String emoji;
  final String group;
  const _RelInfo(this.row, this.emoji, this.group);
}

const Map<String, _RelInfo> _relInfo = {
  'Father': _RelInfo(-1, '👨', 'Parents'),
  'Mother': _RelInfo(-1, '👩', 'Parents'),
  'Spouse': _RelInfo(0, '❤️', 'Your generation'),
  'Son': _RelInfo(1, '👦', 'Children'),
  'Daughter': _RelInfo(1, '👧', 'Children'),
  'Son in law': _RelInfo(1, '👨', 'Children'),
  'Daughter in law': _RelInfo(1, '👩', 'Children'),
  'Grand Son': _RelInfo(2, '👦', 'Grandchildren'),
  'Grand Daughter': _RelInfo(2, '👧', 'Grandchildren'),
};

// Fixed generation order for the expanded view's section list.
const List<String> _groupOrder = [
  'Parents',
  'Your generation',
  'Children',
  'Grandchildren',
];

_RelInfo _infoFor(String relation) =>
    _relInfo[relation] ?? const _RelInfo(0, '🧑', 'Other');

// Color per generation row, close-to-far from "You" at row 0.
Color _rowColor(int row) {
  switch (row) {
    case -2:
      return const Color(0xFFF5C97A); // grandparents - warm gold
    case -1:
      return const Color(0xFFF0997B); // parents - coral
    case 0:
      return const Color(0xFF9FE1CB); // your generation - teal
    case 1:
      return const Color(0xFFB5D4F4); // children - blue
    case 2:
      return const Color(0xFFB5D4F4); // grandchildren - blue too
    default:
      return C.bg2;
  }
}

Color _rowBorder(int row) {
  switch (row) {
    case -2:
      return const Color(0xFFBA7517);
    case -1:
      return const Color(0xFF993C1D);
    case 0:
      return const Color(0xFF0F6E56);
    case 1:
    case 2:
      return const Color(0xFF185FA5);
    default:
      return C.bd;
  }
}

class FamilyTreeWidget extends StatefulWidget {
  const FamilyTreeWidget({super.key, required this.members});
  final List members;

  @override
  State<FamilyTreeWidget> createState() => _FamilyTreeWidgetState();
}

class _FamilyTreeWidgetState extends State<FamilyTreeWidget> {
  bool _expanded = false;

  String _nameOf(dynamic m) => (m['name'] ?? '').toString();
  String _relationOf(dynamic m) {
    final r = m['relation'];
    if (r is Map) return (r['name'] ?? '').toString();
    return (r ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    // Compact view only shows the closest relations, to keep the
    // default view calm even for a large extended family.
    const closeRelations = {'Spouse', 'Son', 'Daughter', 'Father', 'Mother'};
    final closeMembers =
        widget.members.where((m) => closeRelations.contains(_relationOf(m))).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFBEA), Color(0xFFFFF3C4)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: _expanded
            ? _buildExpanded(context)
            : _buildCompact(context, closeMembers),
      ),
    );
  }

  Widget _buildCompact(BuildContext context, List closeMembers) {
    return Column(
      key: const ValueKey('compact'),
      children: [
        SizedBox(
          height: 210,
          child: CustomPaint(
            painter: _TreeLinesPainter(closeMembers, _relationOf),
            child: Stack(children: [
              // "You" node, centered
              Positioned(
                left: 0,
                right: 0,
                top: 80,
                child: Center(child: _node('You', '😊', C.yellow, C.ink, radius: 34)),
              ),
              ..._layoutCompactNodes(closeMembers),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => setState(() => _expanded = true),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: C.ink,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Center(
              child: Text('Show full family · ${widget.members.length}',
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w700, color: C.yellow)),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _layoutCompactNodes(List members) {
    // Group members by row, then space them evenly left-right within that row.
    final byRow = <int, List>{};
    for (final m in members) {
      final row = _infoFor(_relationOf(m)).row;
      byRow.putIfAbsent(row, () => []).add(m);
    }
    final widgets = <Widget>[];
    byRow.forEach((row, rowMembers) {
      final y = 105.0 + row * 70.0; // 0 row centered at "You"'s y
      final count = rowMembers.length;
      for (var i = 0; i < count; i++) {
        final m = rowMembers[i];
        final info = _infoFor(_relationOf(m));
        final offset = (i - (count - 1) / 2) * 80.0;
        widgets.add(Positioned(
          top: y - 26,
          left: 0,
          right: 0,
          child: Center(
            child: Transform.translate(
              offset: Offset(offset, 0),
              child: _node(_nameOf(m), info.emoji, _rowColor(info.row), _rowBorder(info.row)),
            ),
          ),
        ));
      }
    });
    return widgets;
  }

  Widget _node(String name, String emoji, Color bg, Color border, {double radius = 26}) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: border, width: 1.5),
        ),
        child: Center(child: Text(emoji, style: TextStyle(fontSize: radius * 0.75))),
      ),
      const SizedBox(height: 3),
      SizedBox(
        width: 64,
        child: Text(name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w600, color: border)),
      ),
    ]);
  }

  Widget _buildExpanded(BuildContext context) {
    final byGroup = <String, List>{};
    for (final m in widget.members) {
      final info = _infoFor(_relationOf(m));
      byGroup.putIfAbsent(info.group, () => []).add(m);
    }

    return Column(
      key: const ValueKey('expanded'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text('Full family',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: C.ink)),
          ),
          GestureDetector(
            onTap: () => setState(() => _expanded = false),
            child: Icon(Icons.close_rounded, size: 20, color: C.txm),
          ),
        ]),
        const SizedBox(height: 10),
        ..._groupOrder.where((g) => byGroup.containsKey(g)).map((group) {
          final members = byGroup[group]!;
          final row = _infoFor(_relationOf(members.first)).row;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(group.toUpperCase(),
                  style: GoogleFonts.poppins(
                      fontSize: 10, fontWeight: FontWeight.w700, color: _rowBorder(row))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 10,
                children: members.map((m) {
                  final info = _infoFor(_relationOf(m));
                  return _node(_nameOf(m), info.emoji, _rowColor(info.row), _rowBorder(info.row),
                      radius: 24);
                }).toList(),
              ),
            ]),
          );
        }),
      ],
    );
  }
}

class _TreeLinesPainter extends CustomPainter {
  _TreeLinesPainter(this.members, this.relationOf);
  final List members;
  final String Function(dynamic) relationOf;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE8C766)
      ..strokeWidth = 2;
    final youCenter = Offset(size.width / 2, 105);
    for (final m in members) {
      final info = _infoFor(relationOf(m));
      final y = 105.0 + info.row * 70.0;
      canvas.drawLine(youCenter, Offset(size.width / 2, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TreeLinesPainter oldDelegate) => true;
}
