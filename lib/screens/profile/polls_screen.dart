// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/services.dart';
import '../../utils/join_date_helper.dart';

class PollsScreen extends StatefulWidget {
  const PollsScreen({super.key});
  @override
  State<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen> {
  final _svc = CommunityService();
  List _polls = [];
  bool _loading = true;
  DateTime? _joinDate;

  final Map<int, int> _voted     = {};
  final Map<int, bool> _submitting = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _joinDate = await JoinDateHelper.getJoinDate();
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _svc.getPollsList();
    if (!mounted) return;
    setState(() {
      _polls   = res?['data'] ?? [];
      _loading = false;
    });
  }

  /// Option B: gate on poll.created_at (when admin posted it),
  /// NOT on expiry_date. Expiry is a separate check.
  bool _canVoteOnPoll(dynamic poll) {
    // 1. Check expiry
    final expiry = poll['expiry_date']?.toString() ?? '';
    if (expiry.isNotEmpty) {
      try {
        if (DateTime.now().isAfter(DateTime.parse(expiry))) return false;
      } catch (_) {}
    }
    // 2. Check join date against created_at
    final createdAt = poll['created_at']?.toString() ?? '';
    return JoinDateHelper.canInteractSync(
      createdAt.isNotEmpty ? createdAt : null,
      _joinDate,
    );
  }

  bool _isPreJoinPoll(dynamic poll) {
    final createdAt = poll['created_at']?.toString() ?? '';
    if (createdAt.isEmpty || _joinDate == null) return false;
    return !JoinDateHelper.canInteractSync(createdAt, _joinDate);
  }

  bool _isPollExpired(dynamic poll) {
    final expiry = poll['expiry_date']?.toString() ?? '';
    if (expiry.isEmpty) return false;
    try {
      return DateTime.now().isAfter(DateTime.parse(expiry));
    } catch (_) {
      return false;
    }
  }

  Future<void> _vote(int pollId, int optionId, int pollIndex) async {
    if (_voted.containsKey(pollId)) return;
    setState(() { _submitting[pollId] = true; });

    final res = await _svc.submitPoll(pollId: pollId, optionId: optionId);
    if (!mounted) return;

    setState(() {
      _submitting[pollId] = false;
      if (res['status'] == true || res['data'] != null) {
        _voted[pollId] = optionId;
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
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: C.ink),
              ),
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
            decoration: const BoxDecoration(
              color: C.bg,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: _loading
                ? const Center(child: CupertinoActivityIndicator(radius: 14, color: Colors.black))
                : _polls.isEmpty
                    ? Center(child: Text('No polls available', style: poppins(14, c: C.txl)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: C.yellowDark,
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

  Widget _pollCard(dynamic poll, int index) {
    final pollId      = (poll['poll_id'] ?? poll['id'] ?? index) as int? ?? index;
    final question    = poll['question'] ?? poll['title'] ?? '';
    final options     = (poll['options'] as List?) ?? [];
    final total       = (poll['total_users'] != null
        ? int.tryParse(poll['total_users'].toString())
        : null) ?? options.fold<int>(0, (s, o) => s + ((o['votes_count'] ?? 0) as int));
    final expiryRaw   = poll['expiry_date']?.toString() ?? '';
    final expiryLabel = _fmtDate(expiryRaw);
    final hasVotedApi = (poll['status']?.toString() ?? '') == 'completed' ||
                        poll['user_selected']?.toString().isNotEmpty == true;
    final apiSelected = int.tryParse(poll['user_selected']?.toString() ?? '');
    final hasVoted    = _voted.containsKey(pollId) || hasVotedApi;
    final isSubmitting= _submitting[pollId] == true;
    final canVote     = _canVoteOnPoll(poll);
    final isPreJoin   = _isPreJoinPoll(poll);
    final isExpired   = _isPollExpired(poll);
    final showResults = hasVoted || isPreJoin || isExpired;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.bd),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──────────────────────────────────────────────────────
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isExpired ? C.bg2 : C.blueLight,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isExpired ? 'Ended' : 'Poll',
              style: poppins(10, w: FontWeight.w700,
                c: isExpired ? C.txl : const Color(0xFF0D47A1)),
            ),
          ),
          const SizedBox(width: 8),
          if (expiryLabel.isNotEmpty)
            Text(
              isExpired ? 'Ended $expiryLabel' : 'Expires $expiryLabel',
              style: poppins(11, c: C.txl),
            ),
          const Spacer(),
          Text('$total votes', style: poppins(11, c: C.txl)),
        ]),
        const SizedBox(height: 10),

        Text(question, style: poppins(14, w: FontWeight.w700, c: C.ink, h: 1.4)),
        const SizedBox(height: 12),

        // ── Pre-join info banner ─────────────────────────────────────────
        if (isPreJoin && !hasVoted)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: C.bg2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.bd),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: C.txl),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'This poll was created before you joined. You can view results only.',
                style: poppins(11, c: C.txl, h: 1.45),
              )),
            ]),
          ),

        // ── Options ──────────────────────────────────────────────────────
        ...options.asMap().entries.map((e) {
          final opt      = e.value;
          final optId    = (opt['option_id'] ?? opt['id'] ?? e.key) as int? ?? e.key;
          final label    = opt['option_text'] ?? opt['option'] ?? opt['label'] ?? '';
          final votes    = (opt['votes_count'] ?? opt['votes'] ?? 0) as int;
          final pct      = total > 0 ? votes / total : 0.0;
          final isMyVote = (_voted[pollId] == optId) || (apiSelected == optId);

          return GestureDetector(
            onTap: (!hasVoted && !isSubmitting && canVote && !isPreJoin)
                ? () => _vote(pollId, optId, index)
                : null,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              height: 44,
              child: Stack(children: [
                Container(
                  decoration: BoxDecoration(
                    color: showResults ? C.bg2 : C.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isMyVote ? C.yellow : C.bd,
                      width: isMyVote ? 2 : 1.5,
                    ),
                  ),
                ),
                if (showResults)
                  FractionallySizedBox(
                    widthFactor: pct.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isMyVote ? C.yellowMid : C.bg3,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    Expanded(child: Text(label,
                      style: poppins(13,
                        w: isMyVote ? FontWeight.w700 : FontWeight.w500,
                        c: isMyVote ? C.yellowDeep : C.ink),
                    )),
                    if (showResults)
                      Text('${(pct * 100).toInt()}%',
                        style: poppins(12, w: FontWeight.w700,
                          c: isMyVote ? C.yellowDeep : C.txm)),
                    if (isMyVote) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.check_rounded, size: 15, color: C.yellowDeep),
                    ],
                  ]),
                ),
              ]),
            ),
          );
        }),

        // ── Loading ───────────────────────────────────────────────────────
        if (isSubmitting)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Center(child: SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: C.yellowDark))),
          ),

        // ── Footer hint ───────────────────────────────────────────────────
        if (!hasVoted && !isSubmitting && canVote && !isPreJoin)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Tap an option to vote', style: poppins(11, c: C.txl)),
          ),
        if (!hasVoted && isPreJoin)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('View only — poll created before you joined',
                style: poppins(11, c: C.txl)),
          ),
        if (isExpired && !isPreJoin && !hasVoted)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('This poll has ended', style: poppins(11, c: C.txl)),
          ),
      ]),
    );
  }

  String _fmtDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final d = DateTime.parse(raw);
      const m = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${m[d.month - 1]} ${d.year}';
    } catch (_) {
      return raw;
    }
  }
}
