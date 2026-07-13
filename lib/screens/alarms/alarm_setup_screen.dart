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
import '../../alaram/daily_scheduler.dart';
import '../../alaram/alarm_config_store.dart';
import '../../alaram/family_event_scheduler.dart';
import '../../api/models/fetch_profile_model.dart';
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
  String? _tonePath;
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
    final tone = prefs.getString('alarm_tone');
    if (!mounted || tone == null || tone.isEmpty) return;
    setState(() => _tonePath = tone);
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
    await prefs.setString('alarm_tone', target);
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

  Widget _alarmMediaPanel({required bool medical}) {
    final image = medical ? _medImage : _foodImage;
    final title = medical ? 'Medical alarm media' : 'Food alarm media';
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
              Text('Photo and custom alarm tone',
                  style: poppins(11, w: FontWeight.w600, c: C.txl)),
            ],
          ),
        ),
      ]),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () => _pickImage(medical ? 'medical' : 'food'),
        child: Container(
          height: 136,
          width: double.infinity,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: C.bg2,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: C.bd),
          ),
          child: image == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_photo_alternate_outlined,
                        color: C.txl, size: 30),
                    const SizedBox(height: 6),
                    Text('Upload alarm image',
                        style: poppins(12, w: FontWeight.w700, c: C.txm)),
                  ],
                )
              : Image.file(image, fit: BoxFit.cover),
        ),
      ),
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

  Widget _medStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _alarmMasterToggle(
            title: 'Medical alarm',
            subtitle: 'Turn on all medicine reminders',
            value: _medicalEnabled,
            icon: Icons.medication_rounded,
            onChanged: (v) => setState(() {
              _medicalEnabled = v;
              for (final key in _medOn.keys) {
                _medOn[key] = v;
              }
            }),
          ),
          const SizedBox(height: 12),
          IgnorePointer(
            ignoring: !_medicalEnabled,
            child: Opacity(
              opacity: _medicalEnabled ? 1 : .42,
              child: Column(
                children: [
                  _medicalGroup(
                    'Morning medicine',
                    'Breakfast linked dose',
                    Icons.wb_sunny_rounded,
                    'morning_before_food',
                    'morning_after_food',
                  ),
                  const SizedBox(height: 12),
                  _medicalGroup(
                    'Afternoon medicine',
                    'Lunch linked dose',
                    Icons.wb_twilight_rounded,
                    'afternoon_before_food',
                    'afternoon_after_food',
                  ),
                  const SizedBox(height: 12),
                  _medicalGroup(
                    'Night medicine',
                    'Dinner linked dose',
                    Icons.nightlight_round,
                    'night_before_food',
                    'night_after_food',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _alarmMediaPanel(medical: true),
        ],
      );

  Widget _alarmMasterToggle({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
  }) =>
      _premiumPanel([
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: value ? C.greenLight : C.bg3,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: value ? C.green : C.txl, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: poppins(15, w: FontWeight.w800, c: C.ink)),
                    const SizedBox(height: 2),
                    Text(value ? subtitle : 'Alarm is off',
                        style: poppins(11, w: FontWeight.w600, c: C.txl)),
                  ]),
            ),
            Switch(
              value: value,
              activeColor: C.green,
              onChanged: onChanged,
            ),
          ],
        ),
      ]);

  Widget _medicalGroup(String title, String subtitle, IconData icon,
      String beforeKey, String afterKey) {
    return _premiumPanel([
      Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: C.yellowMid,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: C.yellowDeep, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: poppins(14, w: FontWeight.w800, c: C.ink)),
              const SizedBox(height: 2),
              Text(subtitle, style: poppins(11, w: FontWeight.w600, c: C.txl)),
            ]),
          ),
        ],
      ),
      const SizedBox(height: 4),
      _premiumTimeRow(
        icon: Icons.medication_rounded,
        title: 'Before food',
        subtitle: 'Take 30 minutes before food',
        key: beforeKey,
        map: _med,
        enabled: _medicalEnabled && (_medOn[beforeKey] ?? true),
        onToggle: _medicalEnabled
            ? (v) => setState(() => _medOn[beforeKey] = v)
            : null,
      ),
      _premiumTimeRow(
        icon: Icons.check_circle_rounded,
        title: 'After food',
        subtitle: 'Take after food',
        key: afterKey,
        map: _med,
        enabled: _medicalEnabled && (_medOn[afterKey] ?? true),
        onToggle: _medicalEnabled
            ? (v) => setState(() => _medOn[afterKey] = v)
            : null,
        isLast: true,
      ),
    ]);
  }

  Widget _foodStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _alarmMasterToggle(
            title: 'Food alarm',
            subtitle: 'Turn on breakfast, lunch and dinner',
            value: _foodEnabled,
            icon: Icons.restaurant_rounded,
            onChanged: (v) => setState(() {
              _foodEnabled = v;
              for (final key in _foodOn.keys) {
                _foodOn[key] = v;
              }
            }),
          ),
          const SizedBox(height: 12),
          IgnorePointer(
            ignoring: !_foodEnabled,
            child: Opacity(
              opacity: _foodEnabled ? 1 : .42,
              child: _premiumPanel([
                _premiumTimeRow(
                  icon: Icons.wb_sunny_rounded,
                  title: 'Breakfast',
                  subtitle: 'Morning meal reminder',
                  key: 'breakfast_time',
                  map: _food,
                  enabled: _foodEnabled && (_foodOn['breakfast_time'] ?? true),
                  onToggle: _foodEnabled
                      ? (v) => setState(() => _foodOn['breakfast_time'] = v)
                      : null,
                ),
                _premiumTimeRow(
                  icon: Icons.restaurant_rounded,
                  title: 'Lunch',
                  subtitle: 'Afternoon meal reminder',
                  key: 'lunch_time',
                  map: _food,
                  enabled: _foodEnabled && (_foodOn['lunch_time'] ?? true),
                  onToggle: _foodEnabled
                      ? (v) => setState(() => _foodOn['lunch_time'] = v)
                      : null,
                ),
                _premiumTimeRow(
                  icon: Icons.nightlight_round,
                  title: 'Dinner',
                  subtitle: 'Night meal reminder',
                  key: 'dinner_time',
                  map: _food,
                  enabled: _foodEnabled && (_foodOn['dinner_time'] ?? true),
                  onToggle: _foodEnabled
                      ? (v) => setState(() => _foodOn['dinner_time'] = v)
                      : null,
                  isLast: true,
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          _alarmMediaPanel(medical: false),
        ],
      );

  Widget _familyStep() => Column(
        children: [
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
    await _alarmService.saveMedicalSettingsMultipart(
      payload: payload,
      medicalFile: _medImage,
      foodFile: _foodImage,
      alarmTone: _tonePath != null && File(_tonePath!).existsSync()
          ? File(_tonePath!)
          : null,
    );
    await _saveLocalAlarmConfig(payload);
    await _saveSetupFamilyFallback();
    for (final member in _family) {
      await _authService.addFamily(
        name: member['name'] ?? '',
        relation: member['relation'] ?? '',
        birthdayDate: member['birthday_date']?.isEmpty == true
            ? null
            : member['birthday_date'],
        anniversaryDate: member['anniversary_date']?.isEmpty == true
            ? null
            : member['anniversary_date'],
      );
    }
    await _saveAlarmSummary();
    await _scheduleLocalAlarms();
    await _scheduleLocalFamilyEvents();
    setState(() => _saving = false);
    if (!mounted) return;
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
      if (_tonePath != null && _tonePath!.isNotEmpty) 'alaram_tone': _tonePath,
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
        'morning_status':
            (_isMedOn('morning_before_food') || _isMedOn('morning_after_food'))
                ? 1
                : 0,
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
        'night_before_food': _isMedOn('night_before_food')
            ? _apiTime(_med['night_before_food']!)
            : '',
        'night_after_food': _isMedOn('night_after_food')
            ? _apiTime(_med['night_after_food']!)
            : '',
        'food_alarm': _foodEnabled ? 1 : 0,
        'breakfast_status': _isFoodOn('breakfast_time') ? 1 : 0,
        'breakfast_time': _isFoodOn('breakfast_time')
            ? _apiTime(_food['breakfast_time']!)
            : '',
        'lunch_status': _isFoodOn('lunch_time') ? 1 : 0,
        'lunch_time':
            _isFoodOn('lunch_time') ? _apiTime(_food['lunch_time']!) : '',
        'dinner_status': _isFoodOn('dinner_time') ? 1 : 0,
        'dinner_time':
            _isFoodOn('dinner_time') ? _apiTime(_food['dinner_time']!) : '',
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

  Future<void> _scheduleLocalAlarms() async {
    await DailyScheduler.cancelAllAlarms();
    await DailyScheduler.clearStoredAlarms();
    if (_medicalEnabled) {
      for (final item in [
        [
          'morning_before_food',
          'Morning medication before food',
          AlarmType.medical
        ],
        [
          'morning_after_food',
          'Morning medication after food',
          AlarmType.medical
        ],
        [
          'afternoon_before_food',
          'Afternoon medication before food',
          AlarmType.medical
        ],
        [
          'afternoon_after_food',
          'Afternoon medication after food',
          AlarmType.medical
        ],
        [
          'night_before_food',
          'Night medication before food',
          AlarmType.medical
        ],
        ['night_after_food', 'Night medication after food', AlarmType.medical],
      ]) {
        final key = item[0] as String;
        if (!_isMedOn(key)) continue;
        final label = item[1] as String;
        final type = item[2] as AlarmType;
        final time = _apiTime(_med[key]!);
        await DailyScheduler.scheduleReminder(
          type,
          _schedDate(time),
          time,
          'ElderZha • $label',
          'daily',
          soundUrl: _tonePath,
          imageUrl: _medImage?.path,
        );
      }
    }
    if (_foodEnabled) {
      for (final item in [
        ['breakfast_time', 'Breakfast reminder'],
        ['lunch_time', 'Lunch reminder'],
        ['dinner_time', 'Dinner reminder'],
      ]) {
        final key = item[0];
        if (!_isFoodOn(key)) continue;
        final label = item[1];
        final time = _apiTime(_food[key]!);
        await DailyScheduler.scheduleReminder(
          AlarmType.food,
          _schedDate(time),
          time,
          'ElderZha • $label',
          'daily',
          soundUrl: _tonePath,
          imageUrl: _foodImage?.path,
        );
      }
    }
  }

  String _schedDate(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    var dt = DateTime(DateTime.now().year, DateTime.now().month,
        DateTime.now().day, hour, minute);
    if (dt.isBefore(DateTime.now())) dt = dt.add(const Duration(days: 1));
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _scheduleLocalFamilyEvents() async {
    if (_family.isEmpty) return;
    final members = <FamilyMember>[];
    for (final entry in _family.asMap().entries) {
      final m = entry.value;
      void add(String suffix, String eventName, String date) {
        if (date.trim().isEmpty) return;
        members.add(FamilyMember(
          id: 'setup-${entry.key}-$suffix',
          type: '',
          status: '1',
          name: m['name'] ?? '',
          eventDate: date,
          relation: Event(id: '0', name: m['relation'] ?? ''),
          event:
              Event(id: suffix == 'anniversary' ? '2' : '1', name: eventName),
        ));
      }

      add('birthday', 'Birthday', m['birthday_date'] ?? '');
      add('anniversary', 'Anniversary', m['anniversary_date'] ?? '');
    }
    await FamilyEventScheduler.syncFamilyEventReminders(members);
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
                      'Create your first medical, food and family reminders',
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
    'Spouse',
    'Child',
    'Parent',
    'Sibling',
    'Friend',
    'Other',
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
