// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../alaram/daily_scheduler.dart';
import '../../alaram/alarm_config_store.dart';
import '../../alaram/alarm_permission_service.dart';
import '../../services/services.dart';
import '../../theme/app_theme.dart';

enum AlarmViewMode { food, medical }

enum MedicalAlarmFilter { all, breakfast, lunch, night }

const MethodChannel _alarmChannel = MethodChannel('alarm_service');

class AlarmsScreen extends StatefulWidget {
  const AlarmsScreen({super.key});
  @override
  State<AlarmsScreen> createState() => _AlarmsScreenState();
}

class _AlarmsScreenState extends State<AlarmsScreen> {
  final _alarmSvc = AlarmService();

  static const _accent = Color(0xFFE0A800);
  static const _accentLight = Color(0xFFF5C542);
  static const _segBg = Color(0xFFFFF1BF);
  static const _toggleGreen = Color(0xFF32D667);
  static const _muted = Color(0xFF7C778A);
  static const _disabled = Color(0xFFD3CFDB);
  static const _border = Color(0xFFF4D77A);

  AlarmViewMode _mode = AlarmViewMode.food;
  MedicalAlarmFilter _medFilter = MedicalAlarmFilter.all;

  bool _loading = true;
  bool _saving = false;
  bool _appliedInitialMode = false;

  // Toggles
  bool medicalAlarmSwitch = true, foodAlarmSwitch = true;
  bool medMorningBeforeOn = true, medMorningAfterOn = true;
  bool medNoonBeforeOn = false, medNoonAfterOn = false;
  bool medNightBeforeOn = true, medNightAfterOn = true;
  bool foodBreakfastOn = true, foodLunchOn = true, foodDinnerOn = true;

  // Times
  TimeOfDay foodBreakfastTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay foodLunchTime = const TimeOfDay(hour: 13, minute: 0);
  TimeOfDay foodDinnerTime = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay morningBefore = const TimeOfDay(hour: 7, minute: 30);
  TimeOfDay morningAfter = const TimeOfDay(hour: 8, minute: 30);
  TimeOfDay noonBefore = const TimeOfDay(hour: 12, minute: 30);
  TimeOfDay noonAfter = const TimeOfDay(hour: 13, minute: 30);
  TimeOfDay nightBefore = const TimeOfDay(hour: 19, minute: 30);
  TimeOfDay nightAfter = const TimeOfDay(hour: 20, minute: 30);

  // Extras
  File? _medImage, _foodImage;
  String? _medImageUrl, _foodImageUrl;
  String? _tonePath;
  bool _recording = false;
  String? _recordedPreviewPath;
  bool _previewPlaying = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadFromApi();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appliedInitialMode) return;
    _appliedInitialMode = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    final value = args is Map ? args['mode'] : args;
    if (value == AlarmViewMode.medical ||
        value?.toString().toLowerCase() == 'medical') {
      _mode = AlarmViewMode.medical;
    } else if (value == AlarmViewMode.food ||
        value?.toString().toLowerCase() == 'food') {
      _mode = AlarmViewMode.food;
    }
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _alarmChannel.invokeMethod('stopTonePreview');
    if (_recording) {
      _alarmChannel.invokeMethod('stopVoiceRecording');
    }
    super.dispose();
  }

  // ── GET /user/get/medical/records ─────────────────────────────────────────
  Future<void> _loadFromApi() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    _tonePath = prefs.getString('alarm_tone');
    final local = await AlarmConfigStore.load();

    final res = await _alarmSvc.getMedicalRecords();
    if (!mounted) return;

    // API returns data as array (Collection) OR object (single record)
    final rawData = res?['data'];
    Map<String, dynamic> remote = {};
    if (rawData is Map) {
      remote = Map<String, dynamic>.from(rawData);
    } else if (rawData is List && rawData.isNotEmpty && rawData.first is Map) {
      remote = Map<String, dynamic>.from(rawData.first);
    }
    final merged = _mergeAlarmData(local, remote);
    if (merged.isNotEmpty) {
      setState(() => _applyAlarmData(merged, prefs.getString('alarm_tone')));
    }
    setState(() => _loading = false);
  }

  Map<String, dynamic> _mergeAlarmData(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final merged = <String, dynamic>{...local};
    remote.forEach((key, value) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        merged[key] = value;
      }
    });
    return merged;
  }

  void _applyAlarmData(Map data, String? savedTone) {
    medicalAlarmSwitch = _truthy(data['medical_alarm'], fallback: true);
    foodAlarmSwitch =
        _truthy(data['food_alarm'] ?? data['food_alaram'], fallback: true);
    medMorningBeforeOn =
        _firstValue(data, ['morning_before_food', 'm_before_food']).isNotEmpty;
    medMorningAfterOn =
        _firstValue(data, ['morning_after_food', 'm_after_food']).isNotEmpty;
    medNoonBeforeOn =
        _firstValue(data, ['afternoon_before_food', 'af_before_food'])
            .isNotEmpty;
    medNoonAfterOn =
        _firstValue(data, ['afternoon_after_food', 'af_after_food']).isNotEmpty;
    medNightBeforeOn =
        _firstValue(data, ['night_before_food', 'n_before_food']).isNotEmpty;
    medNightAfterOn =
        _firstValue(data, ['night_after_food', 'n_after_food']).isNotEmpty;
    foodBreakfastOn = _truthy(data['breakfast_status'], fallback: true);
    foodLunchOn = _truthy(data['lunch_status'], fallback: true);
    foodDinnerOn = _truthy(data['dinner_status'], fallback: true);
    morningBefore = _parseT(
        _firstValue(data, ['morning_before_food', 'm_before_food']),
        morningBefore);
    morningAfter = _parseT(
        _firstValue(data, ['morning_after_food', 'm_after_food']),
        morningAfter);
    noonBefore = _parseT(
        _firstValue(data, ['afternoon_before_food', 'af_before_food']),
        noonBefore);
    noonAfter = _parseT(
        _firstValue(data, ['afternoon_after_food', 'af_after_food']),
        noonAfter);
    nightBefore = _parseT(
        _firstValue(data, ['night_before_food', 'n_before_food']), nightBefore);
    nightAfter = _parseT(
        _firstValue(data, ['night_after_food', 'n_after_food']), nightAfter);
    foodBreakfastTime = _parseT(
        _firstValue(data, ['breakfast_time', 'bf_time']), foodBreakfastTime);
    foodLunchTime =
        _parseT(_firstValue(data, ['lunch_time', 'l_time']), foodLunchTime);
    foodDinnerTime =
        _parseT(_firstValue(data, ['dinner_time', 'd_time']), foodDinnerTime);
    _medImageUrl = _firstValue(data, ['medical_file', 'medical_image']);
    _foodImageUrl = _firstValue(data, ['food_file', 'food_image']);
    _tonePath = savedTone ??
        _firstValue(data, ['alaram_tone', 'alarm_tone', 'alarmTone']);
  }

  bool _truthy(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value == true) return true;
    if (value is num) return value != 0;
    final text = value.toString().toLowerCase().trim();
    if (text.isEmpty || text == 'null') return fallback;
    return text == '1' || text == 'true' || text == 'yes' || text == 'active';
  }

  String _firstValue(Map data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return '';
  }

  TimeOfDay _parseT(dynamic raw, TimeOfDay fallback) {
    if (raw == null || raw.toString().isEmpty) return fallback;
    final p = raw.toString().split(':');
    if (p.length < 2) return fallback;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return fallback;
    return TimeOfDay(hour: h, minute: m);
  }

  String _fmt(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  String _toStr(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  String _schedDate(TimeOfDay t) {
    var dt = DateTime(DateTime.now().year, DateTime.now().month,
        DateTime.now().day, t.hour, t.minute);
    if (dt.isBefore(DateTime.now())) dt = dt.add(const Duration(days: 1));
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  // ── SAVE — POST /user/store/medical-settings + DailyScheduler ────────────
  Future<void> _save() async {
    setState(() => _saving = true);
    await AlarmPermissionService.ensureFullScreenIntentPermission();

    // 1. Save to API
    final payload = {
      'medical_alarm': medicalAlarmSwitch ? 1 : 0,
      'morning_status': (medMorningBeforeOn || medMorningAfterOn) ? 1 : 0,
      'm_before_food':
          medicalAlarmSwitch && medMorningBeforeOn ? _toStr(morningBefore) : '',
      'm_after_food':
          medicalAlarmSwitch && medMorningAfterOn ? _toStr(morningAfter) : '',
      'afternoon_status': (medNoonBeforeOn || medNoonAfterOn) ? 1 : 0,
      'af_before_food':
          medicalAlarmSwitch && medNoonBeforeOn ? _toStr(noonBefore) : '',
      'af_after_food':
          medicalAlarmSwitch && medNoonAfterOn ? _toStr(noonAfter) : '',
      'night_status': (medNightBeforeOn || medNightAfterOn) ? 1 : 0,
      'n_before_food':
          medicalAlarmSwitch && medNightBeforeOn ? _toStr(nightBefore) : '',
      'n_after_food':
          medicalAlarmSwitch && medNightAfterOn ? _toStr(nightAfter) : '',
      'food_alaram': foodAlarmSwitch ? 1 : 0,
      'food_alarm': foodAlarmSwitch ? 1 : 0,
      'breakfast_status': foodBreakfastOn ? 1 : 0,
      'bf_time': _toStr(foodBreakfastTime),
      'lunch_status': foodLunchOn ? 1 : 0,
      'l_time': _toStr(foodLunchTime),
      'dinner_status': foodDinnerOn ? 1 : 0,
      'd_time': _toStr(foodDinnerTime),
    };
    await _alarmSvc.saveMedicalSettingsMultipart(
      payload: payload,
      medicalFile: _medImage,
      foodFile: _foodImage,
      alarmTone: _tonePath != null && File(_tonePath!).existsSync()
          ? File(_tonePath!)
          : null,
    );
    await AlarmConfigStore.save({
      ...payload,
      if (_medImage != null) 'medical_file': _medImage!.path,
      if (_medImageUrl != null && _medImageUrl!.isNotEmpty)
        'medical_file': _medImageUrl,
      if (_foodImage != null) 'food_file': _foodImage!.path,
      if (_foodImageUrl != null && _foodImageUrl!.isNotEmpty)
        'food_file': _foodImageUrl,
      if (_tonePath != null && _tonePath!.isNotEmpty) 'alaram_tone': _tonePath,
      'saved_from': 'profile_alarm_settings',
      'saved_at': DateTime.now().toIso8601String(),
    });

    // 2. Clear old native alarms
    await DailyScheduler.cancelAllAlarms();
    await DailyScheduler.clearStoredAlarms();

    // 3. Schedule food alarms via DailyScheduler → MethodChannel → Android AlarmManager
    await _scheduleFoodAlarms();
    await _scheduleMedicalAlarms();

    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Alarms saved & scheduled! ✅',
                style: GoogleFonts.poppins()),
            backgroundColor: C.green),
      );
    }
  }

  Future<void> _scheduleFoodAlarms() async {
    if (!foodAlarmSwitch) return;
    if (foodBreakfastOn)
      await DailyScheduler.scheduleReminder(
          AlarmType.food,
          _schedDate(foodBreakfastTime),
          _toStr(foodBreakfastTime),
          '🍳 Elderzha • Breakfast Time',
          'daily',
          soundUrl: _tonePath,
          imageUrl: _foodImage?.path ?? _foodImageUrl);
    if (foodLunchOn)
      await DailyScheduler.scheduleReminder(
          AlarmType.food,
          _schedDate(foodLunchTime),
          _toStr(foodLunchTime),
          '🍽 Elderzha • Lunch Reminder',
          'daily',
          soundUrl: _tonePath,
          imageUrl: _foodImage?.path ?? _foodImageUrl);
    if (foodDinnerOn)
      await DailyScheduler.scheduleReminder(
          AlarmType.food,
          _schedDate(foodDinnerTime),
          _toStr(foodDinnerTime),
          '🍽 Elderzha • Dinner Reminder',
          'daily',
          soundUrl: _tonePath,
          imageUrl: _foodImage?.path ?? _foodImageUrl);
  }

  Future<void> _scheduleMedicalAlarms() async {
    if (!medicalAlarmSwitch) return;
    final img = _medImage?.path ?? _medImageUrl;
    if (medMorningBeforeOn)
      await DailyScheduler.scheduleReminder(
          AlarmType.medical,
          _schedDate(morningBefore),
          _toStr(morningBefore),
          '💊 Elderzha • Morning Before Food',
          'daily',
          soundUrl: _tonePath,
          imageUrl: img);
    if (medMorningAfterOn)
      await DailyScheduler.scheduleReminder(
          AlarmType.medical,
          _schedDate(morningAfter),
          _toStr(morningAfter),
          '💊 Elderzha • Morning After Food',
          'daily',
          soundUrl: _tonePath,
          imageUrl: img);
    if (medNoonBeforeOn)
      await DailyScheduler.scheduleReminder(
          AlarmType.medical,
          _schedDate(noonBefore),
          _toStr(noonBefore),
          '💊 Elderzha • Noon Before Food',
          'daily',
          soundUrl: _tonePath,
          imageUrl: img);
    if (medNoonAfterOn)
      await DailyScheduler.scheduleReminder(
          AlarmType.medical,
          _schedDate(noonAfter),
          _toStr(noonAfter),
          '💊 Elderzha • Noon After Food',
          'daily',
          soundUrl: _tonePath,
          imageUrl: img);
    if (medNightBeforeOn)
      await DailyScheduler.scheduleReminder(
          AlarmType.medical,
          _schedDate(nightBefore),
          _toStr(nightBefore),
          '🌙 Elderzha • Night Before Food',
          'daily',
          soundUrl: _tonePath,
          imageUrl: img);
    if (medNightAfterOn)
      await DailyScheduler.scheduleReminder(
          AlarmType.medical,
          _schedDate(nightAfter),
          _toStr(nightAfter),
          '🌙 Elderzha • Night After Food',
          'daily',
          soundUrl: _tonePath,
          imageUrl: img);
  }

  Future<void> _pickTone() async {
    await Permission.audio.request();
    final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'aac', 'm4a', 'ogg']);
    if (r == null || r.files.single.path == null) return;
    final src = File(r.files.single.path!);
    final dir = await getApplicationDocumentsDirectory();
    final tgt = '${dir.path}/${r.files.single.name}';
    if (await File(tgt).exists()) await File(tgt).delete();
    await src.copy(tgt);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('alarm_tone', tgt);
    await _stopTonePreview();
    setState(() {
      _tonePath = tgt;
      _recordedPreviewPath = null;
    });
  }

  Future<void> _toggleVoiceRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Microphone permission is required',
                style: GoogleFonts.poppins()),
            backgroundColor: C.red),
      );
      return;
    }
    if (!_recording) {
      await _stopTonePreview();
      await _alarmChannel.invokeMethod<String>('startVoiceRecording');
      if (!mounted) return;
      setState(() {
        _recording = true;
        _recordedPreviewPath = null;
        _recordSeconds = 0;
      });
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        final next = _recordSeconds + 1;
        setState(() => _recordSeconds = next);
        if (next >= 15) {
          _finishVoiceRecording();
        }
      });
    } else {
      await _finishVoiceRecording();
    }
  }

  Future<void> _finishVoiceRecording() async {
    if (!_recording) return;
    _recordTimer?.cancel();
    final path = await _alarmChannel.invokeMethod<String>('stopVoiceRecording');
    if (!mounted) return;
    setState(() {
      _recording = false;
      if (path != null && path.isNotEmpty) _recordedPreviewPath = path;
    });
  }

  Future<void> _previewTone(String? path) async {
    if (path == null || path.isEmpty) return;
    if (_previewPlaying) {
      await _stopTonePreview();
      return;
    }
    await _alarmChannel.invokeMethod('playTonePreview', {'path': path});
    if (mounted) setState(() => _previewPlaying = true);
  }

  Future<void> _stopTonePreview() async {
    await _alarmChannel.invokeMethod('stopTonePreview');
    if (mounted) setState(() => _previewPlaying = false);
  }

  Future<void> _useRecordedTone() async {
    final path = _recordedPreviewPath;
    if (path == null || path.isEmpty) return;
    await _stopTonePreview();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('alarm_tone', path);
    if (!mounted) return;
    setState(() {
      _tonePath = path;
      _recordedPreviewPath = null;
    });
  }

  Future<void> _discardRecording() async {
    await _stopTonePreview();
    final path = _recordedPreviewPath;
    if (path != null && path.isNotEmpty) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    if (mounted) setState(() => _recordedPreviewPath = null);
  }

  Future<void> _pickImage(String type) async {
    showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
                child: Wrap(children: [
              ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Gallery'),
                  onTap: () async {
                    Navigator.pop(context);
                    final f = await _picker.pickImage(
                        source: ImageSource.gallery, imageQuality: 85);
                    if (f != null) {
                      final stored = await _persistImage(f.path);
                      setState(() {
                        if (type == 'medical') {
                          _medImage = stored;
                          _medImageUrl = null;
                        } else {
                          _foodImage = stored;
                          _foodImageUrl = null;
                        }
                      });
                    }
                  }),
              ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Camera'),
                  onTap: () async {
                    Navigator.pop(context);
                    final f = await _picker.pickImage(
                        source: ImageSource.camera, imageQuality: 85);
                    if (f != null) {
                      final stored = await _persistImage(f.path);
                      setState(() {
                        if (type == 'medical') {
                          _medImage = stored;
                          _medImageUrl = null;
                        } else {
                          _foodImage = stored;
                          _foodImageUrl = null;
                        }
                      });
                    }
                  }),
            ])));
  }

  Future<File> _persistImage(String sourcePath) async {
    final src = File(sourcePath);
    final dir = await getApplicationDocumentsDirectory();
    final ext = sourcePath.split('.').last;
    final target = File(
        '${dir.path}/elderzha_alarm_image_${DateTime.now().millisecondsSinceEpoch}.$ext');
    return src.copy(target.path);
  }

  Future<void> _selectTime(
      TimeOfDay init, ValueChanged<TimeOfDay> onDone) async {
    final t = await showTimePicker(context: context, initialTime: init);
    if (t != null && mounted) setState(() => onDone(t));
  }

  // ───────────────────────────────────────────────────────────── BUILD ──────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F1),
      body: SafeArea(
          child: _loading
              ? const Center(
                  child: CupertinoActivityIndicator(
                      radius: 14, color: Colors.black))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  child: Column(children: [
                    _topPanel(),
                    const SizedBox(height: 14),
                    _summaryCards(),
                    const SizedBox(height: 14),
                    _nextAlarmCard(),
                    const SizedBox(height: 14),
                    _contentPanel(),
                    const SizedBox(height: 14),
                    _extrasPanel(),
                    const SizedBox(height: 18),
                    _saveBtn(),
                  ]),
                )),
    );
  }

  // ── Top panel (header + tabs) ─────────────────────────────────────────────
  Widget _topPanel() => Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        decoration: BoxDecoration(
          color: C.yellow,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Column(children: [
          Row(children: [
            _backBtn(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Alarm Center',
                      style: GoogleFonts.poppins(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          color: C.ink,
                          height: 1.05)),
                  const SizedBox(height: 4),
                  Text('Manage schedules, popup image and alarm sound',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: C.yellowDeep)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 18),
          _modeTabs(),
        ]),
      );

  Widget _backBtn() => GestureDetector(
        onTap: () => Navigator.maybePop(context),
        child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(.58),
                borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: Colors.black87)),
      );

  Widget _modeTabs() => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: _segBg, borderRadius: BorderRadius.circular(22)),
        child: Row(children: [
          Expanded(child: _segBtn('Food Alarm', AlarmViewMode.food)),
          const SizedBox(width: 8),
          Expanded(child: _segBtn('Medical Alarm', AlarmViewMode.medical)),
        ]),
      );

  Widget _segBtn(String label, AlarmViewMode m) {
    final sel = _mode == m;
    return GestureDetector(
      onTap: () => setState(() => _mode = m),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: sel
              ? const LinearGradient(
                  colors: [_accent, _accentLight],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight)
              : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: sel
              ? [
                  const BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 12,
                      offset: Offset(0, 5))
                ]
              : null,
        ),
        child: Center(
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : const Color(0xFF53515E)))),
      ),
    );
  }

  Widget _summaryCards() => Row(children: [
        Expanded(
          child: _metricCard(
            _activeAlarmCount().toString(),
            'Active alarms',
            Icons.notifications_active_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _metricCard(
            '15s',
            'Voice tone limit',
            Icons.mic_rounded,
          ),
        ),
      ]);

  Widget _metricCard(String value, String label, IconData icon) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE9E4D6)),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _segBg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: _accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: GoogleFonts.poppins(
                      fontSize: 20,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: C.ink)),
              const SizedBox(height: 5),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _muted)),
            ]),
          ),
        ]),
      );

  int _activeAlarmCount() {
    var count = 0;
    if (foodAlarmSwitch) {
      if (foodBreakfastOn) count++;
      if (foodLunchOn) count++;
      if (foodDinnerOn) count++;
    }
    if (medicalAlarmSwitch) {
      if (medMorningBeforeOn) count++;
      if (medMorningAfterOn) count++;
      if (medNoonBeforeOn) count++;
      if (medNoonAfterOn) count++;
      if (medNightBeforeOn) count++;
      if (medNightAfterOn) count++;
    }
    return count;
  }

  ({String title, String subtitle, TimeOfDay time, bool food})? _nextAlarm() {
    final now = DateTime.now();
    final items =
        <({String title, String subtitle, TimeOfDay time, bool food})>[];
    if (foodAlarmSwitch) {
      if (foodBreakfastOn) {
        items.add((
          title: 'Breakfast reminder',
          subtitle: 'Food alarm',
          time: foodBreakfastTime,
          food: true
        ));
      }
      if (foodLunchOn) {
        items.add((
          title: 'Lunch reminder',
          subtitle: 'Food alarm',
          time: foodLunchTime,
          food: true
        ));
      }
      if (foodDinnerOn) {
        items.add((
          title: 'Dinner reminder',
          subtitle: 'Food alarm',
          time: foodDinnerTime,
          food: true
        ));
      }
    }
    if (medicalAlarmSwitch) {
      if (medMorningBeforeOn) {
        items.add((
          title: 'Morning medicine',
          subtitle: 'Before food',
          time: morningBefore,
          food: false
        ));
      }
      if (medMorningAfterOn) {
        items.add((
          title: 'Morning medicine',
          subtitle: 'After food',
          time: morningAfter,
          food: false
        ));
      }
      if (medNoonBeforeOn) {
        items.add((
          title: 'Afternoon medicine',
          subtitle: 'Before food',
          time: noonBefore,
          food: false
        ));
      }
      if (medNoonAfterOn) {
        items.add((
          title: 'Afternoon medicine',
          subtitle: 'After food',
          time: noonAfter,
          food: false
        ));
      }
      if (medNightBeforeOn) {
        items.add((
          title: 'Night medicine',
          subtitle: 'Before food',
          time: nightBefore,
          food: false
        ));
      }
      if (medNightAfterOn) {
        items.add((
          title: 'Night medicine',
          subtitle: 'After food',
          time: nightAfter,
          food: false
        ));
      }
    }
    if (items.isEmpty) return null;
    DateTime dateFor(TimeOfDay t) {
      var dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
      if (!dt.isAfter(now)) dt = dt.add(const Duration(days: 1));
      return dt;
    }

    items.sort((a, b) => dateFor(a.time).compareTo(dateFor(b.time)));
    return items.first;
  }

  Widget _nextAlarmCard() {
    final next = _nextAlarm();
    final isFood = next?.food ?? _mode == AlarmViewMode.food;
    final file = isFood ? _foodImage : _medImage;
    final url = isFood ? _foodImageUrl : _medImageUrl;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: C.ink,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
              color: Color(0x18000000), blurRadius: 18, offset: Offset(0, 8))
        ],
      ),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('NEXT ALARM',
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withOpacity(.62))),
            const SizedBox(height: 5),
            Text(next?.title ?? 'No alarms active',
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(height: 6),
            Text(
              next == null
                  ? 'Enable food or medical reminders'
                  : 'Today at ${_fmt(next.time)} · ${next.subtitle}',
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(.72)),
            ),
          ]),
        ),
        const SizedBox(width: 14),
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.12),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(.22), width: 3),
          ),
          clipBehavior: Clip.antiAlias,
          child: file != null || (url != null && url.isNotEmpty)
              ? _imgPreview(file, url)
              : Icon(
                  isFood ? Icons.restaurant_rounded : Icons.medication_rounded,
                  color: C.yellow,
                  size: 32),
        ),
      ]),
    );
  }

  // ── Content panel ─────────────────────────────────────────────────────────
  Widget _contentPanel() => Container(
        padding: const EdgeInsets.all(18),
        decoration: _card32(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _modeHeader(),
          const SizedBox(height: 16),
          if (_mode == AlarmViewMode.medical) ...[
            _medFilterTabs(),
            const SizedBox(height: 18),
            _medCards()
          ] else
            _foodCards(),
        ]),
      );

  Widget _modeHeader() {
    final isFood = _mode == AlarmViewMode.food;
    final isOn = isFood ? foodAlarmSwitch : medicalAlarmSwitch;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF9E8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF3E3A3))),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isFood ? 'Food Alarm' : 'Medical Alarm',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          const SizedBox(height: 4),
          Text(
              isFood
                  ? 'Breakfast, lunch and dinner reminders'
                  : 'Before and after food medicine reminders',
              style: GoogleFonts.poppins(fontSize: 12, color: _muted)),
        ])),
        Switch(
          value: isOn,
          onChanged: (v) => setState(() {
            if (isFood) {
              foodAlarmSwitch = v;
              foodBreakfastOn = v;
              foodLunchOn = v;
              foodDinnerOn = v;
            } else {
              medicalAlarmSwitch = v;
              medMorningBeforeOn = v;
              medMorningAfterOn = v;
              medNoonBeforeOn = v;
              medNoonAfterOn = v;
              medNightBeforeOn = v;
              medNightAfterOn = v;
            }
          }),
          activeTrackColor: _toggleGreen,
          inactiveTrackColor: const Color(0xFFE9E7EE),
          thumbColor: WidgetStateProperty.all(Colors.white),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ]),
    );
  }

  Widget _medFilterTabs() {
    final tabs = {
      MedicalAlarmFilter.all: 'All Alarms',
      MedicalAlarmFilter.breakfast: 'Morning',
      MedicalAlarmFilter.lunch: 'Afternoon',
      MedicalAlarmFilter.night: 'Night',
    };
    return Container(
      padding: const EdgeInsets.all(6),
      decoration:
          BoxDecoration(color: _segBg, borderRadius: BorderRadius.circular(18)),
      child: Row(
          children: tabs.entries.map((e) {
        final sel = _medFilter == e.key;
        return Expanded(
            child: GestureDetector(
          onTap: () => setState(() => _medFilter = e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 44,
            decoration: BoxDecoration(
              gradient: sel
                  ? const LinearGradient(colors: [_accent, _accentLight])
                  : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(e.value,
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: sel ? Colors.white : Colors.black87)))),
          ),
        ));
      }).toList()),
    );
  }

  Widget _foodCards() => Column(children: [
        _scheduleRow(
          icon: Icons.wb_sunny_rounded,
          title: 'Breakfast',
          subtitle: 'Morning meal reminder',
          time: foodBreakfastTime,
          enabled: foodAlarmSwitch && foodBreakfastOn,
          onToggle: foodAlarmSwitch
              ? (v) => setState(() => foodBreakfastOn = v)
              : null,
          onTap: foodAlarmSwitch
              ? () =>
                  _selectTime(foodBreakfastTime, (t) => foodBreakfastTime = t)
              : null,
        ),
        _scheduleRow(
          icon: Icons.restaurant_rounded,
          title: 'Lunch',
          subtitle: 'Afternoon meal reminder',
          time: foodLunchTime,
          enabled: foodAlarmSwitch && foodLunchOn,
          onToggle:
              foodAlarmSwitch ? (v) => setState(() => foodLunchOn = v) : null,
          onTap: foodAlarmSwitch
              ? () => _selectTime(foodLunchTime, (t) => foodLunchTime = t)
              : null,
        ),
        _scheduleRow(
          icon: Icons.nightlight_round,
          title: 'Dinner',
          subtitle: 'Night meal reminder',
          time: foodDinnerTime,
          enabled: foodAlarmSwitch && foodDinnerOn,
          onToggle:
              foodAlarmSwitch ? (v) => setState(() => foodDinnerOn = v) : null,
          onTap: foodAlarmSwitch
              ? () => _selectTime(foodDinnerTime, (t) => foodDinnerTime = t)
              : null,
          isLast: true,
        ),
      ]);

  Widget _medCards() {
    final sections = <Widget>[];
    if (_medFilter == MedicalAlarmFilter.all ||
        _medFilter == MedicalAlarmFilter.breakfast)
      sections.add(_medSection(
          'Morning',
          medMorningBeforeOn,
          medMorningAfterOn,
          morningBefore,
          morningAfter,
          (v) => medMorningBeforeOn = v,
          (v) => medMorningAfterOn = v,
          () => _selectTime(morningBefore, (t) => morningBefore = t),
          () => _selectTime(morningAfter, (t) => morningAfter = t)));
    if (_medFilter == MedicalAlarmFilter.all ||
        _medFilter == MedicalAlarmFilter.lunch)
      sections.add(_medSection(
          'Afternoon',
          medNoonBeforeOn,
          medNoonAfterOn,
          noonBefore,
          noonAfter,
          (v) => medNoonBeforeOn = v,
          (v) => medNoonAfterOn = v,
          () => _selectTime(noonBefore, (t) => noonBefore = t),
          () => _selectTime(noonAfter, (t) => noonAfter = t)));
    if (_medFilter == MedicalAlarmFilter.all ||
        _medFilter == MedicalAlarmFilter.night)
      sections.add(_medSection(
          'Night',
          medNightBeforeOn,
          medNightAfterOn,
          nightBefore,
          nightAfter,
          (v) => medNightBeforeOn = v,
          (v) => medNightAfterOn = v,
          () => _selectTime(nightBefore, (t) => nightBefore = t),
          () => _selectTime(nightAfter, (t) => nightAfter = t)));
    return Column(children: sections);
  }

  Widget _medSection(
      String title,
      bool beforeOn,
      bool afterOn,
      TimeOfDay beforeT,
      TimeOfDay afterT,
      ValueChanged<bool> onBefore,
      ValueChanged<bool> onAfter,
      VoidCallback tapBefore,
      VoidCallback tapAfter) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1EEE6)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$title medicine',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w800, color: C.ink)),
              const SizedBox(height: 2),
              Text(
                  '${title == 'Morning' ? 'Breakfast' : title == 'Afternoon' ? 'Lunch' : 'Dinner'} linked dose',
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _muted)),
            ]),
          ),
          Switch(
            value: medicalAlarmSwitch && (beforeOn || afterOn),
            onChanged: medicalAlarmSwitch
                ? (v) => setState(() {
                      onBefore(v);
                      onAfter(v);
                    })
                : null,
            activeTrackColor: _toggleGreen,
            inactiveTrackColor: const Color(0xFFE9E7EE),
            thumbColor: WidgetStateProperty.all(Colors.white),
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ]),
        const SizedBox(height: 4),
        _scheduleRow(
          icon: Icons.medication_rounded,
          title: 'Before food',
          subtitle: 'Take 30 minutes before food',
          time: beforeT,
          enabled: medicalAlarmSwitch && beforeOn,
          onToggle:
              medicalAlarmSwitch ? (v) => setState(() => onBefore(v)) : null,
          onTap: medicalAlarmSwitch ? tapBefore : null,
        ),
        _scheduleRow(
          icon: Icons.check_circle_rounded,
          title: 'After food',
          subtitle: 'Take after food',
          time: afterT,
          enabled: medicalAlarmSwitch && afterOn,
          onToggle:
              medicalAlarmSwitch ? (v) => setState(() => onAfter(v)) : null,
          onTap: medicalAlarmSwitch ? tapAfter : null,
          isLast: true,
        ),
      ]),
    );
  }

  Widget _scheduleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required TimeOfDay time,
    required bool enabled,
    required ValueChanged<bool>? onToggle,
    required VoidCallback? onTap,
    bool isLast = false,
  }) {
    return Opacity(
      opacity: enabled ? 1 : .62,
      child: Container(
        padding: EdgeInsets.only(top: 12, bottom: isLast ? 0 : 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: isLast
                ? BorderSide.none
                : const BorderSide(color: Color(0xFFF1EEE6)),
          ),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color:
                  enabled ? const Color(0xFFEEFAF3) : const Color(0xFFF5F3F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: enabled ? C.green : _disabled, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: enabled ? C.ink : _disabled)),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: enabled ? _muted : _disabled)),
            ]),
          ),
          GestureDetector(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minWidth: 84),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: _segBg,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(_fmt(time),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF7C5C00))),
            ),
          ),
          SizedBox(
            width: 46,
            height: 36,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Switch(
                value: enabled,
                onChanged: onToggle,
                activeTrackColor: _toggleGreen,
                inactiveTrackColor: const Color(0xFFE9E7EE),
                thumbColor: WidgetStateProperty.all(Colors.white),
                trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _alarmCard(
      String title, TimeOfDay time, bool enabled, String? subtitle,
      {ValueChanged<bool>? onToggle, VoidCallback? onTap}) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: enabled ? 1 : 0.74,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                  color: enabled ? _border : const Color(0xFFE9E7EF),
                  width: enabled ? 2 : 1.4),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x11000000),
                    blurRadius: 16,
                    offset: Offset(0, 8))
              ]),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: enabled ? Colors.black87 : _disabled)),
            const SizedBox(height: 8),
            FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: RichText(
                    text: TextSpan(children: [
                  TextSpan(
                      text: _fmt(time).split(' ').first,
                      style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: enabled ? Colors.black : _disabled)),
                  TextSpan(
                      text: ' ${_fmt(time).split(' ').last}',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: enabled ? Colors.black : _disabled)),
                ]))),
            if (subtitle != null)
              Text(subtitle,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: enabled ? _muted : _disabled)),
            const Spacer(),
            Row(children: [
              Icon(Icons.alarm_outlined,
                  size: 24, color: enabled ? _accentLight : _disabled),
              const Spacer(),
              SizedBox(
                  width: 44,
                  height: 40,
                  child: FittedBox(
                      fit: BoxFit.contain,
                      alignment: Alignment.centerRight,
                      child: Switch(
                        value: enabled,
                        onChanged: onToggle,
                        activeTrackColor: _toggleGreen,
                        inactiveTrackColor: const Color(0xFFE9E7EE),
                        thumbColor: WidgetStateProperty.all(Colors.white),
                        trackOutlineColor:
                            WidgetStateProperty.all(Colors.transparent),
                      ))),
            ]),
          ]),
        ),
      ),
    );
  }

  // ── Extras panel ──────────────────────────────────────────────────────────
  Widget _extrasPanel() => Container(
        padding: const EdgeInsets.all(18),
        decoration: _card32(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              _mode == AlarmViewMode.food
                  ? 'Food alarm popup'
                  : 'Medical alarm popup',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87)),
          const SizedBox(height: 14),
          _imageCard(),
          const SizedBox(height: 12),
          _toneCard(),
        ]),
      );

  Widget _imageCard() {
    final isFood = _mode == AlarmViewMode.food;
    final file = isFood ? _foodImage : _medImage;
    final url = isFood ? _foodImageUrl : _medImageUrl;
    final type = isFood ? 'food' : 'medical';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF9E8),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFF3E3A3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isFood ? 'Food Alarm Image' : 'Medical Alarm Image',
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
        const SizedBox(height: 10),
        Container(
            height: 88,
            width: double.infinity,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: _imgPreview(file, url)),
        const SizedBox(height: 10),
        GestureDetector(
            onTap: () => _pickImage(type),
            child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: _segBg, borderRadius: BorderRadius.circular(14)),
                child: Center(
                    child: Text('Upload File',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87))))),
      ]),
    );
  }

  Widget _imgPreview(File? file, String? url) {
    if (file != null) return Image.file(file, fit: BoxFit.cover);
    if (url != null && url.isNotEmpty)
      return Image.network(url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _emptyImg('Load Failed'));
    return _emptyImg('No Image');
  }

  Widget _emptyImg(String lbl) => Container(
      color: const Color(0xFFF5F3F9),
      child: Center(
          child: Text(lbl,
              style: GoogleFonts.poppins(fontSize: 12, color: _muted))));

  Widget _toneCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: const Color(0xFFFFF9E8),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFF3E3A3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Alarm Tone',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          const SizedBox(height: 10),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Icon(Icons.music_note_rounded, color: _accent),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(
                        _recordedPreviewPath?.split(RegExp(r'[/\\]')).last ??
                            _tonePath?.split(RegExp(r'[/\\]')).last ??
                            'Select Tone',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _tonePath == null &&
                                    _recordedPreviewPath == null
                                ? _muted
                                : Colors.black87))),
                if (_tonePath != null || _recordedPreviewPath != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        _previewTone(_recordedPreviewPath ?? _tonePath),
                    icon: Icon(
                      _previewPlaying
                          ? Icons.stop_circle_rounded
                          : Icons.play_circle_fill_rounded,
                      color: _accent,
                    ),
                  ),
              ])),
          if (_recording) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (_recordSeconds.clamp(0, 15)) / 15,
              minHeight: 6,
              borderRadius: BorderRadius.circular(999),
              backgroundColor: Colors.white,
              color: C.red,
            ),
            const SizedBox(height: 6),
            Text('Recording... ${15 - _recordSeconds.clamp(0, 15)}s left',
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600, color: C.red)),
          ],
          if (_recordedPreviewPath != null && !_recording) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _accentLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Preview your recording before setting it as alarm tone.',
                      style: GoogleFonts.poppins(fontSize: 12, color: _muted)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: _miniToneAction(
                        _previewPlaying ? 'Stop' : 'Preview',
                        _previewPlaying
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                        () => _previewTone(_recordedPreviewPath),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _miniToneAction(
                        'Use Recording',
                        Icons.check_rounded,
                        _useRecordedTone,
                        filled: true,
                      ),
                    ),
                    IconButton(
                      onPressed: _discardRecording,
                      icon: const Icon(Icons.close_rounded, color: C.red),
                    ),
                  ]),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: GestureDetector(
                  onTap: _pickTone,
                  child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [_accent, _accentLight]),
                          borderRadius: BorderRadius.circular(14)),
                      child: Center(
                          child: Text('Upload Tone',
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white))))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                  onTap: _toggleVoiceRecording,
                  child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                          color: _recording ? C.red : Colors.white,
                          border: Border.all(
                              color: _recording ? C.red : _accentLight),
                          borderRadius: BorderRadius.circular(14)),
                      child: Center(
                          child: Text(
                              _recording ? 'Stop Recording' : 'Record Voice',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _recording
                                      ? Colors.white
                                      : Colors.black87))))),
            ),
          ]),
        ]),
      );

  Widget _miniToneAction(
          String label, IconData icon, FutureOr<void> Function() onTap,
          {bool filled = false}) =>
      GestureDetector(
        onTap: () => onTap(),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: filled ? _accent : const Color(0xFFFFF9E8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _accentLight),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: filled ? Colors.white : _accent),
              const SizedBox(width: 4),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: filled ? Colors.white : Colors.black87)),
              ),
            ],
          ),
        ),
      );

  Widget _saveBtn() => GestureDetector(
        onTap: _saving ? null : _save,
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_accent, _accentLight]),
              borderRadius: BorderRadius.circular(18)),
          child: Center(
              child: _saving
                  ? const CupertinoActivityIndicator(
                      radius: 12, color: Colors.white)
                  : Text('Set Alarm',
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white))),
        ),
      );

  BoxDecoration _card32() => const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(32)),
          boxShadow: [
            BoxShadow(
                color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 8))
          ]);
}
