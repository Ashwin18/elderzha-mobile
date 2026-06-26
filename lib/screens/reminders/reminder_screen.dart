import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../alaram/daily_scheduler.dart';
import '../../services/services.dart';
import '../../theme/app_theme.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  final _alarmService = AlarmService();
  bool _loading = true;
  List _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _alarmService.listReminders();
    if (!mounted) return;
    setState(() {
      _items = _extractList(res)
          .where((item) => !_isDisabled(item))
          .toList(growable: false);
      _loading = false;
    });
  }

  List _extractList(Map<String, dynamic>? res) {
    if (res == null) return [];
    const keys = ['data', 'items', 'list', 'reminders', 'records'];
    for (final key in keys) {
      final value = res[key];
      if (value is List) return value;
      if (value is Map) {
        for (final nested in keys) {
          final nestedValue = value[nested];
          if (nestedValue is List) return nestedValue;
        }
      }
    }
    return [];
  }

  bool _isDisabled(dynamic item) {
    if (item is! Map) return true;
    final raw = item['is_active'] ?? item['status'] ?? item['enabled'];
    if (raw == null) return false;
    final text = raw.toString().toLowerCase().trim();
    return text == '0' || text == 'false' || text == 'disabled';
  }

  Future<void> _openSheet([Map? existing]) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _ReminderSheet(existing: existing),
    );
    if (result == true) await _load();
  }

  Future<void> _delete(Map item) async {
    final id =
        int.tryParse((item['id'] ?? item['reminder_id'] ?? 0).toString());
    if (id == null || id == 0) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete reminder?', style: GoogleFonts.poppins()),
        content: Text('This reminder will be removed from your list.',
            style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.poppins(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _items.removeWhere((value) {
          if (value is! Map) return false;
          return (value['id'] ?? value['reminder_id'] ?? '').toString() ==
              id.toString();
        }));
    final res = await _alarmService.deleteReminder(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            res['status'] == false
                ? (res['message'] ?? 'Reminder removed locally')
                : 'Reminder deleted',
            style: GoogleFonts.poppins()),
        backgroundColor:
            res['status'] == false ? AppColors.red : AppColors.green,
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        Container(
          width: double.infinity,
          color: AppColors.yellow,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reminders',
                          style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink)),
                      Text('Create personal event reminders',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.yellowDeep)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _openSheet(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: AppColors.yellow, size: 26),
                  ),
                ),
              ]),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.yellowDark))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.yellowDark,
                  child: _items.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(28),
                          children: [
                            const SizedBox(height: 90),
                            const Icon(Icons.notifications_none_rounded,
                                size: 48, color: AppColors.inkLight),
                            const SizedBox(height: 14),
                            Text('No reminders yet',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink)),
                            const SizedBox(height: 6),
                            Text('Tap + to schedule your first reminder.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: AppColors.inkLight)),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length,
                          itemBuilder: (_, i) => _reminderCard(
                            Map<String, dynamic>.from(_items[i] as Map),
                          ),
                        ),
                ),
        ),
      ]),
    );
  }

  Widget _reminderCard(Map item) {
    final title =
        (item['title'] ?? item['event_name'] ?? 'Reminder').toString();
    final date = (item['date'] ?? item['reminder_date'] ?? '').toString();
    final time = (item['time'] ?? '').toString();
    final type = (item['type'] ?? 'custom').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.yellowSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.alarm_rounded, color: AppColors.yellowDark),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
            const SizedBox(height: 3),
            Text('$date · $time',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.inkLight)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(type,
                  style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.green)),
            ),
          ]),
        ),
        IconButton(
          onPressed: () => _openSheet(item),
          icon: const Icon(Icons.edit_outlined, color: AppColors.inkMuted),
        ),
        IconButton(
          onPressed: () => _delete(item),
          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
        ),
      ]),
    );
  }
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({this.existing});
  final Map? existing;

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  final _alarmService = AlarmService();
  final _titleCtrl = TextEditingController();
  final _eventCtrl = TextEditingController();
  DateTime? _date;
  TimeOfDay? _time;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleCtrl.text = (existing['title'] ?? '').toString();
      _eventCtrl.text = (existing['event_name'] ?? existing['type'] ?? '')
          .toString()
          .replaceAll('custom', '');
      _date = _parseDate(
          (existing['date'] ?? existing['reminder_date'] ?? '').toString());
      _time = _parseTime((existing['time'] ?? '').toString());
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _eventCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(DateTime.now().year + 10),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.yellowDark),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.yellowDark),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty || _date == null || _time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Enter title, date and time', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final id = int.tryParse(
        (widget.existing?['id'] ?? widget.existing?['reminder_id'] ?? 0)
            .toString());
    final title = _titleCtrl.text.trim();
    final event = _eventCtrl.text.trim();
    final date = _apiDate(_date!);
    final time = _apiTime(_time!);
    final res = id != null && id != 0
        ? await _alarmService.updateReminder(
            id: id,
            title: title,
            time: time,
            enabled: true,
          )
        : await _alarmService.storeReminder(
            title: title,
            time: time,
            type: event.isEmpty ? 'custom' : event,
            date: date,
            repeat: false,
          );
    await DailyScheduler.scheduleReminder(
      AlarmType.food,
      date,
      time,
      'ElderZha • $title',
      'once',
      notes: event,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    final ok = res['status'] == true || res['data'] != null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Reminder saved' : (res['message'] ?? 'Error'),
            style: GoogleFonts.poppins()),
        backgroundColor: ok ? AppColors.green : AppColors.red,
      ),
    );
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(
            child: Text(
              widget.existing == null ? 'Add reminder' : 'Edit reminder',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: _titleCtrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Reminder title',
            prefixIcon: Icon(Icons.title_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _eventCtrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Event name',
            prefixIcon: Icon(Icons.event_note_rounded),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _pickerTile(
              Icons.calendar_today_rounded,
              _date == null ? 'Date' : _displayDate(_date!),
              _pickDate,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _pickerTile(
              Icons.schedule_rounded,
              _time == null ? 'Time' : _time!.format(context),
              _pickTime,
            ),
          ),
        ]),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: _saving ? null : _save,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.yellow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: AppColors.ink, strokeWidth: 2),
                    )
                  : Text('Save reminder',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _pickerTile(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.bgMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.inkLight),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkMuted)),
          ),
        ]),
      ),
    );
  }

  DateTime? _parseDate(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      final parts = raw.split('-');
      if (parts.length != 3) return null;
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      final c = int.tryParse(parts[2]);
      if (a == null || b == null || c == null) return null;
      return parts[0].length == 4 ? DateTime(a, b, c) : DateTime(c, b, a);
    }
  }

  TimeOfDay? _parseTime(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _apiDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  String _apiTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
}
