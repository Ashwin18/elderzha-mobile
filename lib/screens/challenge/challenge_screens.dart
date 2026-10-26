// lib/screens/challenge/challenge_screens.dart
//
// 100-Day Challenge.
//   ChallengeScreen        Day 1 baseline (compulsory, once) and the Day 100
//                          check-in: intro → 5 areas → 5 areas (→ comment).
//   ChallengeReportScreen  Day 1 vs Day 100 for each area, and the change.
import 'package:flutter/material.dart';

import '../../services/challenge_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/ez_dates.dart';

const _chipColors = <Color>[
  Color(0xFFF8C9CF), Color(0xFFF8C9CF), Color(0xFFF9D5B8), Color(0xFFFBE3A6),
  Color(0xFFFDEB9A), Color(0xFFEFEE9A), Color(0xFFD8EE9A), Color(0xFFBEE89E),
  Color(0xFFA6E3A6), Color(0xFF8EDC9D),
];

Widget _logoHeader(BuildContext context, {VoidCallback? onBack}) => Row(children: [
      SizedBox(
        width: 40,
        height: 40,
        child: onBack == null
            ? null
            : GestureDetector(
                onTap: onBack,
                child: Container(
                  decoration: const BoxDecoration(
                      color: C.white, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: C.ink),
                ),
              ),
      ),
      Expanded(
        child: Image.asset('assets/images/logo.png',
            height: 50,
            errorBuilder: (_, __, ___) => Text('ElderZha',
                textAlign: TextAlign.center,
                style: poppins(22, w: FontWeight.w800, c: C.ink))),
      ),
      const SizedBox(width: 40),
    ]);

BoxDecoration get _pageBg => const BoxDecoration(
      gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF3B8), Color(0xFFFFFBE6), Color(0xFFFFFDF4)]),
    );

Widget _bigButton(String text, VoidCallback? onTap, {bool busy = false}) =>
    GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onTap == null ? const Color(0xFFE8E2B8) : C.yellow,
          borderRadius: BorderRadius.circular(18),
          boxShadow: onTap == null
              ? null
              : [
                  BoxShadow(
                      color: C.yellowDark.withOpacity(.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: C.ink, strokeWidth: 2))
            : Text(text, style: poppins(16, w: FontWeight.w800, c: C.ink)),
      ),
    );

// ─────────────────────────────────────────────────────────────────────────
class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key, this.day100 = false, this.compulsory = false});

  /// false = Day 1 baseline, true = Day 100 check-in.
  final bool day100;

  /// Day 1 cannot be skipped: no back button out of the first screen.
  final bool compulsory;

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  int _stage = 0; // 0 intro, 1 areas 1-5, 2 areas 6-10, 3 comment (Day 100)
  final Map<String, int> _scores = {};
  final Map<String, int> _day1 = {};
  final _comment = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.day100) _loadDay1();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _loadDay1() async {
    final r = await ChallengeState.report();
    if (!mounted || r == null) return;
    final areas = r['areas'];
    if (areas is List) {
      setState(() {
        for (final a in areas) {
          if (a is Map && a['day1'] != null) {
            _day1[a['key'].toString()] = int.tryParse('${a['day1']}') ?? 0;
          }
        }
      });
    }
  }

  int get _lastStage => widget.day100 ? 3 : 2;

  bool get _canNext {
    if (_stage == 1) {
      return kChallengeAreas.take(5).every((a) => _scores.containsKey(a.key));
    }
    if (_stage == 2) {
      return kChallengeAreas.every((a) => _scores.containsKey(a.key));
    }
    return true;
  }

  void _back() {
    if (_stage > 0) {
      setState(() => _stage--);
    } else if (!widget.compulsory) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _next() async {
    if (_stage < _lastStage) {
      setState(() => _stage++);
      return;
    }
    await _submit();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final err = widget.day100
        ? await ChallengeState.submitDay100(_scores, _comment.text.trim())
        : await ChallengeState.submitBaseline(_scores);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err, style: poppins(13)), backgroundColor: C.red));
      return;
    }
    if (widget.day100) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => const ChallengeReportScreen()));
    } else {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(SnackBar(
          content: Text('Your 100-Day Challenge has started!',
              style: poppins(13)),
          backgroundColor: C.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = _stage == 0 && !widget.compulsory;
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: Container(
          decoration: _pageBg,
          child: SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: _logoHeader(context,
                    onBack: (_stage == 0 && widget.compulsory) ? null : _back),
              ),
              _steps(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _body(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: _bigButton(_buttonText(), _stage == 0 || _canNext ? _next : null,
                    busy: _saving),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  String _buttonText() {
    if (_stage == 0) return "Let's Begin  →";
    if (_stage < _lastStage) return 'Next  →';
    return widget.day100 ? 'View My 100-Day Journey  →' : 'Start My Challenge  →';
  }

  Widget _steps() {
    Widget dot(String label, bool active, bool done) => Column(children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: done ? C.yellow : (active ? C.yellow : C.white),
                shape: BoxShape.circle,
                border: Border.all(color: C.yellowDark, width: 1.5)),
            child: done
                ? const Icon(Icons.check_rounded, size: 18, color: C.ink)
                : Text(label == 'Your Life Today' ? '1' : '2',
                    style: poppins(13, w: FontWeight.w800, c: C.ink)),
          ),
          const SizedBox(height: 3),
          Text(label, style: poppins(11, w: FontWeight.w600, c: C.ink)),
        ]);
    final last = _stage == _lastStage;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60),
      child: Row(children: [
        dot('Your Life Today', !last, false),
        Expanded(child: Container(height: 2, color: C.yellowDark)),
        dot(widget.day100 ? 'Day 100' : 'Start Challenge', last, false),
      ]),
    );
  }

  Widget _body() {
    switch (_stage) {
      case 0:
        return _intro();
      case 1:
        return _questions('How do you feel today?', 0, 5);
      case 2:
        return _questions('More about your daily life', 5, 10);
      default:
        return _commentStage();
    }
  }

  Widget _intro() {
    final d = widget.day100;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      Text(d ? "Your Day 100\ncheck-in" : "Let's understand\nyour life today",
          style: poppins(28, w: FontWeight.w900, c: C.ink, h: 1.15)),
      const SizedBox(height: 8),
      Text(
          d
              ? 'You have come a long way! Rate each area again. Your Day 1 '
                  'rating is shown beside each one, so you can see the change.'
              : 'This will help us create a personalised 100-Day Better '
                  'Living Challenge for you.',
          style: poppins(14.5, c: C.txm, h: 1.45)),
      const SizedBox(height: 14),
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset('assets/images/elderzha_couple.png',
            height: 190,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(height: 10)),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: C.yellowMid, borderRadius: BorderRadius.circular(18)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.lightbulb_rounded, color: C.yellowDark, size: 30),
          const SizedBox(width: 10),
          Expanded(
              child: Text(
                  'There are no right or wrong answers. Just choose a number '
                  'from 1 to 10 based on how you feel today.',
                  style: poppins(13, w: FontWeight.w600, c: C.ink, h: 1.4))),
        ]),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: C.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: C.bd)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Rating Scale', style: poppins(15, w: FontWeight.w800, c: C.ink)),
          const SizedBox(height: 10),
          _chipsRow(null, (_) {}, readOnly: true),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Very Low', style: poppins(11.5, c: C.txm)),
            Text('Moderate', style: poppins(11.5, c: C.txm)),
            Text('Excellent', style: poppins(11.5, c: C.txm)),
          ]),
        ]),
      ),
    ]);
  }

  Widget _chipsRow(int? selected, ValueChanged<int> onPick,
      {bool readOnly = false}) {
    return Row(children: [
      for (var i = 1; i <= 10; i++)
        Expanded(
          child: GestureDetector(
            onTap: readOnly ? null : () => onPick(i),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _chipColors[i - 1],
                    shape: BoxShape.circle,
                    border: selected == i
                        ? Border.all(color: C.ink, width: 2.5)
                        : null,
                    boxShadow: selected == i
                        ? [
                            BoxShadow(
                                color: C.ink.withOpacity(.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2))
                          ]
                        : null,
                  ),
                  child: Text('$i',
                      style: poppins(selected == i ? 13.5 : 12,
                          w: selected == i ? FontWeight.w900 : FontWeight.w700,
                          c: C.ink)),
                ),
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _questions(String title, int from, int to) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 6),
      Text(title, style: poppins(24, w: FontWeight.w900, c: C.ink, h: 1.2)),
      Text('Please rate each area from 1 to 10.',
          style: poppins(13.5, c: C.txm)),
      const SizedBox(height: 12),
      for (var i = from; i < to; i++) _card(i + 1, kChallengeAreas[i]),
    ]);
  }

  Widget _card(int number, ChallengeArea a) {
    final d1 = _day1[a.key];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: _scores.containsKey(a.key) ? C.yellow : C.bd.withOpacity(.7),
              width: _scores.containsKey(a.key) ? 2 : 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: a.color.withOpacity(.14), shape: BoxShape.circle),
            child: Icon(a.icon, color: a.color, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$number. ${a.label}',
                  style: poppins(14.5, w: FontWeight.w800, c: C.ink)),
              Text(a.question,
                  style: poppins(12, c: C.txm, h: 1.3)),
            ]),
          ),
        ]),
        if (d1 != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
                color: const Color(0xFFFFE3E8),
                borderRadius: BorderRadius.circular(8)),
            child: Text('Your Day 1 rating: $d1',
                style: poppins(11.5, w: FontWeight.w700, c: C.ink)),
          ),
        ],
        const SizedBox(height: 10),
        _chipsRow(_scores[a.key], (v) => setState(() => _scores[a.key] = v)),
      ]),
    );
  }

  Widget _commentStage() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 6),
      Text('One last thing', style: poppins(24, w: FontWeight.w900, c: C.ink)),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: C.yellowMid, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('How has ElderZha made a difference in your daily life, if at all?',
              style: poppins(14, w: FontWeight.w700, c: C.ink, h: 1.35)),
          const SizedBox(height: 10),
          TextField(
            controller: _comment,
            maxLines: 5,
            maxLength: 2000,
            decoration: const InputDecoration(
                hintText: 'Share your thoughts…', filled: true, fillColor: C.white),
          ),
        ]),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────
class ChallengeReportScreen extends StatefulWidget {
  const ChallengeReportScreen({super.key});
  @override
  State<ChallengeReportScreen> createState() => _ChallengeReportScreenState();
}

class _ChallengeReportScreenState extends State<ChallengeReportScreen> {
  Map<String, dynamic>? _r;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ChallengeState.report();
    await ChallengeState.load();
    if (!mounted) return;
    setState(() {
      _r = r;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = (_r?['status'] is Map) ? _r!['status'] as Map : const {};
    final done = st['day100_done'] == true;
    final unlocked = st['day100_unlocked'] == true;
    final areas = (_r?['areas'] is List) ? _r!['areas'] as List : const [];
    final day = st['day_number'];
    final unlockDate = parseYmd(st['day100_date']);

    int sum = 0, n = 0;
    for (final a in areas) {
      if (a is Map && a['change'] != null) {
        sum += int.tryParse('${a['change']}') ?? 0;
        n++;
      }
    }

    return Scaffold(
      body: Container(
        decoration: _pageBg,
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: _logoHeader(context, onBack: () => Navigator.of(context).pop()),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: C.yellowDark))
                  : _r == null
                      ? Center(
                          child: Text('Could not load your report.\nPlease try again.',
                              textAlign: TextAlign.center,
                              style: poppins(14, c: C.txm)))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Your 100-Day\nProgress Report',
                                    style: poppins(28,
                                        w: FontWeight.w900, c: C.ink, h: 1.15)),
                                const SizedBox(height: 4),
                                Text(
                                    done
                                        ? 'See how far you have come!'
                                        : 'Day ${day ?? 1} of 100 — keep going!',
                                    style: poppins(14, c: C.txm)),
                                const SizedBox(height: 14),
                                _table(areas, done),
                                if (done && n > 0) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                        color: C.greenLight,
                                        borderRadius: BorderRadius.circular(16)),
                                    child: Text(
                                        sum >= 0
                                            ? 'On average you improved by '
                                                '${(sum / n).toStringAsFixed(1)} points per area. Well done!'
                                            : 'Every journey has ups and downs. Keep going — '
                                                'ElderZha is with you.',
                                        style: poppins(13.5,
                                            w: FontWeight.w700,
                                            c: const Color(0xFF14702C),
                                            h: 1.4)),
                                  ),
                                ],
                                if ((_r?['comment'] ?? '').toString().isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                        color: C.yellowMid,
                                        borderRadius: BorderRadius.circular(16)),
                                    child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Your thoughts',
                                              style: poppins(13,
                                                  w: FontWeight.w800, c: C.ink)),
                                          const SizedBox(height: 4),
                                          Text('${_r?['comment']}',
                                              style: poppins(13, c: C.ink, h: 1.4)),
                                        ]),
                                  ),
                                ],
                                if (!done) ...[
                                  const SizedBox(height: 14),
                                  if (unlocked)
                                    _bigButton('Take My Day 100 Check-in  →',
                                        () async {
                                      await Navigator.of(context).push(
                                          MaterialPageRoute(
                                              builder: (_) => const ChallengeScreen(
                                                  day100: true)));
                                      if (mounted) _load();
                                    })
                                  else
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                          color: C.white,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: C.bd)),
                                      child: Text(
                                          unlockDate == null
                                              ? 'Your Day 100 check-in will open soon.'
                                              : 'Your Day 100 check-in opens on ${fmtDayLong(unlockDate)}. '
                                                  'We will remind you.',
                                          style: poppins(13, c: C.txm, h: 1.4)),
                                    ),
                                ],
                              ]),
                        ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _table(List areas, bool done) {
    Widget head(String t, {int flex = 2, TextAlign a = TextAlign.center}) =>
        Expanded(
            flex: flex,
            child: Text(t,
                textAlign: a,
                style: poppins(12, w: FontWeight.w800, c: C.ink)));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: C.bd)),
      child: Column(children: [
        Row(children: [
          head('Area', flex: 6, a: TextAlign.left),
          head('Day 1'),
          head('Day 100'),
          head('Change'),
        ]),
        const Divider(height: 14),
        for (final a in areas)
          if (a is Map) _row(a),
      ]),
    );
  }

  Widget _row(Map a) {
    final meta = kChallengeAreas.firstWhere((m) => m.key == a['key'],
        orElse: () => kChallengeAreas.first);
    final d1 = a['day1'];
    final d100 = a['day100'];
    final ch = a['change'] == null ? null : int.tryParse('${a['change']}');
    Widget pill(dynamic v, Color bg) => Expanded(
          flex: 2,
          child: Center(
            child: Container(
              width: 36,
              height: 30,
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
              child: Text(v == null ? '—' : '$v',
                  style: poppins(14, w: FontWeight.w800, c: C.ink)),
            ),
          ),
        );
    Color chColor = C.txm;
    String chText = '—';
    if (ch != null) {
      if (ch > 0) {
        chColor = C.green;
        chText = '↑ +$ch';
      } else if (ch < 0) {
        chColor = C.red;
        chText = '↓ $ch';
      } else {
        chText = '＝ 0';
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(
          flex: 6,
          child: Row(children: [
            Icon(meta.icon, color: meta.color, size: 22),
            const SizedBox(width: 8),
            Expanded(
                child: Text('${a['label']}',
                    style: poppins(12, w: FontWeight.w600, c: C.ink, h: 1.2))),
          ]),
        ),
        pill(d1, const Color(0xFFFFE3E8)),
        pill(d100, const Color(0xFFD9F5DF)),
        Expanded(
          flex: 2,
          child: Text(chText,
              textAlign: TextAlign.center,
              style: poppins(13, w: FontWeight.w800, c: chColor)),
        ),
      ]),
    );
  }
}
