import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../alaram/alarm_history_service.dart';
import '../../theme/app_theme.dart';

/// Profile > Alarm history. Shows, for every reminder that was due, whether
/// it rang or was missed — and lets the user repair alarms in one tap.
class AlarmHistoryScreen extends StatefulWidget {
  const AlarmHistoryScreen({super.key});

  @override
  State<AlarmHistoryScreen> createState() => _AlarmHistoryScreenState();
}

class _AlarmHistoryScreenState extends State<AlarmHistoryScreen> {
  static const MethodChannel _channel = MethodChannel('alarm_service');

  List<AlarmEvent> _events = [];
  bool _loading = true;
  bool _repairing = false;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  TextStyle _t(double size, {FontWeight w = FontWeight.w500, Color c = C.ink}) =>
      GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool repair = false}) async {
    if (repair) {
      await AlarmHistoryService.repairAndSync(force: true);
    }
    final list = await AlarmHistoryService.events();
    if (!mounted) return;
    setState(() {
      _events = list;
      _loading = false;
    });
  }

  Future<void> _repairNow() async {
    setState(() => _repairing = true);
    await _load(repair: true);
    if (!mounted) return;
    setState(() => _repairing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alarms checked and set again.')),
    );
  }

  Future<void> _openSettings() async {
    try {
      await _channel.invokeMethod('openBatterySettings');
    } catch (_) {}
  }

  String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final recent = _events.where((e) => e.scheduledFor.isAfter(weekAgo));
    final rang = recent.where((e) => e.rang).length;
    final missed = recent.where((e) => !e.rang).length;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text('Alarm history'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(repair: true),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _summary(rang, missed),
                  const SizedBox(height: 16),
                  if (_events.isEmpty) _empty() else ..._grouped(),
                  const SizedBox(height: 16),
                  _actions(),
                ],
              ),
      ),
    );
  }

  Widget _summary(int rang, int missed) {
    Widget stat(int n, String label, Color c) => Expanded(
          child: Column(
            children: [
              Text('$n', style: _t(30, w: FontWeight.w800, c: c)),
              Text(label, style: _t(14, c: C.txm)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.bd),
      ),
      child: Column(
        children: [
          Text('Last 7 days', style: _t(14, w: FontWeight.w700, c: C.txm)),
          const SizedBox(height: 8),
          Row(
            children: [
              stat(rang, 'Rang', const Color(0xFF177A40)),
              stat(missed, 'Missed', const Color(0xFFC62828)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
        child: Column(
          children: [
            const Icon(Icons.alarm_rounded, size: 48, color: C.txl),
            const SizedBox(height: 12),
            Text('No alarms recorded yet',
                style: _t(16, w: FontWeight.w700), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              'When a reminder is due, it will show here as Rang or Missed.',
              style: _t(14, c: C.txm),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  List<Widget> _grouped() {
    final out = <Widget>[];
    String? last;
    for (final e in _events) {
      final label = _dayLabel(e.scheduledFor);
      if (label != last) {
        out.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Text(label, style: _t(14, w: FontWeight.w700, c: C.txm)),
        ));
        last = label;
      }
      out.add(_row(e));
    }
    return out;
  }

  Widget _row(AlarmEvent e) {
    final ok = e.rang;
    final color = ok ? const Color(0xFF177A40) : const Color(0xFFC62828);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.bd),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_time(e.scheduledFor), style: _t(16, w: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(e.friendlyTitle, style: _t(14, c: C.txm)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size: 18, color: color),
                const SizedBox(width: 6),
                Text(ok ? 'Rang' : 'Missed',
                    style: _t(14, w: FontWeight.w700, c: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '"Missed" means the alarm did not go off at its time. Setting the '
            'alarms again and allowing ElderZha to run in the background '
            'usually fixes this.',
            style: _t(14, c: C.txm),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _repairing ? null : _repairNow,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_repairing ? 'Checking…' : 'Set alarms again now'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _openSettings,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              foregroundColor: C.ink,
              side: const BorderSide(color: C.bd, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.battery_saver_rounded),
            label: Text('Fix alarm settings', style: _t(14, w: FontWeight.w700)),
          ),
        ],
      );
}
