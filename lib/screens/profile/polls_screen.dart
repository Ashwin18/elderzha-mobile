import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/services.dart';

class PollsScreen extends StatefulWidget {
  const PollsScreen({super.key});
  @override
  State<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen> {
  final _svc = CommunityService();
  List _polls = [];
  bool _loading = true;
  // Track which poll option was voted by pollId
  final Map<int, int> _voted = {};
  final Map<int, bool> _submitting = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    // ── GET /user/get/pools-list ───────────────────────────
    final res = await _svc.getPollsList();
    if (!mounted) return;
    setState(() {
      _polls = res?['data'] ?? [];
      _loading = false;
    });
  }

  Future<void> _vote(int pollId, int optionId, int pollIndex) async {
    if (_voted.containsKey(pollId)) return; // already voted
    setState(() { _submitting[pollId] = true; });

    // ── POST /user/poll/submit ─────────────────────────────
    final res = await _svc.submitPoll(pollId: pollId, optionId: optionId);
    if (!mounted) return;

    setState(() {
      _submitting[pollId] = false;
      if (res['status'] == true || res['data'] != null || res['message'] != null) {
        _voted[pollId] = optionId;
        // Update local vote count
        if (_polls[pollIndex]['options'] is List) {
          final opts = _polls[pollIndex]['options'] as List;
          for (int i = 0; i < opts.length; i++) {
            if ((opts[i]['id'] ?? i) == optionId) {
              opts[i]['votes_count'] = (opts[i]['votes_count'] ?? 0) + 1;
            }
          }
        }
      }
    });

    if (res['status'] != true && res['data'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Vote submitted', style: poppins(13)), backgroundColor: C.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(children: [
        Container(
          color: C.yellow,
          child: SafeArea(bottom: false, child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
            child: Row(children: [
              GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: C.ink)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Community Polls', style: poppins(18, w: FontWeight.w700, c: C.ink)),
                Text('Vote and see what others think', style: poppins(12, w: FontWeight.w500, c: C.yellowDeep)),
              ])),
              GestureDetector(onTap: _load, child: const Icon(Icons.refresh_rounded, color: C.ink)),
            ]),
          )),
        ),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(color: C.bg, borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28))),
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: C.yellowDark))
                : _polls.isEmpty
                    ? _fallbackPolls()
                    : RefreshIndicator(
                        onRefresh: _load, color: C.yellowDark,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _polls.length,
                          itemBuilder: (_, i) => _pollCard(_polls[i], i),
                        ),
                      ),
          ),
        ),
      ]),
    );
  }

  // Fallback with hardcoded polls matching reference design
  Widget _fallbackPolls() {
    final demos = [
      {
        'id': 1,
        'question': 'How many hours do you sleep each night?',
        'total_votes': 122,
        'expires_at': '7 Jun',
        'options': [
          {'id': 1, 'option': 'Less than 5h',  'votes_count': 12},
          {'id': 2, 'option': '5–6 hours',     'votes_count': 28},
          {'id': 3, 'option': '7–8 hours',     'votes_count': 64},
          {'id': 4, 'option': '9+ hours',      'votes_count': 18},
        ],
      },
      {
        'id': 2,
        'question': 'How often do you exercise each week?',
        'total_votes': 100,
        'expires_at': '30 Jun',
        'options': [
          {'id': 5, 'option': 'Never',         'votes_count': 8},
          {'id': 6, 'option': 'Once or twice', 'votes_count': 35},
          {'id': 7, 'option': '3–4 times',     'votes_count': 42},
          {'id': 8, 'option': 'Daily',         'votes_count': 15},
        ],
      },
      {
        'id': 3,
        'question': 'What time do you prefer wellness activities?',
        'total_votes': 158,
        'expires_at': '7 Jun',
        'options': [
          {'id': 9,  'option': 'Early morning (5–7 AM)', 'votes_count': 82},
          {'id': 10, 'option': 'Morning (7–10 AM)',       'votes_count': 46},
          {'id': 11, 'option': 'Evening (5–8 PM)',        'votes_count': 20},
          {'id': 12, 'option': 'Night (after 8 PM)',      'votes_count': 10},
        ],
      },
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: demos.length,
      itemBuilder: (_, i) => _pollCard(demos[i], i),
    );
  }

  Widget _pollCard(dynamic poll, int index) {
    final pollId    = poll['id']          as int? ?? index;
    final question  = poll['question']    ?? poll['title'] ?? '';
    final options   = (poll['options']    as List?) ?? [];
    final total     = poll['total_votes'] as int? ??
        options.fold<int>(0, (s, o) => s + ((o['votes_count'] ?? o['votes'] ?? 0) as int));
    final expires   = poll['expires_at']  ?? '';
    final hasVoted  = _voted.containsKey(pollId);
    final isSubmitting = _submitting[pollId] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.bd),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: C.blueLight, borderRadius: BorderRadius.circular(999)),
            child: Text('Poll', style: poppins(10, w: FontWeight.w700, c: const Color(0xFF0D47A1))),
          ),
          const SizedBox(width: 8),
          if (expires.isNotEmpty) Text('Expires $expires', style: poppins(11, c: C.txl)),
          const Spacer(),
          Text('$total responses', style: poppins(11, c: C.txl)),
        ]),
        const SizedBox(height: 10),
        Text(question, style: poppins(14, w: FontWeight.w700, c: C.ink, h: 1.4)),
        const SizedBox(height: 12),

        // Options
        ...options.asMap().entries.map((e) {
          final opt       = e.value;
          final optId     = opt['id']          as int? ?? e.key;
          final label     = opt['option']      ?? opt['label'] ?? opt['text'] ?? '';
          final votes     = (opt['votes_count'] ?? opt['votes'] ?? 0) as int;
          final pct       = (total > 0 ? votes / total : 0.0);
          final isMyVote  = _voted[pollId] == optId;
          final showResult= hasVoted;

          return GestureDetector(
            onTap: (!hasVoted && !isSubmitting) ? () => _vote(pollId, optId, index) : null,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              height: 44,
              child: Stack(children: [
                // Background
                Container(
                  decoration: BoxDecoration(
                    color: showResult ? C.bg2 : C.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isMyVote ? C.yellow : C.bd, width: isMyVote ? 2 : 1.5),
                  ),
                ),
                // Progress fill
                if (showResult)
                  FractionallySizedBox(
                    widthFactor: pct.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isMyVote ? C.yellowMid : C.bg3,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                // Label row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    Expanded(child: Text(label, style: poppins(13, w: isMyVote ? FontWeight.w700 : FontWeight.w500, c: isMyVote ? C.yellowDeep : C.ink))),
                    if (showResult) Text('${(pct * 100).toInt()}%', style: poppins(12, w: FontWeight.w700, c: isMyVote ? C.yellowDeep : C.txm)),
                    if (isMyVote) ...[const SizedBox(width: 6), const Icon(Icons.check_rounded, size: 15, color: C.yellowDeep)],
                  ]),
                ),
              ]),
            ),
          );
        }),

        // Submit loading
        if (isSubmitting)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: C.yellowDark))),
          ),

        if (!hasVoted && !isSubmitting)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Tap an option to vote', style: poppins(11, c: C.txl)),
          ),
      ]),
    );
  }
}
