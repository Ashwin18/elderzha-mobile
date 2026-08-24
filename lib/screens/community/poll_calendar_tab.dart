// lib/screens/community/poll_calendar_tab.dart
//
// The redesigned "Polls" sub-tab inside Spike — same Today/Coming Up/
// History structure as Activities, adapted for voting:
//   - TODAY: poll is open, shows options + live results (once voted)
//   - COMING UP: future polls, blurred preview + countdown
//   - HISTORY: past polls — shows what you voted for (or that you
//     never voted), visually distinct states, as requested
//
// Backed by GET /user/poll/calendar (see CommunityService).
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/services.dart';

class PollCalendarTab extends StatefulWidget {
  const PollCalendarTab({super.key});
  @override
  State<PollCalendarTab> createState() => _PollCalendarTabState();
}

class _PollCalendarTabState extends State<PollCalendarTab> {
  final _svc = CommunityService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _days = [];
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _tickTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final res = await _svc.getPollCalendar(forceRefresh: true);
    if (!mounted) return;
    if (res != null && res['status'] == true) {
      final data = res['data'];
      setState(() {
        _days = data is List
            ? data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : [];
        _loading = false;
      });
    } else {
      setState(() {
        _error = res?['message']?.toString() ?? 'Unable to load polls';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _todayPolls =>
      _days.where((d) => d['status'] == 'today').toList();

  List<Map<String, dynamic>> get _laterToday => _days
      .where((d) => d['status'] == 'locked' && d['unlocks_today'] == true)
      .toList()
    ..sort((a, b) => (a['unlock_at'] as String? ?? '').compareTo(b['unlock_at'] as String? ?? ''));

  List<Map<String, dynamic>> get _upcoming {
    final byDate = <String, List<Map<String, dynamic>>>{};
    for (final d in _days.where((d) => d['status'] == 'locked' && d['unlocks_today'] != true)) {
      byDate.putIfAbsent(d['date'].toString(), () => []).add(d);
    }
    final now = DateTime.now();
    final result = <Map<String, dynamic>>[];
    for (int i = 0; i < 7; i++) {
      final date = DateTime(now.year, now.month, now.day + i + 1);
      final dateStr = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final group = byDate[dateStr];
      if (group != null && group.isNotEmpty) {
        result.add({...group.first, 'polls_count': group.length});
      }
    }
    return result;
  }

  List<Map<String, dynamic>> get _history =>
      _days.where((d) => d['status'] == 'past').toList()
        ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: C.yellowDark));
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, style: poppins(13, c: C.txl)),
          const SizedBox(height: 10),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }

    return RefreshIndicator(
      color: C.yellowDark,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (_todayPolls.isNotEmpty)
            for (int i = 0; i < _todayPolls.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              _TodayPollCard(day: _todayPolls[i], svc: _svc, onVoted: _load),
            ]
          else
            _NoPollTodayCard(),

          if (_laterToday.isNotEmpty) ...[
            const SizedBox(height: 26),
            Row(children: [
              Text('LATER TODAY', style: poppins(11, w: FontWeight.w700, c: C.txl)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: C.yellowLight, borderRadius: BorderRadius.circular(999)),
                child: Text('${_laterToday.length}', style: poppins(10, w: FontWeight.w800, c: C.yellowDeep)),
              ),
            ]),
            const SizedBox(height: 10),
            ..._laterToday.map((d) => _LockedPollCard(day: d)),
          ],

          const SizedBox(height: 26),
          Text('COMING UP', style: poppins(11, w: FontWeight.w700, c: C.txl)),
          const SizedBox(height: 10),
          ..._upcoming.map((d) => _LockedPollCard(day: d)),

          if (_history.isNotEmpty) ...[
            const SizedBox(height: 26),
            Text('HISTORY', style: poppins(11, w: FontWeight.w700, c: C.txl)),
            const SizedBox(height: 10),
            ..._history.map((d) => _PollHistoryRow(day: d)),
          ],
        ],
      ),
    );
  }
}

// ── Today's poll — vote or see results ───────────────────────────────────
class _TodayPollCard extends StatefulWidget {
  const _TodayPollCard({required this.day, required this.svc, required this.onVoted});
  final Map<String, dynamic> day;
  final CommunityService svc;
  final VoidCallback onVoted;

  @override
  State<_TodayPollCard> createState() => _TodayPollCardState();
}

class _TodayPollCardState extends State<_TodayPollCard> {
  bool _voting = false;

  Future<void> _vote(int optionId) async {
    setState(() => _voting = true);
    final poll = widget.day['poll'] as Map;
    final res = await widget.svc.submitPoll(
      pollId: int.parse(poll['id'].toString()),
      optionId: optionId,
    );
    if (!mounted) return;
    setState(() => _voting = false);
    if (res['status'] == true) {
      widget.onVoted();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message']?.toString() ?? 'Failed to vote', style: poppins(12, c: C.white)),
        backgroundColor: C.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.day['poll'] as Map;
    final question = poll['question']?.toString() ?? '';
    final options = (poll['options'] as List? ?? []).cast<Map>();
    final hasVoted = poll['has_voted'] == true;
    final myOptionId = poll['my_option_id'];
    final totalAnswered = poll['total_answered'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: C.bd),
        boxShadow: [BoxShadow(color: C.ink.withOpacity(.06), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 6, width: double.infinity, color: C.yellow),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(999)),
                child: Text('🗳️ TODAY\'S POLL', style: poppins(11, w: FontWeight.w800, c: C.yellow)),
              ),
            ]),
            const SizedBox(height: 14),
            Text(question, style: poppins(18, w: FontWeight.w800, c: C.ink, h: 1.3)),
            const SizedBox(height: 16),

            ...options.map((opt) {
              final optId = int.tryParse(opt['option_id'].toString());
              final isMine = hasVoted && myOptionId?.toString() == opt['option_id'].toString();
              final pct = opt['percentage'] ?? 0;

              if (!hasVoted) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: _voting ? null : () => _vote(optId!),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: C.bg2,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: C.bd),
                      ),
                      child: Text(opt['option_text']?.toString() ?? '',
                          style: poppins(14, w: FontWeight.w600, c: C.ink)),
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: (pct / 100).clamp(0, 1).toDouble()),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedFraction, child) {
                    final animatedPct = (animatedFraction * 100).round();
                    return Stack(children: [
                      Container(
                        width: double.infinity,
                        height: 46,
                        decoration: BoxDecoration(color: C.bg2, borderRadius: BorderRadius.circular(14)),
                      ),
                      FractionallySizedBox(
                        widthFactor: animatedFraction,
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: isMine ? C.yellow : C.yellowLight,
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(children: [
                            if (isMine) const Icon(Icons.check_circle_rounded, size: 16, color: C.ink),
                            if (isMine) const SizedBox(width: 6),
                            Expanded(
                              child: Text(opt['option_text']?.toString() ?? '',
                                  style: poppins(13.5, w: FontWeight.w700, c: C.ink)),
                            ),
                            Text('$animatedPct%', style: poppins(13, w: FontWeight.w800, c: C.ink)),
                          ]),
                        ),
                      ),
                    ]);
                  },
                ),
              );
            }),

            if (hasVoted) ...[
              const SizedBox(height: 6),
              Text('$totalAnswered vote${totalAnswered == 1 ? '' : 's'} so far',
                  style: poppins(11.5, c: C.txl)),
            ],

            if (_voting) ...[
              const SizedBox(height: 10),
              const Center(child: CircularProgressIndicator(color: C.yellowDark, strokeWidth: 2)),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _NoPollTodayCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.bd)),
    child: Column(children: [
      const Text('🗳️', style: TextStyle(fontSize: 40)),
      const SizedBox(height: 10),
      Text('No poll for today', style: poppins(14, w: FontWeight.w700, c: C.ink)),
      const SizedBox(height: 4),
      Text('Check back soon for something new', style: poppins(12, c: C.txl)),
    ]),
  );
}

// ── Locked future poll — blurred preview + countdown ─────────────────────
class _LockedPollCard extends StatelessWidget {
  const _LockedPollCard({required this.day});
  final Map<String, dynamic> day;

  String _countdown() {
    final unlockAtStr = day['unlock_at']?.toString();
    if (unlockAtStr == null) return '';
    final unlockAt = DateTime.tryParse(unlockAtStr);
    if (unlockAt == null) return '';
    final unlocksToday = day['unlocks_today'] == true;
    final diff = unlockAt.difference(DateTime.now());

    if (unlocksToday) {
      // See activity_calendar_tab.dart's _countdown() for why this
      // reads the raw 'time' string rather than unlockAt.hour.
      final rawTime = day['time']?.toString();
      String label;
      if (rawTime != null && rawTime.contains(':')) {
        final parts = rawTime.split(':');
        final hour24 = int.tryParse(parts[0]) ?? unlockAt.hour;
        final minute = int.tryParse(parts[1]) ?? unlockAt.minute;
        final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
        final ampm = hour24 >= 12 ? 'PM' : 'AM';
        label = '$hour12:${minute.toString().padLeft(2, '0')} $ampm';
      } else {
        final hour12 = unlockAt.hour % 12 == 0 ? 12 : unlockAt.hour % 12;
        final minute = unlockAt.minute.toString().padLeft(2, '0');
        final ampm = unlockAt.hour >= 12 ? 'PM' : 'AM';
        label = '$hour12:$minute $ampm';
      }
      if (diff.isNegative) return 'Opening now';
      return 'Opens at $label';
    }
    if (diff.isNegative) return 'Unlocking soon';
    if (diff.inDays >= 1) return 'Unlocks in ${diff.inDays} day${diff.inDays > 1 ? 's' : ''}';
    if (diff.inHours >= 1) return 'Unlocks in ${diff.inHours} hour${diff.inHours > 1 ? 's' : ''}';
    return 'Unlocks in ${diff.inMinutes} min';
  }

  String _dateLabel() {
    final date = DateTime.tryParse(day['date']?.toString() ?? '');
    if (date == null) return day['date']?.toString() ?? '';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${date.day} ${months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final pollsCount = day['polls_count'] as int? ?? 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 72,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.bd),
      ),
      child: Stack(fit: StackFit.expand, children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(color: C.yellowLight),
        ),
        Container(color: Colors.black.withOpacity(.30)),
        Positioned(
          left: 16, right: 16, top: 0, bottom: 0,
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: Colors.white.withOpacity(.18), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.lock_rounded, color: C.white, size: 15),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_dateLabel(), style: poppins(12.5, w: FontWeight.w700, c: C.white)),
                Text(_countdown(), style: poppins(11, c: Colors.white.withOpacity(.85))),
              ]),
            ),
            if (pollsCount > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: C.yellow, borderRadius: BorderRadius.circular(999)),
                child: Text('+${pollsCount - 1} more', style: poppins(10, w: FontWeight.w800, c: C.ink)),
              ),
          ]),
        ),
      ]),
    );
  }
}

// ── Past poll — voted vs never-voted, visually distinct ──────────────────
class _PollHistoryRow extends StatelessWidget {
  const _PollHistoryRow({required this.day});
  final Map<String, dynamic> day;

  @override
  Widget build(BuildContext context) {
    final poll = day['poll'] as Map? ?? {};
    final question = poll['question']?.toString() ?? '';
    final hasVoted = poll['has_voted'] == true;
    final options = (poll['options'] as List? ?? []).cast<Map>();
    final myOptionId = poll['my_option_id'];
    final date = DateTime.tryParse(day['date']?.toString() ?? '');
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateLabel = date != null ? '${date.day} ${months[date.month - 1]}' : (day['date']?.toString() ?? '');

    String? myOptionText;
    if (hasVoted && myOptionId != null) {
      final match = options.where((o) => o['option_id'].toString() == myOptionId.toString());
      if (match.isNotEmpty) myOptionText = match.first['option_text']?.toString();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        // Visually distinct: voted = light green tint, never voted = plain white
        color: hasVoted ? C.greenLight : C.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hasVoted ? C.green.withOpacity(.3) : C.bd),
      ),
      child: Row(children: [
        Icon(
          hasVoted ? Icons.check_circle_rounded : Icons.circle_outlined,
          color: hasVoted ? C.green : C.txl,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(question, style: poppins(12.5, w: FontWeight.w700, c: C.ink),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              hasVoted ? 'You voted: $myOptionText · $dateLabel' : 'You didn\'t vote · $dateLabel',
              style: poppins(11, c: hasVoted ? C.green : C.txl, w: FontWeight.w600),
            ),
          ]),
        ),
      ]),
    );
  }
}
