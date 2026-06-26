import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/services.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});
  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _actService = ActivityService();

  bool _loadingMaster = true;
  bool _submitting = false;
  bool _showSuccess = false;
  int _q = 0;

  // ── Master data from API ──────────────────────────────────
  List _moodOpts = [];
  List _peopleOpts = [];
  List _placeOpts = [];
  List _actOpts = [];
  List _weatherOpts = [];

  // ── Fallback static options (reference HTML) ──────────────
  static const _defaultMoods = [
    {'v': 'happy', 'e': '😊', 'l': 'Happy'},
    {'v': 'sad', 'e': '😔', 'l': 'Sad'},
    {'v': 'love', 'e': '🥰', 'l': 'Love'},
    {'v': 'angry', 'e': '😤', 'l': 'Angry'},
    {'v': 'fear', 'e': '😨', 'l': 'Fear'},
    {'v': 'disgust', 'e': '🤢', 'l': 'Disgust'},
    {'v': 'confused', 'e': '😕', 'l': 'Confused'},
    {'v': 'excited', 'e': '🤩', 'l': 'Excited'},
  ];
  static const _defaultPeople = [
    {'v': 'family', 'e': '👨‍👩‍👧', 'l': 'Family'},
    {'v': 'friends', 'e': '👫', 'l': 'Friends'},
    {'v': 'neighbours', 'e': '🏘️', 'l': 'Neighbours'},
    {'v': 'strangers', 'e': '🚶', 'l': 'Strangers'},
    {'v': 'partner', 'e': '💑', 'l': 'Partner'},
  ];
  static const _defaultPlaces = [
    {'v': 'home', 'e': '🏠', 'l': 'Home'},
    {'v': 'office', 'e': '🏢', 'l': 'Office'},
    {'v': 'school', 'e': '🏫', 'l': 'School'},
    {'v': 'outside', 'e': '🌳', 'l': 'Outside'},
  ];
  static const _defaultActs = [
    {'v': 'eating', 'e': '🍽️', 'l': 'Eating'},
    {'v': 'drinking', 'e': '💧', 'l': 'Drinking'},
    {'v': 'exercise', 'e': '💪', 'l': 'Exercise'},
    {'v': 'sleeping', 'e': '😴', 'l': 'Sleeping'},
    {'v': 'working', 'e': '💼', 'l': 'Working'},
    {'v': 'learning', 'e': '📚', 'l': 'Learning'},
    {'v': 'playing', 'e': '🎮', 'l': 'Playing'},
    {'v': 'walking', 'e': '🚶', 'l': 'Walking'},
  ];
  static const _defaultWeather = [
    {'v': 'sunny', 'e': '☀️', 'l': 'Sunny'},
    {'v': 'rainy', 'e': '🌧️', 'l': 'Rainy'},
    {'v': 'cloudy', 'e': '☁️', 'l': 'Cloudy'},
    {'v': 'snowy', 'e': '❄️', 'l': 'Snowy'},
    {'v': 'stormy', 'e': '⛈️', 'l': 'Stormy'},
  ];

  // ── Selected values ───────────────────────────────────────
  String _mood = '', _weather = '', _sleep = '', _notes = '';
  final List<String> _people = [], _places = [], _acts = [];

  @override
  void initState() {
    super.initState();
    _loadMaster();
  }

  // ── GET /user/active/daily/acivity ────────────────────────
  Future<void> _loadMaster() async {
    setState(() => _loadingMaster = true);
    final res = await _actService.getDailyActivityMaster();
    if (!mounted) return;

    // Parse API response — fall back to defaults if empty/null
    setState(() {
      if (res != null && res['data'] != null) {
        final d = res['data'] is Map ? res['data'] : res;
        _moodOpts = _parseOpts(_firstList(d, ['moods', 'mood', 'feelings'])) ??
            List.from(_defaultMoods);
        _peopleOpts =
            _parseOpts(_firstList(d, ['people', 'persons', 'met_people'])) ??
                List.from(_defaultPeople);
        _placeOpts =
            _parseOpts(_firstList(d, ['places', 'place', 'locations'])) ??
                List.from(_defaultPlaces);
        _actOpts = _parseOpts(_firstList(
                d, ['activities', 'activity', 'daily_activities'])) ??
            List.from(_defaultActs);
        _weatherOpts = _parseOpts(
                _firstList(d, ['weathers', 'weather', 'weather_types'])) ??
            List.from(_defaultWeather);
      } else {
        _moodOpts = List.from(_defaultMoods);
        _peopleOpts = List.from(_defaultPeople);
        _placeOpts = List.from(_defaultPlaces);
        _actOpts = List.from(_defaultActs);
        _weatherOpts = List.from(_defaultWeather);
      }
      _loadingMaster = false;
    });
  }

  // Convert API response list → [{v, e, l}] format
  List? _parseOpts(dynamic raw) {
    if (raw == null || raw is! List || raw.isEmpty) return null;
    return raw
        .map<Map<String, String>>((o) => {
              'v': o['value']?.toString() ??
                  o['slug']?.toString() ??
                  o['id']?.toString() ??
                  o['name']?.toString() ??
                  '',
              'e': o['emoji']?.toString() ??
                  o['icon']?.toString() ??
                  o['image']?.toString() ??
                  '•',
              'l': o['label']?.toString() ??
                  o['name']?.toString() ??
                  o['title']?.toString() ??
                  '',
            })
        .toList();
  }

  List? _firstList(dynamic source, List<String> keys) {
    if (source is! Map) return null;
    for (final key in keys) {
      final value = source[key];
      if (value is List) return value;
      if (value is Map) {
        for (final nested in ['data', 'items', 'list']) {
          if (value[nested] is List) return value[nested] as List;
        }
      }
    }
    return null;
  }

  // ── POST /user/daily/activity/store ──────────────────────
  Future<void> _submit() async {
    if (_mood.isEmpty || _weather.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please complete the required check-in questions',
              style: poppins(13)),
          backgroundColor: C.red,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    final res = await _actService.storeDailyActivity(
      mood: _mood,
      people: List.from(_people),
      places: List.from(_places),
      activities: List.from(_acts),
      weather: _weather,
      sleepTime: _sleep.isNotEmpty ? _sleep : null,
      notes: _notes.isNotEmpty ? _notes : null,
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _showSuccess = true;
    });
    // Log result but don't block success screen
    debugPrint('Check-in result: ${res['status']} — ${res['message']}');
  }

  // ── Icon grid builder ─────────────────────────────────────
  Widget _iconGrid(
      List opts, String? single, List<String>? multi, bool isMulti) {
    final rows = <Widget>[];
    for (int i = 0; i < opts.length; i += 4) {
      final slice = opts.sublist(i, (i + 4).clamp(0, opts.length));
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          ...slice.map<Widget>((o) {
            final v = o['v']?.toString() ?? '';
            final on = isMulti ? (multi!.contains(v)) : single == v;
            return Expanded(
                child: GestureDetector(
              onTap: () => setState(() {
                if (isMulti) {
                  on ? multi!.remove(v) : multi!.add(v);
                } else {
                  if (_moodOpts.any((m) => m['v'] == v))
                    _mood = v;
                  else
                    _weather = v;
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.only(right: 6),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                decoration: BoxDecoration(
                  color: on ? C.yellowLight : C.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: on ? C.yellow : C.bd, width: on ? 2 : 1.5),
                ),
                child: Column(children: [
                  Text(o['e']?.toString() ?? '•',
                      style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 4),
                  Text(o['l']?.toString() ?? '',
                      style: poppins(10,
                          w: FontWeight.w700, c: on ? C.yellowDeep : C.txm),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ]),
              ),
            ));
          }),
          // fill remaining cols
          ...List.generate((4 - slice.length).clamp(0, 4),
              (_) => const Expanded(child: SizedBox())),
        ]),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  final _qTitles = [
    'How are you feeling today?',
    'Who have you met today?',
    'Which places have you been?',
    'What activities did you do?',
    "What's the weather like?"
  ];
  final _qIcons = [
    Icons.mood_rounded,
    Icons.people_rounded,
    Icons.place_rounded,
    Icons.directions_run_rounded,
    Icons.cloud_rounded
  ];

  String _today() {
    final n = DateTime.now();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${days[n.weekday - 1]}, ${n.day} ${months[n.month - 1]} ${n.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Stack(children: [
        // ── Main check-in UI ───────────────────────────────
        Column(children: [
          // Yellow header
          Container(
            width: double.infinity,
            color: C.yellow,
            child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Row(children: [
                            const Icon(Icons.arrow_back_ios_new_rounded,
                                size: 16, color: C.ink),
                            const SizedBox(width: 6),
                            Text('How was your day?',
                                style:
                                    poppins(15, w: FontWeight.w700, c: C.ink))
                          ]),
                        ),
                        const SizedBox(height: 10),
                        Text('Daily check-in · ${_today()}',
                            style: poppins(12,
                                w: FontWeight.w600, c: C.yellowDeep)),
                        const SizedBox(height: 10),
                        // Progress bar — 5 segments
                        Row(
                            children: List.generate(
                                5,
                                (i) => Expanded(
                                        child: Container(
                                      margin:
                                          EdgeInsets.only(right: i < 4 ? 4 : 0),
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: i <= _q
                                            ? Colors.white.withOpacity(0.9)
                                            : Colors.white.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    )))),
                        const SizedBox(height: 6),
                        Align(
                            alignment: Alignment.centerRight,
                            child: Text('Question ${_q + 1} of 5',
                                style: poppins(11,
                                    w: FontWeight.w600, c: C.yellowDeep))),
                      ]),
                )),
          ),
          // White slide-up body
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                  color: C.white,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28))),
              child: _loadingMaster
                  ? const Center(
                      child: CircularProgressIndicator(color: C.yellowDark))
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(children: [
                        Expanded(
                            child: SingleChildScrollView(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                              // Question label
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(children: [
                                  Icon(_qIcons[_q],
                                      size: 16, color: C.yellowDark),
                                  const SizedBox(width: 6),
                                  Text(_qTitles[_q],
                                      style: poppins(13,
                                          w: FontWeight.w700, c: C.ink)),
                                ]),
                              ),
                              // Q0: Mood (single select)
                              if (_q == 0)
                                _iconGrid(_moodOpts, _mood, null, false),
                              // Q1: People (multi)
                              if (_q == 1)
                                _iconGrid(_peopleOpts, null, _people, true),
                              // Q2: Places (multi)
                              if (_q == 2)
                                _iconGrid(_placeOpts, null, _places, true),
                              // Q3: Activities (multi)
                              if (_q == 3)
                                _iconGrid(_actOpts, null, _acts, true),
                              // Q4: Weather + sleep + notes
                              if (_q == 4) ...[
                                _iconGrid(_weatherOpts, _weather, null, false),
                                const SizedBox(height: 10),
                                _inputRow(Icons.bedtime_outlined,
                                    'Sleep time (e.g. 10:30 PM)',
                                    onChanged: (v) => _sleep = v),
                                const SizedBox(height: 8),
                                _inputRow(
                                    Icons.notes_rounded, 'Notes about today...',
                                    onChanged: (v) => _notes = v, maxLines: 3),
                              ],
                            ]))),
                        // Nav buttons
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(children: [
                            if (_q > 0) ...[
                              Expanded(
                                  child: GestureDetector(
                                onTap: () => setState(() => _q--),
                                child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                        color: C.bg2,
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    child: Center(
                                        child: Text('← Back',
                                            style: poppins(13,
                                                w: FontWeight.w700,
                                                c: C.ink)))),
                              )),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                                child: GestureDetector(
                              onTap: _submitting
                                  ? null
                                  : () {
                                      if (_q < 4)
                                        setState(() => _q++);
                                      else
                                        _submit();
                                    },
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                    color: _q == 4 ? C.green : C.ink,
                                    borderRadius: BorderRadius.circular(14)),
                                child: Center(
                                    child: _submitting
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2))
                                        : Text(_q < 4 ? 'Next →' : 'Submit ✓',
                                            style: poppins(14,
                                                w: FontWeight.w700,
                                                c: Colors.white))),
                              ),
                            )),
                          ]),
                        ),
                      ]),
                    ),
            ),
          ),
        ]),

        // ── Success overlay ────────────────────────────────
        if (_showSuccess)
          Positioned.fill(
            child: Container(
              color: Colors.white,
              child: SafeArea(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🎉', style: TextStyle(fontSize: 72)),
                      const SizedBox(height: 8),
                      Text('Amazing!',
                          style: poppins(22, w: FontWeight.w700, c: C.ink)),
                      const SizedBox(height: 8),
                      Text('Your daily check-in is saved.\nKeep it up!',
                          style: poppins(13, c: C.txm, h: 1.6),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: [
                            if (_mood.isNotEmpty)
                              _pill(
                                  _moodOpts.firstWhere((m) => m['v'] == _mood,
                                          orElse: () =>
                                              {'e': '😊', 'l': _mood})['e']! +
                                      ' $_mood',
                                  C.yellowMid,
                                  C.yellowDeep),
                            if (_weather.isNotEmpty)
                              _pill(
                                  _weatherOpts.firstWhere(
                                          (w) => w['v'] == _weather,
                                          orElse: () => {
                                                'e': '☀️',
                                                'l': _weather
                                              })['e']! +
                                      ' $_weather',
                                  C.blueLight,
                                  const Color(0xFF0D47A1)),
                            if (_acts.isNotEmpty)
                              _pill('✓ ${_acts[0]}', C.greenLight,
                                  const Color(0xFF145C30)),
                          ]),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context, true),
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                                color: C.yellow,
                                borderRadius: BorderRadius.circular(14)),
                            child: Center(
                                child: Text('Back to home →',
                                    style: poppins(14,
                                        w: FontWeight.w700, c: C.ink))),
                          ),
                        ),
                      ),
                    ]),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _inputRow(IconData icon, String hint,
      {required Function(String) onChanged, int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
          color: C.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.bd, width: 1.5)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: EdgeInsets.only(left: 14, top: maxLines > 1 ? 13 : 0),
            child: Icon(icon, size: 18, color: C.txl)),
        Expanded(
            child: TextField(
          onChanged: onChanged,
          maxLines: maxLines,
          style: poppins(13, c: C.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: poppins(13, c: C.txl),
            border: InputBorder.none,
            filled: false,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          ),
        )),
      ]),
    );
  }

  Widget _pill(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: poppins(11, w: FontWeight.w700, c: fg)),
      );
}
