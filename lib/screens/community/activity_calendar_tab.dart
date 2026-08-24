// lib/screens/community/activity_calendar_tab.dart
//
// The redesigned "Activities" sub-tab inside Spike — three clear
// sections:
//   - TODAY: large, prominent card, front and center, full reply flow
//   - COMING UP: future days shown BLURRED (image + title obscured),
//     locked icon + countdown, not tappable/submittable until unlock
//   - HISTORY: past days — user's own reply, plus other approved
//     users' replies on the same activity (social proof)
//
// Backed by GET /user/activity/calendar (see CommunityService).
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:confetti/confetti.dart';
import '../../theme/app_theme.dart';
import '../../services/services.dart';
import '../../widgets/community_media.dart';

class ActivityCalendarTab extends StatefulWidget {
  const ActivityCalendarTab({super.key});
  @override
  State<ActivityCalendarTab> createState() => _ActivityCalendarTabState();
}

class _ActivityCalendarTabState extends State<ActivityCalendarTab> {
  final _communitySvc = CommunityService();
  final _activitySvc = ActivityService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _days = [];
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // Refresh once a minute so countdowns stay accurate and a locked
    // day flips to unlocked live if the user leaves the screen open.
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
    final res = await _communitySvc.getActivityCalendar();
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
        _error = res?['message']?.toString() ?? 'Unable to load activities';
        _loading = false;
      });
    }
  }

  // Multiple activities can exist for today (admin created more than
  // one, whether intentionally or by testing) — show ALL of them, not
  // just the first match, so new ones never get silently hidden behind
  // an already-replied older one. Unreplied ones surface first.
  List<Map<String, dynamic>> get _todayActivities {
    final items = _days.where((d) => d['status'] == 'today').toList();
    items.sort((a, b) {
      final aReplied = (a['activity'] as Map?)?['reply_submitted'] == true;
      final bReplied = (b['activity'] as Map?)?['reply_submitted'] == true;
      if (aReplied == bReplied) return 0;
      return aReplied ? 1 : -1; // unreplied first
    });
    return items;
  }

  // Activities scheduled for TODAY's date but whose exact unlock time
  // hasn't arrived yet (e.g. set for 3pm, it's currently 1pm). These
  // don't belong in _todayActivities (not unlocked) or _upcoming
  // (that only covers tomorrow onward) — without this they'd be
  // invisible until their time passed.
  List<Map<String, dynamic>> get _laterToday {
    final items = _days
        .where((d) => d['status'] == 'locked' && d['unlocks_today'] == true)
        .toList();
    items.sort((a, b) => (a['unlock_at'] as String? ?? '')
        .compareTo(b['unlock_at'] as String? ?? ''));
    return items;
  }

  // Always shows the next 7 calendar days from today, regardless of
  // whether admin has actually created/assigned an activity for each
  // one yet — days without content show a "not planned yet" placeholder
  // instead of just not appearing at all. If admin assigned MORE than
  // one activity to a date, all of them are grouped together (not
  // silently dropped) and a count is attached for the UI badge.
  List<Map<String, dynamic>> get _upcoming {
    final byDate = <String, List<Map<String, dynamic>>>{};
    for (final d in _days.where((d) => d['status'] == 'locked')) {
      byDate.putIfAbsent(d['date'].toString(), () => []).add(d);
    }
    final now = DateTime.now();
    return List.generate(7, (i) {
      final date = DateTime(now.year, now.month, now.day + i + 1);
      final dateStr =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final dayGroup = byDate[dateStr];
      if (dayGroup == null || dayGroup.isEmpty) {
        return {
          'date': dateStr,
          'status': 'locked',
          'unlock_at': date.toIso8601String(),
          'unlock_in_seconds': date.difference(now).inSeconds,
          'not_planned': true,
        };
      }
      // Show the first activity as the preview, with a count attached
      // so the card can show "+N more" when admin assigned several.
      return {
        ...dayGroup.first,
        'activities_count': dayGroup.length,
      };
    });
  }

  List<Map<String, dynamic>> get _history =>
      _days.where((d) => d['status'] == 'completed' || d['status'] == 'missed')
          .toList()
        ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: C.yellowDark));
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
          if (_todayActivities.isNotEmpty)
            _TodayCarousel(
              activities: _todayActivities,
              onReplied: _load,
              svc: _activitySvc,
            )
          else
            _NoActivityTodayCard(),

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
            ..._laterToday.map((d) => _LockedDayCard(day: d)),
          ],

          const SizedBox(height: 26),
          Text('COMING UP', style: poppins(11, w: FontWeight.w700, c: C.txl)),
          const SizedBox(height: 10),
          ..._upcoming.map((d) => _LockedDayCard(day: d)),

          if (_history.isNotEmpty) ...[
            const SizedBox(height: 26),
            Text('HISTORY', style: poppins(11, w: FontWeight.w700, c: C.txl)),
            const SizedBox(height: 10),
            ..._history.map((d) => _HistoryRow(day: d)),
          ],
        ],
      ),
    );
  }
}

// ── Today's card — the centerpiece ──────────────────────────────────────
// ── Swipeable carousel for multiple today-activities ─────────────────────
// When admin assigns more than one activity to the same day, this shows
// them as a horizontal swipe carousel (like a stories UI) instead of a
// plain vertical stack — with dot indicators and a "1 of 2" badge so
// it's obvious there's more to see.
class _TodayCarousel extends StatefulWidget {
  const _TodayCarousel({required this.activities, required this.onReplied, required this.svc});
  final List<Map<String, dynamic>> activities;
  final VoidCallback onReplied;
  final ActivityService svc;

  @override
  State<_TodayCarousel> createState() => _TodayCarouselState();
}

class _TodayCarouselState extends State<_TodayCarousel> {
  late final PageController _pageController;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.94);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.activities.length;

    if (count == 1) {
      // Single activity — no need for carousel chrome at all.
      return _TodayCard(day: widget.activities[0], onReplied: widget.onReplied, svc: widget.svc);
    }

    return Column(children: [
      SizedBox(
        height: 420,
        child: PageView.builder(
          controller: _pageController,
          itemCount: count,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) => Padding(
            padding: EdgeInsets.only(right: i == count - 1 ? 0 : 10),
            child: SingleChildScrollView(
              child: _TodayCard(day: widget.activities[i], onReplied: widget.onReplied, svc: widget.svc),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: _page == i ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: _page == i ? C.yellowDark : C.bd,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        const SizedBox(width: 8),
        Text('${_page + 1} of $count', style: poppins(11, w: FontWeight.w600, c: C.txl)),
      ]),
    ]);
  }
}

class _TodayCard extends StatefulWidget {
  const _TodayCard({required this.day, required this.onReplied, required this.svc});
  final Map<String, dynamic> day;
  final VoidCallback onReplied;
  final ActivityService svc;

  @override
  State<_TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends State<_TodayCard> {
  final _replyCtrl = TextEditingController();
  late ConfettiController _confettiController;
  File? _attachment;
  bool _submitting = false;
  bool _showReplyBox = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  // The 'time' field comes straight from the DB via the backend
  // (already confirmed running in Asia/Kolkata / IST), formatted as
  // HH:MM:SS or HH:MM — this displays it as the admin actually set
  // it, no further timezone conversion needed or wanted here.
  String? _scheduledTimeLabel() {
    final raw = widget.day['time']?.toString();
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final hour24 = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour24 == null || minute == null) return null;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final ampm = hour24 >= 12 ? 'PM' : 'AM';
    return '$hour12:${minute.toString().padLeft(2, '0')} $ampm';
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _attachment = File(picked.path));
  }

  Future<void> _submit() async {
    final activity = widget.day['activity'] as Map;
    if (_replyCtrl.text.trim().isEmpty && _attachment == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Write a reply or add a photo', style: poppins(12, c: C.white)),
        backgroundColor: C.red,
      ));
      return;
    }
    setState(() => _submitting = true);
    final res = await widget.svc.submitReplyAndShare(
      postId: int.parse(activity['id'].toString()),
      replyText: _replyCtrl.text.trim(),
      attachment: _attachment,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (res['status'] == true) {
      _confettiController.play();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Reply submitted! Waiting for approval.', style: poppins(12, c: C.white)),
        backgroundColor: C.green,
      ));
      widget.onReplied();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message']?.toString() ?? 'Failed to submit', style: poppins(12, c: C.white)),
        backgroundColor: C.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.day['activity'] as Map;
    final title = activity['title']?.toString() ?? 'Today\'s activity';
    final postType = activity['post_type']?.toString() ?? 'text';
    final textContent = activity['text_content']?.toString();
    final mediaUrl = activity['media_url']?.toString();
    final youtubeLink = activity['youtube_link']?.toString();
    final youtubeThumbnail = activity['youtube_thumbnail']?.toString();
    final replySubmitted = activity['reply_submitted'] == true;
    final approvalStatus = activity['approval_status']?.toString();

    return Stack(clipBehavior: Clip.none, children: [
      Container(
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: C.bd),
        boxShadow: [BoxShadow(color: C.ink.withOpacity(.06), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Yellow accent strip — keeps the "today" energy without
        // saturating the whole card
        Container(height: 6, width: double.infinity, color: C.yellow),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(999)),
            child: Text('📅 TODAY', style: poppins(11, w: FontWeight.w800, c: C.yellow)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: C.yellowLight, borderRadius: BorderRadius.circular(999)),
            child: Text(
              postType == 'image' ? '📷 Photo'
                  : postType == 'video' ? '🎥 Video'
                  : postType == 'youtube' ? '🎬 YouTube'
                  : '✍️ Prompt',
              style: poppins(11, w: FontWeight.w700, c: C.yellowDeep),
            ),
          ),
          if (_scheduledTimeLabel() != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: C.bg2, borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.schedule_rounded, size: 11, color: C.txm),
                const SizedBox(width: 4),
                Text(_scheduledTimeLabel()!, style: poppins(11, w: FontWeight.w700, c: C.txm)),
              ]),
            ),
          ],
        ]),
        const SizedBox(height: 14),
        Text(title, style: poppins(21, w: FontWeight.w800, c: C.ink, h: 1.2)),

        if (postType == 'text') ...[
          const SizedBox(height: 14),
          // Text-only prompts get their own visual "shell" — a soft
          // yellow-tinted panel with a large quote icon — so they feel
          // just as complete and intentional as an image/video card,
          // instead of just... less content.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: C.yellowLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: C.yellowBorder),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.format_quote_rounded, color: C.yellowDark, size: 28),
              if (textContent != null && textContent.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(textContent, style: poppins(13.5, c: C.ink.withOpacity(.8), h: 1.5)),
              ],
            ]),
          ),
        ],

        if (mediaUrl != null || (postType == 'youtube' && youtubeLink != null && youtubeLink.isNotEmpty)) ...[
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CommunityMedia(item: activity, height: 200),
          ),
        ],

        const SizedBox(height: 18),

        if (replySubmitted) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: C.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [BoxShadow(color: C.ink.withOpacity(.06), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  approvalStatus == 'approved' ? Icons.check_circle_rounded
                      : approvalStatus == 'rejected' ? Icons.info_rounded
                      : Icons.hourglass_top_rounded,
                  color: approvalStatus == 'approved' ? C.green
                      : approvalStatus == 'rejected' ? C.red : C.yellowDark,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Text(
                  approvalStatus == 'approved' ? 'Live in community feed'
                      : approvalStatus == 'rejected' ? 'Needs a small change'
                      : 'Waiting for approval',
                  style: poppins(11.5, w: FontWeight.w700, c: C.ink),
                ),
              ]),
            ),
          ),
        ] else if (_showReplyBox) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Row(children: [
                Text('Your reply', style: poppins(12, w: FontWeight.w700, c: C.txm)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() {
                    _showReplyBox = false;
                    _replyCtrl.clear();
                    _attachment = null;
                  }),
                  child: Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(color: C.bg2, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.close_rounded, size: 15, color: C.txm),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              TextField(
                controller: _replyCtrl,
                maxLines: 3,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Write your reply...',
                  hintStyle: poppins(13, c: C.txl),
                  border: InputBorder.none,
                ),
                style: poppins(13, c: C.ink),
              ),
              if (_attachment != null) ...[
                const SizedBox(height: 8),
                Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(_attachment!, height: 100, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 6, right: 6,
                    child: GestureDetector(
                      onTap: () => setState(() => _attachment = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(.5), shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, size: 13, color: C.white),
                      ),
                    ),
                  ),
                ]),
              ],
              const SizedBox(height: 10),
              Row(children: [
                IconButton(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_photo_alternate_rounded, color: C.yellowDark),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _submitting ? null : () => setState(() {
                    _showReplyBox = false;
                    _replyCtrl.clear();
                    _attachment = null;
                  }),
                  child: Text('Cancel', style: poppins(13, w: FontWeight.w600, c: C.txl)),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(backgroundColor: C.ink),
                  child: _submitting
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(color: C.yellow, strokeWidth: 2))
                      : Text('Submit', style: poppins(13, w: FontWeight.w700, c: C.yellow)),
                ),
              ]),
            ]),
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => setState(() => _showReplyBox = true),
              style: FilledButton.styleFrom(
                backgroundColor: C.ink,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('✍️  Reply now', style: poppins(14, w: FontWeight.w700, c: C.yellow)),
            ),
          ),
        ],
      ]),
      ),
      ]),
      ),
      // Confetti burst — plays on successful reply submission
      Align(
        alignment: Alignment.topCenter,
        child: ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          numberOfParticles: 30,
          gravity: 0.3,
          colors: const [C.yellow, C.green, C.ink, Colors.pinkAccent, Colors.blueAccent],
        ),
      ),
    ]);
  }
}

class _VideoThumb extends StatelessWidget {
  const _VideoThumb({required this.url});
  final String url;
  @override
  Widget build(BuildContext context) => Container(
    height: 180, width: double.infinity, color: C.ink,
    child: const Center(child: Icon(Icons.play_circle_fill_rounded, size: 56, color: C.yellow)),
  );
}

// ── No activity assigned for today ──────────────────────────────────────
class _NoActivityTodayCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.bd)),
    child: Column(children: [
      const Text('🌤️', style: TextStyle(fontSize: 40)),
      const SizedBox(height: 10),
      Text('No activity for today', style: poppins(14, w: FontWeight.w700, c: C.ink)),
      const SizedBox(height: 4),
      Text('Check back tomorrow for something new', style: poppins(12, c: C.txl)),
    ]),
  );
}

// ── Locked future day — completely hidden content, just a countdown ─────
class _LockedDayCard extends StatelessWidget {
  const _LockedDayCard({required this.day});
  final Map<String, dynamic> day;

  String _countdown() {
    final unlockAtStr = day['unlock_at']?.toString();
    if (unlockAtStr == null) return '';
    final unlockAt = DateTime.tryParse(unlockAtStr);
    if (unlockAt == null) return '';
    final unlocksToday = day['unlocks_today'] == true;
    final diff = unlockAt.difference(DateTime.now());

    if (unlocksToday) {
      // Same calendar day, just waiting on the clock — show the exact
      // time rather than a vague countdown ("Opens at 3:00 PM").
      //
      // Reads the display hour/minute directly from the raw 'time'
      // field (e.g. "18:30:00") rather than unlockAt.hour — a parsed
      // DateTime's .hour reflects the DEVICE's local timezone, so if
      // a device's system clock is misconfigured (e.g. set to UTC
      // instead of IST, common on emulators), the displayed time
      // would silently shift by that offset even though the
      // underlying data is correct. Reading the raw string sidesteps
      // that entirely for what's shown to the user.
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
    final notPlanned = day['not_planned'] == true;
    final activity = day['activity'] as Map? ?? {};
    final title = activity['title']?.toString() ?? '';
    final postType = activity['post_type']?.toString();
    final mediaUrl = activity['media_url']?.toString();
    final youtubeThumb = activity['youtube_thumbnail']?.toString();
    final previewImage = mediaUrl ?? youtubeThumb;
    final activitiesCount = day['activities_count'] as int? ?? 1;

    if (notPlanned) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: C.bg2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: C.bd, style: BorderStyle.solid),
        ),
        child: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: C.ink.withOpacity(.05), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.event_outlined, color: C.txl, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_dateLabel(), style: poppins(12.5, w: FontWeight.w700, c: C.txm)),
              Text('Not planned yet', style: poppins(11, c: C.txl)),
            ]),
          ),
        ]),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 92,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.bd),
      ),
      child: Stack(fit: StackFit.expand, children: [
        // Blurred background — either the activity's own image/
        // thumbnail (blurred hard) or a neutral fallback if it's
        // a text-only activity.
        if (previewImage != null)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Image.network(previewImage, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: C.bg2)),
          )
        else
          Container(color: C.bg2),

        // Dark scrim so the lock icon/text stay readable regardless
        // of what's underneath.
        Container(color: Colors.black.withOpacity(.38)),

        // Blurred title text — gives a sense that content exists
        // without revealing what it actually is.
        if (title.isNotEmpty)
          Positioned(
            left: 16, right: 16, top: 14,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Text(title,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: poppins(15, w: FontWeight.w700, c: C.white)),
            ),
          ),

        // Multi-activity badge — lets users know more than one thing
        // is waiting for them that day, without revealing what.
        if (activitiesCount > 1)
          Positioned(
            top: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: C.yellow,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.layers_rounded, size: 11, color: C.ink),
                const SizedBox(width: 3),
                Text('+${activitiesCount - 1} more', style: poppins(10, w: FontWeight.w800, c: C.ink)),
              ]),
            ),
          ),

        // Lock + date + countdown — the only genuinely legible content.
        Positioned(
          left: 16, right: 16, bottom: 14,
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.18),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.lock_rounded, color: C.white, size: 15),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_dateLabel(), style: poppins(12.5, w: FontWeight.w700, c: C.white)),
                Text(_countdown(), style: poppins(11, c: Colors.white.withOpacity(.85))),
              ]),
            ),
            if (postType == 'video' || postType == 'youtube')
              Icon(
                postType == 'youtube' ? Icons.play_circle_outline_rounded : Icons.videocam_rounded,
                color: Colors.white.withOpacity(.7), size: 18,
              ),
          ]),
        ),
      ]),
    );
  }
}

// ── Past day — completed or missed ───────────────────────────────────────
class _HistoryRow extends StatefulWidget {
  const _HistoryRow({required this.day});
  final Map<String, dynamic> day;

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final activity = widget.day['activity'] as Map? ?? {};
    final completed = widget.day['status'] == 'completed';
    final title = activity['title']?.toString() ?? '';
    final approvalStatus = activity['approval_status']?.toString();
    final mediaUrl = activity['media_url']?.toString();
    final youtubeThumb = activity['youtube_thumbnail']?.toString();
    final thumb = mediaUrl ?? youtubeThumb;
    final date = DateTime.tryParse(widget.day['date']?.toString() ?? '');
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateLabel = date != null ? '${date.day} ${months[date.month - 1]}' : (widget.day['date']?.toString() ?? '');
    final otherReplies = (activity['other_replies'] as List? ?? []).cast<Map>();
    final otherCount = activity['other_replies_count'] ?? otherReplies.length;

    String statusLine;
    Color statusColor;
    if (!completed) {
      statusLine = 'Missed · $dateLabel';
      statusColor = C.txl;
    } else if (approvalStatus == 'approved') {
      statusLine = 'Approved · $dateLabel';
      statusColor = C.green;
    } else if (approvalStatus == 'rejected') {
      statusLine = 'Not approved · $dateLabel';
      statusColor = C.red;
    } else {
      statusLine = 'Pending review · $dateLabel';
      statusColor = C.yellowDeep;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.bd)),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: otherReplies.isEmpty ? null : () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              if (thumb != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(thumb, width: 44, height: 44, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          width: 44, height: 44, color: C.bg2,
                          child: Icon(completed ? Icons.check_circle_rounded : Icons.circle_outlined,
                              color: statusColor, size: 18))),
                ),
                const SizedBox(width: 10),
              ] else ...[
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: C.bg2, borderRadius: BorderRadius.circular(10)),
                  child: Icon(completed ? Icons.check_circle_rounded : Icons.circle_outlined,
                      color: statusColor, size: 18),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title.isNotEmpty ? title : 'Activity', style: poppins(12.5, w: FontWeight.w700, c: C.ink)),
                  Text(statusLine, style: poppins(11, c: statusColor, w: FontWeight.w600)),
                ]),
              ),
              if (otherCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: C.yellowLight, borderRadius: BorderRadius.circular(999)),
                  child: Text('+$otherCount others', style: poppins(10.5, w: FontWeight.w700, c: C.yellowDeep)),
                ),
                const SizedBox(width: 6),
                Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: C.txl, size: 20),
              ],
            ]),
          ),
        ),

        if (_expanded && otherReplies.isNotEmpty) ...[
          const Divider(height: 1),
          ...otherReplies.map((r) => Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: C.yellowLight,
                backgroundImage: r['user_image'] != null ? NetworkImage(r['user_image']) : null,
                child: r['user_image'] == null
                    ? Text((r['user_name']?.toString() ?? 'U').substring(0, 1).toUpperCase(),
                        style: poppins(11, w: FontWeight.w700, c: C.yellowDeep))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(r['user_name']?.toString() ?? 'A member',
                        style: poppins(11.5, w: FontWeight.w700, c: C.ink)),
                    const SizedBox(width: 6),
                    if (r['created_at'] != null)
                      Text(r['created_at'].toString(), style: poppins(10, c: C.txl)),
                  ]),
                  if ((r['notes']?.toString() ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(r['notes'].toString(), style: poppins(11.5, c: C.txm, h: 1.3)),
                    ),
                  if (r['image'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(r['image'], height: 80, width: 80, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                      ),
                    ),
                ]),
              ),
            ]),
          )),
        ],
      ]),
    );
  }
}
