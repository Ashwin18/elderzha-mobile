// Small date helpers shared by the Early Bird screens.
const List<String> _ezMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "2026-11-16" -> a local DateTime at midnight, or null.
DateTime? parseYmd(dynamic v) {
  final t = v?.toString() ?? '';
  if (t.length < 10 || t == 'null') return null;
  final d = DateTime.tryParse(t.substring(0, 10));
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

/// 16 Nov 2026
String fmtDay(DateTime d) => '${d.day} ${_ezMonths[d.month - 1]} ${d.year}';

/// 16 Nov (no year)
String fmtDayShort(DateTime d) => '${d.day} ${_ezMonths[d.month - 1]}';
