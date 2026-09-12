import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../alaram/alarm_config_store.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_routes.dart';
import '../../services/services.dart';

const MethodChannel _alarmSetupChannel = MethodChannel('alarm_service');

class AlarmSetupScreen extends StatefulWidget {
  const AlarmSetupScreen({super.key});
  @override
  State<AlarmSetupScreen> createState() => _AlarmSetupScreenState();
}

class _AlarmSetupScreenState extends State<AlarmSetupScreen> {
  int _step = 0; // 0=Medical, 1=Food, 2=Family
  bool _saving = false;
  bool _medicalEnabled = true;
  bool _foodEnabled = true;
  final _alarmService = AlarmService();
  final _authService = AuthService();
  final _picker = ImagePicker();
  File? _medImage;
  File? _foodImage;
  String? _medImageUrl;   // server URL (loaded from API)
  String? _foodImageUrl;  // server URL (loaded from API)

  // Separate medical/food tones. All existing code below still just
  // reads/writes `_tonePath` / `_toneUrl` as if they were plain fields —
  // these getters/setters transparently route to the correct one based
  // on which step (0=Medical, 1=Food) is currently active, so picking or
  // recording a tone on the Food step never touches the Medical tone
  // and vice versa.
  String? _medTonePath, _medToneUrl;
  String? _foodTonePath, _foodToneUrl;
  String? get _tonePath => _step == 1 ? _foodTonePath : _medTonePath;
  set _tonePath(String? v) {
    if (_step == 1) { _foodTonePath = v; } else { _medTonePath = v; }
  }
  String? get _toneUrl => _step == 1 ? _foodToneUrl : _medToneUrl;
  set _toneUrl(String? v) {
    if (_step == 1) { _foodToneUrl = v; } else { _medToneUrl = v; }
  }

  String? _recordedPreviewPath;
  bool _recording = false;
  bool _previewPlaying = false;
  bool _timePickerOpen = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  // Medical
  final Map<String, String> _med = {
    'morning_before_food': '07:30 AM',
    'morning_after_food': '08:30 AM',
    'afternoon_before_food': '12:30 PM',
    'afternoon_after_food': '01:30 PM',
    'night_before_food': '08:00 PM',
    'night_after_food': '09:00 PM',
  };
  // Food
  final Map<String, String> _food = {
    'breakfast_time': '08:00 AM',
    'lunch_time': '01:00 PM',
    'dinner_time': '08:00 PM',
  };
  final Map<String, bool> _medOn = {
    'morning_before_food': true,
    'morning_after_food': true,
    'afternoon_before_food': true,
    'afternoon_after_food': true,
    'night_before_food': true,
    'night_after_food': true,
  };
  final Map<String, bool> _foodOn = {
    'breakfast_time': true,
    'lunch_time': true,
    'dinner_time': true,
  };
  // Family members added locally
  final List<Map<String, String>> _family = [];

  @override
  void initState() {
    super.initState();
    _loadSavedTone();
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _stopTonePreview();
    super.dispose();
  }

  Future<void> _loadSavedTone() async {
    final prefs = await SharedPreferences.getInstance();
    // Legacy shared local tone (from before medical/food were split) —
    // used only as a fallback if a type-specific one isn't set yet.
    final legacyLocalTone = prefs.getString('alarm_tone');
    final medLocalTone = prefs.getString('medical_alarm_tone');
    final foodLocalTone = prefs.getString('food_alarm_tone');
    if (mounted) {
      setState(() {
        _medTonePath = medLocalTone?.isNotEmpty == true
            ? medLocalTone : legacyLocalTone;
        _foodTonePath = foodLocalTone?.isNotEmpty == true
            ? foodLocalTone : legacyLocalTone;
      });
    }
    // Also load image/tone URLs from API for display
    try {
      final res = await AlarmService().getMedicalRecords();
      final rawData = res?['data'];
      if (rawData != null && mounted) {
        Map<String, dynamic> data = {};
        if (rawData is Map) data = Map<String, dynamic>.from(rawData);
        final medUrl  = data['medical_file']?.toString() ?? '';
        final foodUrl = data['food_file']?.toString() ?? '';
        final legacyToneUrl = data['alaram_tone']?.toString() ?? '';
        final medToneUrl = data['medical_tone']?.toString() ?? '';
        final foodToneUrl = data['food_tone']?.toString() ?? '';
        setState(() {
          if (medUrl.isNotEmpty) _medImageUrl = medUrl;
          if (foodUrl.isNotEmpty) _foodImageUrl = foodUrl;
          // Only use server tone URL if no local tone already picked.
          // Prefer the new type-specific field, fall back to the old
          // shared one for users who set a tone before this split.
          if (_medTonePath == null || _medTonePath!.isEmpty) {
            final url = medToneUrl.isNotEmpty ? medToneUrl : legacyToneUrl;
            if (url.isNotEmpty) _medToneUrl = url;
          }
          if (_foodTonePath == null || _foodTonePath!.isEmpty) {
            final url = foodToneUrl.isNotEmpty ? foodToneUrl : legacyToneUrl;
            if (url.isNotEmpty) _foodToneUrl = url;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _pickTime(String key, Map<String, String> map) async {
    if (_timePickerOpen) return;
    _timePickerOpen = true;
    try {
      final t = await showTimePicker(
        context: context,
        initialTime: _parseDisplayTime(map[key]) ?? TimeOfDay.now(),
        builder: (ctx, child) => Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: C.yellowDark),
          ),
          child: child ?? const SizedBox.shrink(),
        ),
      );
      if (t != null && mounted) setState(() => map[key] = t.format(context));
    } finally {
      _timePickerOpen = false;
    }
  }

  TimeOfDay? _parseDisplayTime(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false)
        .firstMatch(value.trim());
    if (match == null) return null;
    var hour = int.tryParse(match.group(1) ?? '') ?? 0;
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    final suffix = (match.group(3) ?? '').toUpperCase();
    if (suffix == 'PM' && hour != 12) hour += 12;
    if (suffix == 'AM' && hour == 12) hour = 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Widget _setupMetric(String value, String label, IconData icon) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: C.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: C.bd),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: C.yellowMid,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: C.yellowDeep, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: poppins(20, w: FontWeight.w800, c: C.ink, h: 1)),
                    const SizedBox(height: 5),
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: poppins(11, w: FontWeight.w600, c: C.txl)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _nextSetupCard() {
    final isFood = _step == 1;
    final isFamily = _step == 2;
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isFamily ? 'OPTIONAL STEP' : 'FIRST REMINDER',
                    style: poppins(11,
                        w: FontWeight.w800, c: Colors.white.withOpacity(.62))),
                const SizedBox(height: 5),
                Text(
                  isFamily
                      ? 'Family events'
                      : isFood
                          ? (_foodEnabled
                              ? 'Breakfast reminder'
                              : 'Food alarm off')
                          : (_medicalEnabled
                              ? 'Morning medicine'
                              : 'Medical alarm off'),
                  style:
                      poppins(20, w: FontWeight.w800, c: Colors.white, h: 1.15),
                ),
                const SizedBox(height: 6),
                Text(
                  isFamily
                      ? 'Birthdays and anniversaries'
                      : isFood
                          ? (_foodEnabled
                              ? 'Today at ${_food['breakfast_time']} · Food alarm'
                              : 'You can continue without food reminders')
                          : (_medicalEnabled
                              ? 'Today at ${_med['morning_before_food']} · Before food'
                              : 'You can continue without medicine reminders'),
                  style: poppins(12,
                      w: FontWeight.w500, c: Colors.white.withOpacity(.72)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.12),
              borderRadius: BorderRadius.circular(22),
              border:
                  Border.all(color: Colors.white.withOpacity(.22), width: 3),
            ),
            child: Icon(
              isFamily
                  ? Icons.cake_rounded
                  : isFood
                      ? Icons.restaurant_rounded
                      : Icons.medication_rounded,
              color: C.yellow,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumTimeRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String key,
    required Map<String, String> map,
    required bool enabled,
    required ValueChanged<bool>? onToggle,
    bool isLast = false,
  }) {
    return Container(
      padding: EdgeInsets.only(top: 12, bottom: isLast ? 0 : 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : const BorderSide(color: Color(0xFFF1EEE6)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEEFAF3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: C.green, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: poppins(14, w: FontWeight.w800, c: C.ink)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: poppins(11, w: FontWeight.w600, c: C.txl)),
              ],
            ),
          ),
          GestureDetector(
            onTap: enabled ? () => _pickTime(key, map) : null,
            child: Container(
              constraints: const BoxConstraints(minWidth: 84),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: C.yellowMid,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(map[key]!,
                  textAlign: TextAlign.center,
                  style: poppins(12, w: FontWeight.w800, c: C.yellowDeep)),
            ),
          ),
          const SizedBox(width: 6),
          Switch(
            value: enabled,
            onChanged: onToggle,
            activeColor: C.green,
          ),
        ],
      ),
    );
  }

  Widget _premiumPanel(List<Widget> children) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: C.bd),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0F000000), blurRadius: 18, offset: Offset(0, 8))
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Future<void> _pickImage(String type) async {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final f = await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                );
                if (f == null) return;
                final stored = await _persistImage(f.path);
                if (!mounted) return;
                setState(() {
                  if (type == 'medical') {
                    _medImage = stored;
                  } else {
                    _foodImage = stored;
                  }
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () async {
                Navigator.pop(context);
                final f = await _picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 85,
                );
                if (f == null) return;
                final stored = await _persistImage(f.path);
                if (!mounted) return;
                setState(() {
                  if (type == 'medical') {
                    _medImage = stored;
                  } else {
                    _foodImage = stored;
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<File> _persistImage(String sourcePath) async {
    final src = File(sourcePath);
    final dir = await getApplicationDocumentsDirectory();
    final ext = sourcePath.split('.').last;
    final target = File(
      '${dir.path}/elderzha_setup_alarm_image_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    return src.copy(target.path);
  }

  Future<void> _pickTone() async {
    await Permission.audio.request();
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'aac', 'm4a', 'ogg'],
    );
    if (picked == null || picked.files.single.path == null) return;
    final src = File(picked.files.single.path!);
    final dir = await getApplicationDocumentsDirectory();
    final target = '${dir.path}/${picked.files.single.name}';
    if (await File(target).exists()) await File(target).delete();
    await src.copy(target);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _step == 1 ? 'food_alarm_tone' : 'medical_alarm_tone', target);
    await _stopTonePreview();
    if (!mounted) return;
    setState(() {
      _tonePath = target;
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
              style: poppins(12, c: Colors.white)),
          backgroundColor: C.red,
        ),
      );
      return;
    }
    if (!_recording) {
      await _stopTonePreview();
      await _alarmSetupChannel.invokeMethod<String>('startVoiceRecording');
      if (!mounted) return;
      setState(() {
        _recording = true;
        _recordedPreviewPath = null;
        _recordSeconds = 0;
      });
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final next = _recordSeconds + 1;
        setState(() => _recordSeconds = next);
        if (next >= 15) _finishVoiceRecording();
      });
    } else {
      await _finishVoiceRecording();
    }
  }

  Future<void> _finishVoiceRecording() async {
    if (!_recording) return;
    _recordTimer?.cancel();
    final path =
        await _alarmSetupChannel.invokeMethod<String>('stopVoiceRecording');
    if (!mounted) return;
    setState(() {
      _recording = false;
      if (path != null && path.isNotEmpty) _recordedPreviewPath = path;
    });
  }

  Future<void> _showAlarmPreview({required bool isFood}) async {
    // Play whatever tone is currently selected, same as the native alarm
    // would, alongside the themed visual — a genuine preview of both.
    final tonePath = _recordedPreviewPath ?? _tonePath;
    if (tonePath != null && tonePath.isNotEmpty) {
      await _alarmSetupChannel.invokeMethod('playTonePreview', {'path': tonePath});
      if (mounted) setState(() => _previewPlaying = true);
    }

    // Match AlarmActivity.kt's resolveTheme() colors exactly, so this is
    // a true preview of what the real full-screen alarm will look like.
    final bgTop = isFood ? const Color(0xFF0B2A15) : const Color(0xFF160A33);
    final bgBottom = isFood ? const Color(0xFF1B5E20) : const Color(0xFF2D1B69);
    final accentA = const Color(0xFFFFCC01);
    final accentB = isFood ? const Color(0xFF4CAF50) : const Color(0xFFFF9500);
    final emoji = isFood ? '🍽️' : '💊';
    final title = isFood ? 'Breakfast reminder' : 'Morning medicine';
    final notes = isFood
        ? 'Time for your healthy meal'
        : 'Before food — take as prescribed';
    final okLabel = isFood ? "I've had my breakfast" : 'I\'ve taken my medicine';

    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [bgTop, bgBottom],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(children: [
                const SizedBox(height: 20),
                Text('PREVIEW — this is what will show',
                    style: poppins(11, w: FontWeight.w700,
                        c: Colors.white.withOpacity(.55))),
                const Spacer(),
                Container(
                  width: 92, height: 92,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [accentA, accentB]),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(child: Text(emoji, style: const TextStyle(fontSize: 44))),
                ),
                const SizedBox(height: 20),
                Text(title,
                    textAlign: TextAlign.center,
                    style: poppins(22, w: FontWeight.w800, c: Colors.white)),
                const SizedBox(height: 8),
                Text(notes,
                    textAlign: TextAlign.center,
                    style: poppins(13, c: Colors.white.withOpacity(.7))),
                const Spacer(),
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [accentA, accentB]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text('✓  $okLabel',
                        style: poppins(15, w: FontWeight.w800, c: const Color(0xFF1A1726))),
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text('Tap anywhere to close preview',
                      style: poppins(12, c: Colors.white.withOpacity(.6))),
                ),
              ]),
            ),
          ),
        ),
      ),
    );

    await _stopTonePreview();
  }

  Future<void> _previewTone(String? path) async {
    if (path == null || path.isEmpty) return;
    if (_previewPlaying) {
      await _stopTonePreview();
      return;
    }
    await _alarmSetupChannel.invokeMethod('playTonePreview', {'path': path});
    if (mounted) setState(() => _previewPlaying = true);
  }

  Future<void> _stopTonePreview() async {
    try {
      await _alarmSetupChannel.invokeMethod('stopTonePreview');
    } catch (_) {}
    if (mounted) setState(() => _previewPlaying = false);
  }

  Future<void> _useRecordedTone() async {
    final path = _recordedPreviewPath;
    if (path == null || path.isEmpty) return;
    await _stopTonePreview();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _step == 1 ? 'food_alarm_tone' : 'medical_alarm_tone', path);
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

  Widget _alarmMediaPanel({required bool medical}) {
    final title = medical ? 'Medical alarm tone' : 'Food alarm tone';
    return _premiumPanel([
      Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: C.yellowMid,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            medical ? Icons.medication_rounded : Icons.restaurant_rounded,
            color: C.yellowDeep,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: poppins(15, w: FontWeight.w800, c: C.ink)),
              const SizedBox(height: 2),
              Text('Choose the sound for this alarm',
                  style: poppins(11, w: FontWeight.w600, c: C.txl)),
            ],
          ),
        ),
      ]),
      const SizedBox(height: 12),
      _toneCard(),
    ]);
  }

  Widget _toneCard() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: C.yellowMid,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: C.yellowBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Alarm tone', style: poppins(13, w: FontWeight.w800, c: C.ink)),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: C.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              const Icon(Icons.music_note_rounded, color: C.yellowDark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _recordedPreviewPath?.split(RegExp(r'[/\\]')).last ??
                      _tonePath?.split(RegExp(r'[/\\]')).last ??
                      'Select tone',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: poppins(
                    12,
                    w: FontWeight.w700,
                    c: _tonePath == null && _recordedPreviewPath == null
                        ? C.txl
                        : C.ink,
                  ),
                ),
              ),
              if (_tonePath != null || _recordedPreviewPath != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      _previewTone(_recordedPreviewPath ?? _tonePath),
                  icon: Icon(
                    _previewPlaying
                        ? Icons.stop_circle_rounded
                        : Icons.play_circle_fill_rounded,
                    color: C.yellowDark,
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _showAlarmPreview(isFood: _step == 1),
            icon: const Icon(Icons.visibility_rounded, size: 18),
            label: Text('Preview this alarm',
                style: poppins(13, w: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              foregroundColor: C.ink,
              side: const BorderSide(color: C.bd, width: 1.5),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          if (_recording) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (_recordSeconds.clamp(0, 15)) / 15,
              minHeight: 6,
              borderRadius: BorderRadius.circular(999),
              backgroundColor: C.white,
              color: C.red,
            ),
            const SizedBox(height: 6),
            Text('Recording... ${15 - _recordSeconds.clamp(0, 15)}s left',
                style: poppins(11, w: FontWeight.w700, c: C.red)),
          ],
          if (_recordedPreviewPath != null && !_recording) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: _toneAction(
                  _previewPlaying ? 'Stop' : 'Preview',
                  _previewPlaying
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded,
                  () => _previewTone(_recordedPreviewPath),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _toneAction('Use', Icons.check_rounded, _useRecordedTone,
                    filled: true),
              ),
              IconButton(
                onPressed: _discardRecording,
                icon: const Icon(Icons.close_rounded, color: C.red),
              ),
            ]),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _toneAction(
                  'Upload tone', Icons.upload_file_rounded, _pickTone,
                  filled: true),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _toneAction(
                _recording ? 'Stop' : 'Record voice',
                _recording ? Icons.stop_rounded : Icons.mic_rounded,
                _toggleVoiceRecording,
                danger: _recording,
              ),
            ),
          ]),
        ]),
      );

  Widget _toneAction(String label, IconData icon, FutureOr<void> Function() tap,
          {bool filled = false, bool danger = false}) =>
      GestureDetector(
        onTap: () => tap(),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: danger
                ? C.red
                : filled
                    ? C.ink
                    : C.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
                color: danger || filled ? Colors.transparent : C.yellowBorder),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon,
                size: 16,
                color: danger || filled ? Colors.white : C.yellowDark),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: poppins(12,
                      w: FontWeight.w800,
                      c: danger || filled ? Colors.white : C.ink)),
            ),
          ]),
        ),
      );

  // Live preview — a running summary of the day forming as the
  // user sets times, so the form feels like it's building a
  // picture rather than just collecting isolated field values.
  Widget _schedulePreview() {
    const labels = {
      'morning_before_food': 'Morning (before food)',
      'morning_after_food': 'Morning (after food)',
      'afternoon_before_food': 'Afternoon (before food)',
      'afternoon_after_food': 'Afternoon (after food)',
      'night_before_food': 'Night (before food)',
      'night_after_food': 'Night (after food)',
    };
    final entries = _medOn.entries.where((e) => e.value).toList();
    if (!_medicalEnabled || entries.isEmpty) return const SizedBox.shrink();

    return _premiumPanel([
      Row(children: [
        const Icon(Icons.calendar_view_day_rounded, size: 18, color: C.yellowDark),
        const SizedBox(width: 8),
        Text('Your day so far', style: poppins(13, w: FontWeight.w800, c: C.ink)),
      ]),
      const SizedBox(height: 10),
      ...entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: C.yellowDark, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(labels[e.key] ?? e.key, style: poppins(12, c: C.txm))),
              Text(_med[e.key] ?? '', style: poppins(12, w: FontWeight.w700, c: C.ink)),
            ]),
          )),
    ]);
  }

  Widget _medStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _masterToggleCard(
            emoji: '💊',
            title: 'Medicine alarms',
            subtitle: _medicalEnabled
                ? "We've set sensible default times below"
                : 'Turned off — toggle on to set medicine alarms',
            value: _medicalEnabled,
            onChanged: (v) => setState(() => _medicalEnabled = v),
          ),
          if (_medicalEnabled) ...[
            const SizedBox(height: 12),
            _groupedMedList(),
            const SizedBox(height: 12),
            _schedulePreview(),
            const SizedBox(height: 12),
            _alarmMediaPanel(medical: true),
          ],
        ],
      );

  // The 3 food time slots, in display order.
  static const _foodQuestions = [
    ('breakfast_time', '🍳', 'Breakfast'),
    ('lunch_time', '🍽️', 'Lunch'),
    ('dinner_time', '🌙', 'Dinner'),
  ];

  Widget _masterToggleCard({
    required String emoji,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: C.yellowMid, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: C.yellow, borderRadius: BorderRadius.circular(13)),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: poppins(15, w: FontWeight.w700, c: C.ink)),
            const SizedBox(height: 2),
            Text(subtitle, style: poppins(11.5, c: C.yellowDeep)),
          ]),
        ),
        Switch(value: value, activeColor: C.ink, onChanged: onChanged),
      ]),
    );
  }

  // Groups the 6 medicine slots into 3 color-coded time-of-day
  // cards (Morning/Afternoon/Night), each showing its before/after
  // food pair side by side. Each slot keeps its own fully
  // independent switch — the card is a visual grouping only, not a
  // shared on/off control, so e.g. "before food on, after food off"
  // within the same time of day works exactly as expected.
  Widget _groupedMedList() {
    return Column(children: [
      _timeOfDayGroupCard(
        emoji: '☀️',
        label: 'MORNING',
        gradient: const [Color(0xFFFFF3C4), Color(0xFFFFE9A0)],
        labelColor: C.yellowDeep,
        beforeKey: 'morning_before_food',
        afterKey: 'morning_after_food',
      ),
      const SizedBox(height: 10),
      _timeOfDayGroupCard(
        emoji: '🌤️',
        label: 'AFTERNOON',
        gradient: const [Color(0xFFFFE0C4), Color(0xFFFFC98A)],
        labelColor: const Color(0xFF7A4A00),
        beforeKey: 'afternoon_before_food',
        afterKey: 'afternoon_after_food',
      ),
      const SizedBox(height: 10),
      _timeOfDayGroupCard(
        emoji: '🌙',
        label: 'NIGHT',
        gradient: const [Color(0xFFD8DEF5), Color(0xFFB8C4EC)],
        labelColor: const Color(0xFF1E2A6B),
        beforeKey: 'night_before_food',
        afterKey: 'night_after_food',
      ),
    ]);
  }

  Widget _timeOfDayGroupCard({
    required String emoji,
    required String label,
    required List<Color> gradient,
    required Color labelColor,
    required String beforeKey,
    required String afterKey,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(label, style: poppins(12.5, w: FontWeight.w800, c: labelColor)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _slotMiniCard('Before food', beforeKey)),
          const SizedBox(width: 8),
          Expanded(child: _slotMiniCard('After food', afterKey)),
        ]),
      ]),
    );
  }

  Widget _slotMiniCard(String label, String key) {
    final isOn = _medOn[key] ?? false;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isOn ? C.white : C.white.withOpacity(.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isOn ? C.yellowBorder : C.bd),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: poppins(10, c: C.txm))),
          Transform.scale(
            scale: .78,
            child: Switch(
              value: isOn,
              activeColor: C.ink,
              activeTrackColor: C.yellow,
              onChanged: (v) => setState(() => _medOn[key] = v),
            ),
          ),
        ]),
        if (isOn)
          GestureDetector(
            onTap: () => _showChangeTimeSheet(key, '⏰', label, _med, _medOn),
            child: Row(children: [
              Text(_med[key] ?? '', style: poppins(14.5, w: FontWeight.w800, c: C.ink)),
              const SizedBox(width: 4),
              Icon(Icons.edit_rounded, size: 12, color: C.yellowDark),
            ]),
          )
        else
          Text('Off', style: poppins(12.5, c: C.txl)),
      ]),
    );
  }

  // Reusable editable list — shown pre-filled with sensible defaults
  // (already ON, already timed), rather than asking one question at
  // a time from a blank slate. Each row has an explicit, visible
  // Switch to enable/disable that specific alarm — tapping the time
  // pill (shown only while on) opens a friendly confirmation before
  // changing the actual time.
  Widget _editableAlarmList(
    List<(String, String, String)> items,
    Map<String, String> timeMap,
    Map<String, bool> onMap,
  ) {
    return Column(children: items.map((item) {
      final key = item.$1;
      final emoji = item.$2;
      final label = item.$3;
      final isOn = onMap[key] ?? false;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isOn ? C.yellowBorder : C.bd),
        ),
        child: Row(children: [
          Text(emoji, style: TextStyle(fontSize: 20, color: isOn ? null : C.txl)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: poppins(13, w: FontWeight.w600, c: isOn ? C.ink : C.txl)),
          ),
          if (isOn) ...[
            GestureDetector(
              onTap: () => _showChangeTimeSheet(key, emoji, label, timeMap, onMap),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: C.bg2, borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(timeMap[key] ?? '', style: poppins(12.5, w: FontWeight.w700, c: C.ink)),
                  const SizedBox(width: 4),
                  Icon(Icons.edit_rounded, size: 14, color: C.yellowDark),
                ]),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Switch(
            value: isOn,
            activeColor: C.ink,
            activeTrackColor: C.yellow,
            onChanged: (v) => setState(() => onMap[key] = v),
          ),
        ]),
      );
    }).toList());
  }

  // Friendly bottom-sheet confirmation before actually changing a
  // time that's already set — prevents an accidental tap from
  // silently overwriting a time the user meant to keep.
  Future<void> _showChangeTimeSheet(
    String key,
    String emoji,
    String label,
    Map<String, String> timeMap,
    Map<String, bool> onMap,
  ) async {
    final currentTime = timeMap[key] ?? '';
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
        decoration: const BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: C.bd, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 18),
          Text(emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 10),
          Text('Change $label time?', textAlign: TextAlign.center, style: poppins(16, w: FontWeight.w800, c: C.ink)),
          const SizedBox(height: 4),
          Text('Currently $currentTime', style: poppins(12.5, c: C.txm)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(color: C.bg2, borderRadius: BorderRadius.circular(13)),
                  child: Center(child: Text('Keep $currentTime', style: poppins(12.5, w: FontWeight.w600, c: C.txm))),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(color: C.yellow, borderRadius: BorderRadius.circular(13)),
                  child: Center(child: Text('Pick new time', style: poppins(12.5, w: FontWeight.w700, c: C.ink))),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
    if (result == true) {
      await _pickTime(key, timeMap);
      if (!mounted) return;
      setState(() {
        onMap[key] = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$label updated to ${timeMap[key]}', style: poppins(12, c: C.white)),
            backgroundColor: const Color(0xFF3B6D11),
            duration: const Duration(seconds: 2),
          ));
        }
      });
    }
  }

  Widget _foodStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _masterToggleCard(
            emoji: '🍽️',
            title: 'Meal reminders',
            subtitle: _foodEnabled
                ? "We've set sensible default times below"
                : 'Turned off — toggle on to set meal reminders',
            value: _foodEnabled,
            onChanged: (v) => setState(() => _foodEnabled = v),
          ),
          if (_foodEnabled) ...[
            const SizedBox(height: 12),
            _editableAlarmList(_foodQuestions, _food, _foodOn),
            const SizedBox(height: 12),
            _foodSchedulePreview(),
            const SizedBox(height: 12),
            _alarmMediaPanel(medical: false),
          ],
        ],
      );

  Widget _foodSchedulePreview() {
    const labels = {
      'breakfast_time': 'Breakfast',
      'lunch_time': 'Lunch',
      'dinner_time': 'Dinner',
    };
    final entries = _foodOn.entries.where((e) => e.value).toList();
    if (!_foodEnabled || entries.isEmpty) return const SizedBox.shrink();

    return _premiumPanel([
      Row(children: [
        const Icon(Icons.calendar_view_day_rounded, size: 18, color: C.yellowDark),
        const SizedBox(width: 8),
        Text('Your meals so far', style: poppins(13, w: FontWeight.w800, c: C.ink)),
      ]),
      const SizedBox(height: 10),
      ...entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: C.yellowDark, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(labels[e.key] ?? e.key, style: poppins(12, c: C.txm))),
              Text(_food[e.key] ?? '', style: poppins(12, w: FontWeight.w700, c: C.ink)),
            ]),
          )),
    ]);
  }

  Widget _familyStep() => Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFBEAF0),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(children: [
              const Text('🌳', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 8),
              Text('Add your family', style: poppins(16, w: FontWeight.w800, c: C.ink)),
              const SizedBox(height: 4),
              Text(
                "We'll remind you of their birthdays, anniversaries, and important events — and build your Family Tree as you go.",
                textAlign: TextAlign.center,
                style: poppins(12, c: C.txm, h: 1.4),
              ),
            ]),
          ),
          GestureDetector(
            onTap: _addFamilySheet,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: C.yellow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  '+ Add family member',
                  style: poppins(14, w: FontWeight.w700, c: C.ink),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_family.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: C.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: C.bd),
              ),
              child: Column(
                children: [
                  const Text('👨‍👩‍👧', style: TextStyle(fontSize: 32)),
                  const SizedBox(height: 8),
                  Text('No family members yet', style: poppins(13, c: C.txl)),
                  Text('Optional — skip to proceed',
                      style: poppins(11, c: C.txl)),
                ],
              ),
            )
          else
            ..._family.map(
              (m) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: C.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: C.bd),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: C.yellowMid,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (m['name']?.isNotEmpty == true ? m['name']![0] : 'F')
                            .toUpperCase(),
                        style: poppins(16, w: FontWeight.w800, c: C.yellowDeep),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m['name'] ?? 'Family member',
                              style: poppins(13, w: FontWeight.w800, c: C.ink)),
                          if ((m['relation'] ?? '').isNotEmpty)
                            Text(m['relation']!, style: poppins(11, c: C.txl)),
                          const SizedBox(height: 6),
                          Wrap(spacing: 6, runSpacing: 5, children: [
                            if ((m['birthday_date'] ?? '').isNotEmpty)
                              _familyChip(
                                  '🎂 Birthday · ${m['birthday_date']}',
                                  const Color(0xFFFCE4EC),
                                  const Color(0xFFC2185B)),
                            if ((m['anniversary_date'] ?? '').isNotEmpty)
                              _familyChip(
                                  '💍 Anniversary · ${m['anniversary_date']}',
                                  C.blueLight,
                                  const Color(0xFF0D47A1)),
                          ]),
                        ]),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _family.remove(m)),
                    child: const Icon(Icons.close, size: 18, color: C.txl),
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: C.yellowMid,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.yellowBorder),
            ),
            child: Row(
              children: [
                const Text('🔔', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "You'll be reminded 1 day before every birthday and anniversary",
                    style: poppins(11, w: FontWeight.w600, c: C.yellowDeep),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  void _addFamilySheet() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _AddFamilySheet(),
    );
    if (result != null) setState(() => _family.add(result));
  }

  void _next() async {
    if (_step < 2) {
      setState(() => _step++);
      return;
    }
    // Final step — save alarms and proceed to payment
    setState(() => _saving = true);
    final payload = _alarmPayload();
    // NOTE: _step is 2 (Family) here, so reference the medical/food
    // backing fields directly rather than through _tonePath/_toneUrl
    // (which dispatch based on _step and would incorrectly resolve to
    // Medical only at this point in the flow).
    await _alarmService.saveMedicalSettingsMultipart(
      payload: payload,
      medicalFile: _medImage,
      foodFile: _foodImage,
      medicalTone: _medTonePath != null && File(_medTonePath!).existsSync()
          ? File(_medTonePath!)
          : null,
      foodTone: _foodTonePath != null && File(_foodTonePath!).existsSync()
          ? File(_foodTonePath!)
          : null,
    );
    await _saveLocalAlarmConfig(payload);
    await _saveSetupFamilyFallback();
    final familySaveErrors = <String>[];
    final familySaveResults = <String>[];
    if (_family.isEmpty) {
      familySaveResults.add('(no family members were added at this step)');
    }
    for (final member in _family) {
      final res = await _authService.addFamily(
        name: member['name'] ?? '',
        relation: member['relation'] ?? '',
        birthdayDate: member['birthday_date']?.isEmpty == true
            ? null
            : member['birthday_date'],
        anniversaryDate: member['anniversary_date']?.isEmpty == true
            ? null
            : member['anniversary_date'],
      );
      final name = member['name'] ?? 'Member';
      if (res['status'] != true && res['data'] == null) {
        final err = res['message']?.toString() ??
            res['errors']?.toString() ?? 'unknown error';
        familySaveErrors.add('$name: $err');
        familySaveResults.add('$name → FAILED: $res');
      } else {
        familySaveResults.add('$name → OK: $res');
      }
    }
    await _saveAlarmSummary();
    setState(() => _saving = false);
    if (!mounted) return;
    if (!mounted) return;
    if (familySaveErrors.isNotEmpty) {
      // Surface the real failure instead of silently proceeding as if
      // every family member saved — this was previously discarded,
      // which is why members could appear in Reminders (a purely local
      // schedule cache) but never actually show up in Family Members
      // (which reads from the server).
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Some family members did not save',
              style: poppins(16, w: FontWeight.w700, c: C.ink)),
          content: Text(
            '${familySaveErrors.join('\n\n')}\n\n'
            'You can re-add them later from Profile > Family Members.',
            style: poppins(13, c: C.txm, h: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK',
                  style: poppins(14, w: FontWeight.w700, c: C.yellowDark)),
            ),
          ],
        ),
      );
      if (!mounted) return;
    }
    Navigator.pushReplacementNamed(context, AppRoutes.payment);
  }

  Future<void> _saveSetupFamilyFallback() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('setup_family_members', jsonEncode(_family));
  }

  Future<void> _saveLocalAlarmConfig(Map<String, dynamic> payload) async {
    await AlarmConfigStore.save({
      ...payload,
      if (_medImage != null) 'medical_file': _medImage!.path,
      if (_foodImage != null) 'food_file': _foodImage!.path,
      // Separate medical/food tones — DailyScheduler picks the right
      // one based on which alarm type is actually firing.
      if (_medTonePath != null && _medTonePath!.isNotEmpty)
        'medical_tone': _medTonePath
      else if (_medToneUrl != null && _medToneUrl!.isNotEmpty)
        'medical_tone': _medToneUrl,
      if (_foodTonePath != null && _foodTonePath!.isNotEmpty)
        'food_tone': _foodTonePath
      else if (_foodToneUrl != null && _foodToneUrl!.isNotEmpty)
        'food_tone': _foodToneUrl,
      'saved_from': 'first_time_setup',
      'saved_at': DateTime.now().toIso8601String(),
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_time_alarm_setup_completed', true);
  }

  bool _isMedOn(String key) => _medicalEnabled && (_medOn[key] ?? false);
  bool _isFoodOn(String key) => _foodEnabled && (_foodOn[key] ?? false);
  int get _enabledMedCount => _medOn.keys.where(_isMedOn).length;
  int get _enabledFoodCount => _foodOn.keys.where(_isFoodOn).length;

  Map<String, dynamic> _alarmPayload() => {
        'medical_alarm': _medicalEnabled ? 1 : 0,
        // Backend DB columns: m_before_food, m_after_food, af_before_food, etc.
        // Also send long names as aliases for getMedicalRecords compatibility
        'morning_status':
            (_isMedOn('morning_before_food') || _isMedOn('morning_after_food'))
                ? 1
                : 0,
        'm_before_food': _isMedOn('morning_before_food')
            ? _apiTime(_med['morning_before_food']!)
            : '',
        'm_after_food': _isMedOn('morning_after_food')
            ? _apiTime(_med['morning_after_food']!)
            : '',
        'morning_before_food': _isMedOn('morning_before_food')
            ? _apiTime(_med['morning_before_food']!)
            : '',
        'morning_after_food': _isMedOn('morning_after_food')
            ? _apiTime(_med['morning_after_food']!)
            : '',
        'afternoon_status': (_isMedOn('afternoon_before_food') ||
                _isMedOn('afternoon_after_food'))
            ? 1
            : 0,
        'af_before_food': _isMedOn('afternoon_before_food')
            ? _apiTime(_med['afternoon_before_food']!)
            : '',
        'af_after_food': _isMedOn('afternoon_after_food')
            ? _apiTime(_med['afternoon_after_food']!)
            : '',
        'afternoon_before_food': _isMedOn('afternoon_before_food')
            ? _apiTime(_med['afternoon_before_food']!)
            : '',
        'afternoon_after_food': _isMedOn('afternoon_after_food')
            ? _apiTime(_med['afternoon_after_food']!)
            : '',
        'night_status':
            (_isMedOn('night_before_food') || _isMedOn('night_after_food'))
                ? 1
                : 0,
        'n_before_food': _isMedOn('night_before_food')
            ? _apiTime(_med['night_before_food']!)
            : '',
        'n_after_food': _isMedOn('night_after_food')
            ? _apiTime(_med['night_after_food']!)
            : '',
        'night_before_food': _isMedOn('night_before_food')
            ? _apiTime(_med['night_before_food']!)
            : '',
        'night_after_food': _isMedOn('night_after_food')
            ? _apiTime(_med['night_after_food']!)
            : '',
        'food_alaram': _foodEnabled ? 1 : 0,
        'food_alarm':  _foodEnabled ? 1 : 0,
        'breakfast_status': _isFoodOn('breakfast_time') ? 1 : 0,
        'bf_time': _isFoodOn('breakfast_time')
            ? _apiTime(_food['breakfast_time']!)
            : '',
        'breakfast_time': _isFoodOn('breakfast_time')
            ? _apiTime(_food['breakfast_time']!)
            : '',
        'lunch_status': _isFoodOn('lunch_time') ? 1 : 0,
        'l_time': _isFoodOn('lunch_time')
            ? _apiTime(_food['lunch_time']!) : '',
        'lunch_time': _isFoodOn('lunch_time')
            ? _apiTime(_food['lunch_time']!) : '',
        'dinner_status': _isFoodOn('dinner_time') ? 1 : 0,
        'd_time': _isFoodOn('dinner_time')
            ? _apiTime(_food['dinner_time']!) : '',
        'dinner_time': _isFoodOn('dinner_time')
            ? _apiTime(_food['dinner_time']!) : '',
      };

  String _apiTime(String value) {
    final text = value.trim();
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return text;
    var hour = int.parse(match.group(1)!);
    final minute = match.group(2)!;
    final suffix = match.group(3)!.toUpperCase();
    if (suffix == 'PM' && hour != 12) hour += 12;
    if (suffix == 'AM' && hour == 12) hour = 0;
    return '${hour.toString().padLeft(2, '0')}:$minute:00';
  }

  Future<void> _saveAlarmSummary() async {
    final prefs = await SharedPreferences.getInstance();
    // Mark alarm setup as completed — used by profile to show 'Configured'
    await prefs.setBool('first_time_alarm_setup_completed', true);
    final items = [
      if (_isMedOn('morning_before_food'))
        {
          'label': 'Morning medication before food',
          'time': _med['morning_before_food'],
          'icon': '💊',
        },
      if (_isMedOn('morning_after_food'))
        {
          'label': 'Morning medication after food',
          'time': _med['morning_after_food'],
          'icon': '💊',
        },
      if (_isMedOn('afternoon_before_food'))
        {
          'label': 'Afternoon medication before food',
          'time': _med['afternoon_before_food'],
          'icon': '💊',
        },
      if (_isMedOn('afternoon_after_food'))
        {
          'label': 'Afternoon medication after food',
          'time': _med['afternoon_after_food'],
          'icon': '💊',
        },
      if (_isMedOn('night_before_food'))
        {
          'label': 'Night medication before food',
          'time': _med['night_before_food'],
          'icon': '🌙',
        },
      if (_isMedOn('night_after_food'))
        {
          'label': 'Night medication after food',
          'time': _med['night_after_food'],
          'icon': '🌙',
        },
      if (_isFoodOn('breakfast_time'))
        {
          'label': 'Breakfast reminder',
          'time': _food['breakfast_time'],
          'icon': '🍳',
        },
      if (_isFoodOn('lunch_time'))
        {'label': 'Lunch reminder', 'time': _food['lunch_time'], 'icon': '🍱'},
      if (_isFoodOn('dinner_time'))
        {
          'label': 'Dinner reminder',
          'time': _food['dinner_time'],
          'icon': '🍽'
        },
      ..._family.map(
        (m) => {
          'label': '${m['name']} family event',
          'time': [
            if ((m['birthday_date'] ?? '').isNotEmpty) m['birthday_date'],
            if ((m['anniversary_date'] ?? '').isNotEmpty) m['anniversary_date'],
          ].join(' · '),
          'icon': '🎂',
        },
      ),
    ];
    await prefs.setString('setup_alarm_summary', jsonEncode(items));
  }

  Widget _familyChip(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: poppins(10, w: FontWeight.w800, c: fg)),
      );

  final _stepLabels = ['Medical Alarm', 'Food Alarm', 'Family Members'];
  final _stepDescs = [
    'Set medication reminders around your meals',
    'Set your daily meal reminders',
    'Add birthdays & anniversaries (optional)',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(
        children: [
          // Yellow header with step indicator
          Container(
            color: C.yellow,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alarm setup',
                      style: poppins(24, w: FontWeight.w800, c: C.ink, h: 1.05),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This powers your Reminders & Alarms feature — so you never miss a dose',
                      style: poppins(12, w: FontWeight.w600, c: C.yellowDeep),
                    ),
                    const SizedBox(height: 14),
                    // Step indicator
                    Row(
                      children: List.generate(3, (i) {
                        final done = i < _step;
                        final active = i == _step;
                        return Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: done
                                            ? C.green
                                            : active
                                                ? C.ink
                                                : C.white.withOpacity(0.4),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: done
                                            ? const Icon(
                                                Icons.check,
                                                size: 15,
                                                color: Colors.white,
                                              )
                                            : Text(
                                                '${i + 1}',
                                                style: poppins(
                                                  13,
                                                  w: FontWeight.w700,
                                                  c: active ? C.yellow : C.txm,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _stepLabels[i],
                                      style: poppins(
                                        9,
                                        w: active
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        c: active ? C.ink : C.yellowDeep,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                              if (i < 2)
                                Container(
                                  height: 2,
                                  width: 20,
                                  margin: const EdgeInsets.only(bottom: 18),
                                  color: i < _step
                                      ? C.green
                                      : C.white.withOpacity(0.4),
                                ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // White body
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: C.bg,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _stepLabels[_step],
                            style: poppins(20, w: FontWeight.w800, c: C.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(_stepDescs[_step],
                              style: poppins(12, w: FontWeight.w600, c: C.txl)),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _setupMetric(
                                _step == 2
                                    ? _family.length.toString()
                                    : (_step == 1
                                        ? _enabledFoodCount.toString()
                                        : _enabledMedCount.toString()),
                                _step == 2 ? 'Family added' : 'Alarms',
                                _step == 2
                                    ? Icons.group_rounded
                                    : Icons.notifications_active_rounded,
                              ),
                              const SizedBox(width: 10),
                              _setupMetric(
                                _step == 2 ? '1d' : 'Daily',
                                _step == 2 ? 'Before event' : 'Repeat',
                                _step == 2
                                    ? Icons.event_available_rounded
                                    : Icons.repeat_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _nextSetupCard(),
                          const SizedBox(height: 14),
                          if (_step == 0) _medStep(),
                          if (_step == 1) _foodStep(),
                          if (_step == 2) _familyStep(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Column(
                      children: [
                        if (_step > 0) ...[
                          GestureDetector(
                            onTap: () => setState(() => _step--),
                            child: Container(
                              width: double.infinity,
                              height: 48,
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: C.bd2, width: 1.5),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Text(
                                  '← Back',
                                  style: poppins(
                                    13,
                                    w: FontWeight.w700,
                                    c: C.ink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        GestureDetector(
                          onTap: _saving ? null : _next,
                          child: Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              color: C.ink,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: _saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: C.yellow,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _step < 2
                                          ? 'Continue →'
                                          : 'Proceed to Payment →',
                                      style: poppins(
                                        14,
                                        w: FontWeight.w700,
                                        c: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddFamilySheet extends StatefulWidget {
  const _AddFamilySheet();
  @override
  State<_AddFamilySheet> createState() => _AddFamilySheetState();
}

class _AddFamilySheetState extends State<_AddFamilySheet> {
  final _nameCtrl = TextEditingController();
  final _birthdayCtrl = TextEditingController();
  final _anniversaryCtrl = TextEditingController();
  DateTime? _birthdayDate;
  DateTime? _anniversaryDate;
  String _relation = 'Spouse';
  final _relations = [
    'Mother', 'Father', 'Spouse', 'Son', 'Daughter',
    'Grand Son', 'Grand Daughter', 'Son in law', 'Daughter in law',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _birthdayCtrl.dispose();
    _anniversaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required TextEditingController ctrl,
    required ValueChanged<DateTime?> onPicked,
    required DateTime? initialDate,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 120),
      lastDate: DateTime(DateTime.now().year + 20),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: C.yellowDark),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      onPicked(picked);
      ctrl.text = _formatDate(picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 18,
        right: 18,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add family member',
            style: poppins(17, w: FontWeight.w700, c: C.ink),
          ),
          const SizedBox(height: 14),
          Text(
            'RELATION',
            style: poppins(11, w: FontWeight.w700, c: C.txl),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _relations.map((r) {
              final sel = _relation == r;
              return GestureDetector(
                onTap: () => setState(() => _relation = r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: sel ? C.yellowLight : C.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sel ? C.yellow : C.bd,
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    r,
                    style: poppins(
                      12,
                      w: FontWeight.w700,
                      c: sel ? C.yellowDeep : C.txm,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Member name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _dateTile(
                emoji: '🎂',
                title: 'Birthday',
                ctrl: _birthdayCtrl,
                onTap: () => _pickDate(
                  ctrl: _birthdayCtrl,
                  initialDate: _birthdayDate,
                  onPicked: (d) => _birthdayDate = d,
                ),
                onClear: () => setState(() {
                  _birthdayCtrl.clear();
                  _birthdayDate = null;
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _dateTile(
                emoji: '💍',
                title: 'Anniversary',
                ctrl: _anniversaryCtrl,
                onTap: () => _pickDate(
                  ctrl: _anniversaryCtrl,
                  initialDate: _anniversaryDate,
                  onPicked: (d) => _anniversaryDate = d,
                ),
                onClear: () => setState(() {
                  _anniversaryCtrl.clear();
                  _anniversaryDate = null;
                }),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {
              if (_nameCtrl.text.trim().isEmpty ||
                  (_birthdayCtrl.text.isEmpty &&
                      _anniversaryCtrl.text.isEmpty)) {
                return;
              }
              Navigator.pop(context, {
                'name': _nameCtrl.text.trim(),
                'relation': _relation,
                'birthday_date': _birthdayCtrl.text,
                'anniversary_date': _anniversaryCtrl.text,
              });
            },
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: C.yellow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  'Save member',
                  style: poppins(14, w: FontWeight.w700, c: C.ink),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _dateTile({
    required String emoji,
    required String title,
    required TextEditingController ctrl,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final hasDate = ctrl.text.trim().isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasDate ? C.yellowLight : C.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasDate ? C.yellow : C.bd,
            width: hasDate ? 2 : 1,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const Spacer(),
            if (hasDate)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded, size: 16, color: C.txl),
              ),
          ]),
          const SizedBox(height: 6),
          Text(title,
              style: poppins(11,
                  w: FontWeight.w800, c: hasDate ? C.yellowDeep : C.txm)),
          const SizedBox(height: 5),
          Text(hasDate ? ctrl.text : 'Select date',
              style:
                  poppins(10, w: FontWeight.w600, c: hasDate ? C.ink : C.txl)),
        ]),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
}