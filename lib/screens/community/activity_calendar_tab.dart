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
import '../../theme/app_theme.dart';
import '../../services/services.dart';

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

  Map<String, dynamic>? get _today =>
      _days.cast<Map<String, dynamic>?>().firstWhere(
          (d) => d?['status'] == 'today', orElse: () => null);

  List<Map<String, dynamic>> get _upcoming =>
      _days.where((d) => d['status'] == 'locked').toList()
        ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

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
          if (_today != null) _TodayCard(
            day: _today!,
            onReplied: _load,
            svc: _activitySvc,
          ) else _NoActivityTodayCard(),

          if (_upcoming.isNotEmpty) ...[
            const SizedBox(height: 26),
            Text('COMING UP', style: poppins(11, w: FontWeight.w700, c: C.txl)),
            const SizedBox(height: 10),
            ..._upcoming.map((d) => _LockedDayCard(day: d)),
          ],

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
  File? _attachment;
  bool _submitting = false;
  bool _showReplyBox = false;

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
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

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [C.yellow, C.yellowDark],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: C.yellow.withOpacity(.35), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(999)),
            child: Text('📅 TODAY', style: poppins(11, w: FontWeight.w800, c: C.yellow)),
          ),
        ]),
        const SizedBox(height: 14),
        Text(title, style: poppins(21, w: FontWeight.w800, c: C.ink, h: 1.2)),

        if (postType == 'text' && textContent != null && textContent.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(textContent, style: poppins(13, c: C.ink.withOpacity(.75), h: 1.4)),
        ],

        if (mediaUrl != null) ...[
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: postType == 'video'
                ? _VideoThumb(url: mediaUrl)
                : Image.network(
                    mediaUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 180,
                        color: C.white.withOpacity(.5),
                        child: const Center(
                            child: CircularProgressIndicator(
                                color: C.yellowDark, strokeWidth: 2)),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 180,
                      color: C.white.withOpacity(.5),
                      child: Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.broken_image_outlined, color: C.txl, size: 32),
                          if (kDebugMode) ...[
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(mediaUrl,
                                  style: poppins(9, c: C.red),
                                  textAlign: TextAlign.center,
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ]),
                      ),
                    ),
                  ),
          ),
        ],

        if (postType == 'youtube' && youtubeLink != null && youtubeLink.isNotEmpty) ...[
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(alignment: Alignment.center, children: [
              if (youtubeThumbnail != null)
                Image.network(
                  youtubeThumbnail,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 180, color: C.ink,
                  ),
                )
              else
                Container(height: 180, width: double.infinity, color: C.ink),
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: C.white, size: 32),
              ),
            ]),
          ),
        ],

        const SizedBox(height: 18),

        if (replySubmitted) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(
                approvalStatus == 'approved' ? Icons.check_circle_rounded
                    : approvalStatus == 'rejected' ? Icons.info_rounded
                    : Icons.hourglass_top_rounded,
                color: approvalStatus == 'approved' ? C.green
                    : approvalStatus == 'rejected' ? C.red : C.yellowDark,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(
                approvalStatus == 'approved' ? 'You replied! Now live in the community feed.'
                    : approvalStatus == 'rejected' ? 'Your reply needs a small change — check with admin.'
                    : 'You replied! Waiting for approval.',
                style: poppins(12.5, w: FontWeight.w700, c: C.ink),
              )),
            ]),
          ),
        ] else if (_showReplyBox) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              TextField(
                controller: _replyCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Write your reply...',
                  hintStyle: poppins(13, c: C.txl),
                  border: InputBorder.none,
                ),
                style: poppins(13, c: C.ink),
              ),
              if (_attachment != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(_attachment!, height: 100, fit: BoxFit.cover),
                ),
              ],
              const SizedBox(height: 10),
              Row(children: [
                IconButton(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_photo_alternate_rounded, color: C.yellowDark),
                ),
                const Spacer(),
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
    );
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
    final diff = unlockAt.difference(DateTime.now());
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
    final activity = day['activity'] as Map? ?? {};
    final title = activity['title']?.toString() ?? '';
    final postType = activity['post_type']?.toString();
    final mediaUrl = activity['media_url']?.toString();
    final youtubeThumb = activity['youtube_thumbnail']?.toString();
    final previewImage = mediaUrl ?? youtubeThumb;

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
    final date = DateTime.tryParse(widget.day['date']?.toString() ?? '');
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateLabel = date != null ? '${date.day} ${months[date.month - 1]}' : (widget.day['date']?.toString() ?? '');
    final otherReplies = (activity['other_replies'] as List? ?? []).cast<Map>();
    final otherCount = activity['other_replies_count'] ?? otherReplies.length;

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
              Text(completed ? '✅' : '⚪', style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title.isNotEmpty ? title : 'Activity', style: poppins(12.5, w: FontWeight.w700, c: C.ink)),
                  Text(completed ? 'Replied · $dateLabel' : 'Missed · $dateLabel',
                      style: poppins(11, c: completed ? C.green : C.txl)),
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
