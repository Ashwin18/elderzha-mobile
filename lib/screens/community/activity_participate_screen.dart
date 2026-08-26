// lib/screens/community/activity_participate_screen.dart
//
// Full-screen destination opened by tapping "Participate now" on an
// activity banner card within the Activities tab. Distinctly named
// (not ActivityDetailScreen) because that existing screen serves a
// different purpose — opened from the Feed tab against a different
// data shape (reply_sent/reply_approved) than what the Activities
// calendar endpoint actually returns (reply_submitted/approval_status).
// Reusing it as-is risked silently showing the wrong reply status.
//
// Shows the banner, full content, a reply form (if not yet replied
// and the activity is unlocked), the user's own submitted reply (if
// already replied), and other users' approved responses.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:confetti/confetti.dart';
import '../../theme/app_theme.dart';
import '../../services/services.dart';
import '../../widgets/community_media.dart';

class ActivityParticipateScreen extends StatefulWidget {
  const ActivityParticipateScreen({super.key, required this.day, required this.svc});
  final Map<String, dynamic> day;
  final ActivityService svc;

  @override
  State<ActivityParticipateScreen> createState() => _ActivityParticipateScreenState();
}

class _ActivityParticipateScreenState extends State<ActivityParticipateScreen> {
  final _replyCtrl = TextEditingController();
  late ConfettiController _confettiController;
  File? _attachment;
  bool _submitting = false;
  bool _repliedLocally = false;
  List _otherResponses = [];
  bool _loadingResponses = true;

  Map get _activity => widget.day['activity'] as Map;
  bool get _canReply => widget.day['status'] == 'today' || widget.day['status'] == 'completed';

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _loadOtherResponses();
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadOtherResponses() async {
    try {
      final id = int.tryParse(_activity['id'].toString());
      if (id == null) return;
      final res = await widget.svc.getActivityPosts(id);
      if (!mounted) return;
      final list = res?['data'];
      setState(() {
        _otherResponses = list is List
            ? list
            : (list is Map ? (list['data'] as List? ?? []) : []);
        _loadingResponses = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingResponses = false);
    }
  }

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
    if (_replyCtrl.text.trim().isEmpty && _attachment == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Write a reply or add a photo', style: poppins(12, c: C.white)),
        backgroundColor: C.red,
      ));
      return;
    }
    setState(() => _submitting = true);
    final res = await widget.svc.submitReplyAndShare(
      postId: int.parse(_activity['id'].toString()),
      replyText: _replyCtrl.text.trim(),
      attachment: _attachment,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (res['status'] == true) {
      _confettiController.play();
      setState(() => _repliedLocally = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Reply submitted! Waiting for approval.', style: poppins(12, c: C.white)),
        backgroundColor: C.green,
      ));
      _loadOtherResponses();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message']?.toString() ?? 'Failed to submit', style: poppins(12, c: C.white)),
        backgroundColor: C.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = _activity;
    final title = activity['title']?.toString() ?? 'Activity';
    final postType = activity['post_type']?.toString() ?? 'text';
    final description = activity['text_content']?.toString();
    final bannerUrl = activity['banner_image']?.toString();
    final mediaUrl = activity['media_url']?.toString();
    final youtubeLink = activity['youtube_link']?.toString();
    final replySubmitted = _repliedLocally || activity['reply_submitted'] == true;
    final ownReplyNotes = activity['notes']?.toString() ?? activity['reply_notes']?.toString();

    final hasExtraMedia = postType != 'text' &&
        ((mediaUrl != null && mediaUrl.isNotEmpty) ||
            (postType == 'youtube' && youtubeLink != null && youtubeLink.isNotEmpty));

    final (badgeIcon, badgeLabel, badgeBg, badgeFg) = switch (postType) {
      'image' => (Icons.camera_alt_rounded, 'Image', C.blueLight, const Color(0xFF0C447C)),
      'video' => (Icons.videocam_rounded, 'Video', C.blueLight, const Color(0xFF0C447C)),
      'youtube' => (Icons.smart_display_rounded, 'YouTube', C.red.withOpacity(.12), C.red),
      _ => (Icons.edit_note_rounded, 'Text', C.bg2, C.txm),
    };

    return Scaffold(
      backgroundColor: C.bg,
      body: Stack(clipBehavior: Clip.none, children: [
        SafeArea(
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: C.white, shape: BoxShape.circle, border: Border.all(color: C.bd)),
                    child: const Icon(Icons.arrow_back_rounded, size: 18, color: C.ink),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Banner — always shown, uses banner_image (independent
              // of post type), same source and placeholder-fallback as
              // the list card. The activity's own content (photo/video/
              // YouTube) shows as a separate block further down.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: (bannerUrl != null && bannerUrl.isNotEmpty)
                      ? Image.network(
                          bannerUrl,
                          height: 190,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 190,
                            width: double.infinity,
                            color: C.yellowLight,
                            child: const Icon(Icons.image_rounded, size: 40, color: C.yellowDark),
                          ),
                        )
                      : Container(
                          height: 190,
                          width: double.infinity,
                          color: C.yellowLight,
                          child: const Icon(Icons.image_rounded, size: 40, color: C.yellowDark),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(999)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(badgeIcon, size: 12, color: badgeFg),
                        const SizedBox(width: 4),
                        Text(badgeLabel, style: poppins(11, w: FontWeight.w700, c: badgeFg)),
                      ]),
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
                  const SizedBox(height: 10),
                  Text(title, style: poppins(20, w: FontWeight.w800, c: C.ink, h: 1.25)),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(description, style: poppins(14, c: C.txm, h: 1.5)),
                  ],
                  // Actual content — photo/video/YouTube — shown as its
                  // own block below the description, for every type
                  // except Text (which has nothing further to show).
                  if (hasExtraMedia) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CommunityMedia(item: activity, height: 190),
                    ),
                  ],
                  const SizedBox(height: 20),

                  if (!_canReply) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: C.bg2, borderRadius: BorderRadius.circular(14)),
                      child: Text('This activity is from a past day.', style: poppins(12.5, c: C.txm)),
                    ),
                  ] else if (replySubmitted) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: C.greenLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: C.green.withOpacity(.3)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.check_circle_rounded, size: 16, color: C.green),
                          const SizedBox(width: 6),
                          Text('Your reply', style: poppins(12.5, w: FontWeight.w700, c: C.green)),
                        ]),
                        if (ownReplyNotes != null && ownReplyNotes.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(ownReplyNotes, style: poppins(13, c: C.ink, h: 1.4)),
                        ],
                      ]),
                    ),
                  ] else ...[
                    Text('Your reply', style: poppins(12.5, w: FontWeight.w700, c: C.txm)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _replyCtrl,
                      maxLines: 4,
                      style: poppins(13.5, c: C.ink),
                      decoration: InputDecoration(
                        hintText: 'Write your reply...',
                        hintStyle: poppins(13, c: C.txl),
                        filled: true,
                        fillColor: C.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: C.bd)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: C.bd)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(color: C.bg2, borderRadius: BorderRadius.circular(10)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_attachment == null ? Icons.add_photo_alternate_outlined : Icons.check_circle_rounded,
                              size: 16, color: _attachment == null ? C.txm : C.green),
                          const SizedBox(width: 6),
                          Text(_attachment == null ? 'Add photo' : 'Photo added',
                              style: poppins(12, w: FontWeight.w600, c: _attachment == null ? C.txm : C.green)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: C.ink,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _submitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: C.yellow, strokeWidth: 2))
                            : Text('Submit reply', style: poppins(13.5, w: FontWeight.w800, c: C.yellow)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Text('Other responses', style: poppins(12.5, w: FontWeight.w700, c: C.txm)),
                  const SizedBox(height: 10),
                  if (_loadingResponses)
                    const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: C.yellowDark, strokeWidth: 2)))
                  else if (_otherResponses.isEmpty)
                    Text('No responses yet — be the first!', style: poppins(12.5, c: C.txl))
                  else
                    ..._otherResponses.map((r) {
                      final rMap = r is Map ? r : {};
                      final name = rMap['user_name']?.toString() ?? 'A member';
                      final notes = rMap['notes']?.toString() ?? '';
                      final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(color: C.yellowLight, borderRadius: BorderRadius.circular(9)),
                            child: Center(child: Text(initial, style: poppins(12, w: FontWeight.w800, c: C.yellowDeep))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: TextSpan(children: [
                                TextSpan(text: '$name  ', style: poppins(12.5, w: FontWeight.w700, c: C.ink)),
                                TextSpan(text: notes, style: poppins(12.5, c: C.txm, h: 1.4)),
                              ]),
                            ),
                          ),
                        ]),
                      );
                    }),
                ]),
              ),
            ]),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 24,
            gravity: 0.3,
          ),
        ),
      ]),
    );
  }
}
