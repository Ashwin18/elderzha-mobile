// ignore_for_file: use_build_context_synchronously
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../services/services.dart';
import '../../widgets/community_media.dart';

/// ViewActivities + showActivityDetailsSheet — ported from original
class ActivityDetailScreen extends StatefulWidget {
  final int? activityId;
  final bool autoOpenReply;
  const ActivityDetailScreen({
    super.key,
    this.activityId,
    this.autoOpenReply = false,
  });
  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  final _actSvc = ActivityService();
  final _commSvc = CommunityService();
  List _activities = [];
  bool _loading = true;
  bool _autoOpened = false;
  bool _detailSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // GET /user/activity/list
  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _actSvc.listUserActivities();
    if (!mounted) return;
    setState(() {
      _activities = _extractActivities(res);
      _loading = false;
    });

    if (widget.autoOpenReply && !_autoOpened && _activities.isNotEmpty) {
      _autoOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _detailSheetOpen) return;
        final item = widget.activityId != null
            ? _activities.firstWhere(
                (a) =>
                    (a['activity_id'] ?? a['id']).toString() ==
                    widget.activityId.toString(),
                orElse: () => _activities.first,
              )
            : _activities.first;
        _openDetails(item);
      });
    }
  }

  String _fmtDate(String? d) {
    try {
      final p = DateTime.parse(d ?? '');
      const m = [
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
        'Dec',
      ];
      return '${p.day.toString().padLeft(2, '0')} ${m[p.month - 1]} ${p.year}';
    } catch (_) {
      return d ?? '';
    }
  }

  String _fmtTime(String? t) {
    try {
      final p = DateTime.parse('2000-01-01 ${t ?? ''}');
      final h = p.hour % 12 == 0 ? 12 : p.hour % 12;
      return '$h:${p.minute.toString().padLeft(2, '0')} ${p.hour >= 12 ? 'PM' : 'AM'}';
    } catch (_) {
      return t ?? '';
    }
  }

  // GET /user/get/activity/details/{id} then open detail sheet
  Future<void> _openDetails(dynamic item) async {
    if (_detailSheetOpen) return;
    final id = item['activity_id'] ?? item['id'] ?? 0;
    final results = await Future.wait([
      _actSvc.getActivityReplies(id),
      _commSvc.getActivityPosts(int.tryParse(id.toString()) ?? 0),
    ]);
    if (!mounted) return;
    final detail = results[0]?['data'] ?? results[0] ?? {};
    final posts = results[1]?['data'] ?? results[1] ?? {};
    if (detail is Map) {
      _showDetailSheet(
        item,
        {
          ...Map<String, dynamic>.from(detail),
          'activity_posts': _extractApprovedPosts(posts),
        },
      );
    } else {
      _showDetailSheet(item, {
        'data': detail,
        'activity_posts': _extractApprovedPosts(posts),
      });
    }
  }

  List _extractActivities(Map<String, dynamic>? res) {
    final data = res?['data'];
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'] as List;
    return [];
  }

  List _extractApprovedPosts(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final nested = data['data'];
      if (nested is List) return nested;
      if (nested is Map && nested['data'] is List)
        return nested['data'] as List;
    }
    return [];
  }

  void _showDetailSheet(dynamic item, dynamic detail) {
    if (_detailSheetOpen) return;
    _detailSheetOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _DetailSheet(
        item: item,
        detail: detail,
        actSvc: _actSvc,
        commSvc: _commSvc,
        onRefresh: _load,
      ),
    ).whenComplete(() {
      _detailSheetOpen = false;
      if (widget.autoOpenReply && widget.activityId != null && mounted) {
        Navigator.pop(context, true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF0),
      appBar: AppBar(
        backgroundColor: C.yellow,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: C.ink,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Activities',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: C.ink,
          ),
        ),
      ),
      body: widget.autoOpenReply && widget.activityId != null
          ? Center(
              child: _loading
                  ? const CupertinoActivityIndicator(
                      radius: 14,
                      color: Colors.black,
                    )
                  : Text(
                      'Opening activity...',
                      style: GoogleFonts.poppins(color: C.txl),
                    ),
            )
          : _loading
              ? const Center(
                  child: CupertinoActivityIndicator(
                    radius: 14,
                    color: Colors.black,
                  ),
                )
              : _activities.isEmpty
                  ? Center(
                      child: Text(
                        'No activities found',
                        style: GoogleFonts.poppins(color: C.txl),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: C.yellowDark,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _activities.length,
                        itemBuilder: (_, i) {
                          final item = _activities[i];
                          final title = item['title'] ?? item['name'] ?? '';
                          final body = CommunityMedia.bodyText(
                              Map<String, dynamic>.from(item as Map));
                          final typeLabel = _postTypeLabel(item);
                          final date = _fmtDate(
                            item['date']?.toString() ??
                                item['created_at']?.toString(),
                          );
                          final time = _fmtTime(item['time']?.toString());
                          final statusLabel = _activityStatusLabel(item);
                          final approved = statusLabel == 'Admin approved';
                          return GestureDetector(
                            onTap: () => _openDetails(item),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 6,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                _typePill(typeLabel),
                                                Text(
                                                  '$date · $time',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    color: C.txl,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 7),
                                            Text(
                                              title,
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.black87,
                                                height: 1.35,
                                              ),
                                            ),
                                            if (body.isNotEmpty) ...[
                                              const SizedBox(height: 5),
                                              Text(
                                                body,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: C.txm,
                                                  height: 1.45,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 18,
                                        color: C.txl,
                                      ),
                                    ],
                                  ),
                                  CommunityMedia(
                                    item: Map<String, dynamic>.from(item),
                                    height: 150,
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      if (statusLabel != 'Reply')
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: approved
                                                ? C.greenLight
                                                : C.yellowMid,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            statusLabel,
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: approved
                                                  ? C.green
                                                  : C.yellowDeep,
                                            ),
                                          ),
                                        ),
                                      const Spacer(),
                                      Text(
                                        statusLabel == 'Reply'
                                            ? 'Reply'
                                            : 'View',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: C.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _typePill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: C.blueLight,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0D47A1),
          ),
        ),
      );

  String _postTypeLabel(Map item) {
    final type = (item['post_type'] ?? item['media_type'] ?? item['type'] ?? '')
        .toString()
        .toLowerCase();
    if (type.contains('youtube')) return 'YouTube';
    if (type.contains('video')) return 'Video';
    if (type.contains('image')) return 'Image';
    return 'Text';
  }

  String _activityStatusLabel(Map item) {
    final approval = (item['approval_status'] ?? '').toString().toLowerCase();
    final status = (item['status'] ?? '').toString().toLowerCase();
    final replySent = item['reply_sent'] == true ||
        item['reply_sent']?.toString() == '1' ||
        approval == 'submitted' ||
        approval == 'pending' ||
        status == 'pending_review';
    if (approval == 'approved' || item['reply_approved'] == true) {
      return 'Admin approved';
    }
    if (approval == 'rejected' || status == 'skipped') return 'Rejected';
    if (replySent) return 'Waiting for approval';
    return 'Reply';
  }
}

// ── Detail bottom sheet ────────────────────────────────────────────────────
class _DetailSheet extends StatefulWidget {
  final dynamic item, detail;
  final ActivityService actSvc;
  final CommunityService commSvc;
  final VoidCallback onRefresh;
  const _DetailSheet({
    required this.item,
    required this.detail,
    required this.actSvc,
    required this.commSvc,
    required this.onRefresh,
  });
  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  final _notesCtrl = TextEditingController();
  final _picker = ImagePicker();
  XFile? _attachment;
  String? _attachmentType;
  bool _submitting = false;
  bool _pendingApproval = false;

  @override
  void initState() {
    super.initState();
    _notesCtrl.text = widget.detail?['notes']?.toString() ?? '';
    _pendingApproval = _initialPendingApproval;
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _initialPendingApproval {
    final itemApproval =
        (widget.item['approval_status'] ?? '').toString().toLowerCase();
    final detailStatus =
        (widget.detail?['status'] ?? '').toString().toLowerCase();
    final itemStatus = (widget.item['status'] ?? '').toString().toLowerCase();
    final hasDetailReply = [
      widget.detail?['notes'],
      widget.detail?['reply'],
      widget.detail?['description'],
      widget.detail?['content'],
      widget.detail?['user_reply'],
      widget.detail?['my_reply'],
    ].any((v) => v != null && v.toString().trim().isNotEmpty);
    final sent = widget.item['reply_sent'] == true ||
        widget.item['reply_sent']?.toString() == '1' ||
        itemApproval == 'submitted' ||
        itemApproval == 'pending' ||
        itemStatus == 'pending_review' ||
        hasDetailReply;
    return sent &&
        itemApproval != 'approved' &&
        detailStatus != 'approved' &&
        itemStatus != 'approved';
  }

  bool get _approved {
    final itemApproval =
        (widget.item['approval_status'] ?? '').toString().toLowerCase();
    final itemStatus = (widget.item['status'] ?? '').toString().toLowerCase();
    final detailApproval =
        (widget.detail?['approval_status'] ?? '').toString().toLowerCase();
    final detailStatus =
        (widget.detail?['status'] ?? '').toString().toLowerCase();
    return itemApproval == 'approved' ||
        detailApproval == 'approved' ||
        detailStatus == 'approved' ||
        itemStatus == 'completed' ||
        widget.item['reply_approved'] == true;
  }

  // POST /user/activity/reply-share
  Future<void> _submit() async {
    if (_submitting || _pendingApproval || _approved) return;
    final id = widget.item['activity_id'] ?? widget.item['id'] ?? 0;
    setState(() => _submitting = true);
    final res = await widget.actSvc.submitReplyAndShare(
      postId: id,
      replyText: _notesCtrl.text.trim(),
      attachment: _attachment == null ? null : File(_attachment!.path),
    );
    final ok = res['status'] == true;
    setState(() {
      _submitting = false;
      _pendingApproval = ok;
    });
    if (mounted) {
      widget.onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Submitted and waiting for admin approval'
                : (res['message']?.toString() ?? 'Unable to submit reply'),
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: ok ? C.green : C.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final detail = widget.detail;
    final title = _cleanText(
      item['title'] ?? item['activity_title'] ?? item['description'] ?? '',
    );
    final activityPayload = _mergeActivityPayload(item, detail);
    final body = CommunityMedia.bodyText(activityPayload);
    final isDone = _approved;
    final replies = _extractReplies(detail);
    final typeLabel = _postTypeLabel(activityPayload);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: C.bg3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _typePill(typeLabel),
                          Text(
                            _dateTimeText(activityPayload),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: C.txl,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      CommunityMedia(item: activityPayload),
                      if (body.isNotEmpty) const SizedBox(height: 10),
                      if (body.isNotEmpty)
                        Text(
                          body,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: C.txm,
                            height: 1.55,
                          ),
                        ),
                      const SizedBox(height: 14),
                      if (_pendingApproval)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: C.yellowMid,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: C.yellowBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.pending_actions_rounded,
                                size: 18,
                                color: C.yellowDark,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your reply is waiting for admin approval. It will appear in Activities after approval.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: C.yellowDeep,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (isDone)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: C.greenLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: C.green.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                size: 18,
                                color: C.green,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Activity already replied and approved by admin.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: C.green,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (!_pendingApproval && !isDone) ...[
                        if (_attachment != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: C.bg2,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: _attachmentType == 'video'
                                ? Center(
                                    child: Text(
                                      '🎬 ${_attachment!.name}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: C.txm,
                                      ),
                                    ),
                                  )
                                : Image.file(
                                    File(_attachment!.path),
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final f = await _picker.pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 85,
                                  );
                                  if (f != null)
                                    setState(() {
                                      _attachment = f;
                                      _attachmentType = 'image';
                                    });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: C.bg2,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.image_outlined,
                                        size: 16,
                                        color: C.txl,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Photo',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: C.txl,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final f = await _picker.pickVideo(
                                    source: ImageSource.gallery,
                                  );
                                  if (f != null)
                                    setState(() {
                                      _attachment = f;
                                      _attachmentType = 'video';
                                    });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: C.bg2,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.videocam_outlined,
                                        size: 16,
                                        color: C.txl,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Video',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: C.txl,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _notesCtrl,
                          maxLines: 3,
                          style:
                              GoogleFonts.poppins(fontSize: 13, color: C.ink),
                          decoration: InputDecoration(
                            hintText: 'Add notes or reply...',
                            hintStyle: GoogleFonts.poppins(
                              fontSize: 13,
                              color: C.txl,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      // Replies list
                      if (replies.isNotEmpty) ...[
                        Text(
                          'Approved replies',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: C.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...replies.map(
                          (r) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: C.bg2,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _cleanText(r['reply'] ??
                                  r['content'] ??
                                  r['description'] ??
                                  r['notes'] ??
                                  ''),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: C.txm,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _submitting || _pendingApproval || isDone
                            ? null
                            : _submit,
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: (isDone || _pendingApproval)
                                ? C.green
                                : C.yellow,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: _submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _pendingApproval
                                        ? 'Waiting for approval'
                                        : isDone
                                            ? 'Admin approved'
                                            : 'Submit & Share',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDone || _pendingApproval
                                          ? Colors.white
                                          : C.ink,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _cleanText(dynamic value) => value
      .toString()
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .trim();

  Widget _typePill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: C.blueLight,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0D47A1),
          ),
        ),
      );

  String _postTypeLabel(Map item) {
    final type = (item['post_type'] ?? item['media_type'] ?? item['type'] ?? '')
        .toString()
        .toLowerCase();
    if (type.contains('youtube')) return 'YouTube';
    if (type.contains('video')) return 'Video';
    if (type.contains('image')) return 'Image';
    return 'Text';
  }

  String _dateTimeText(Map item) {
    final date = (item['date'] ?? item['activity_date'] ?? '').toString();
    final time = (item['time'] ?? item['activity_time'] ?? '').toString();
    return [date, time].where((v) => v.trim().isNotEmpty).join(' · ');
  }

  Map<String, dynamic> _mergeActivityPayload(dynamic item, dynamic detail) {
    final out = <String, dynamic>{};
    if (item is Map) out.addAll(Map<String, dynamic>.from(item));
    if (detail is Map) out.addAll(Map<String, dynamic>.from(detail));

    final itemText = item is Map ? CommunityMedia.bodyText(item) : '';
    final detailText = detail is Map ? CommunityMedia.bodyText(detail) : '';
    if ((out['text_content']?.toString().trim().isEmpty ?? true)) {
      out['text_content'] = detailText.isNotEmpty ? detailText : itemText;
    }

    final itemMedia = item is Map ? CommunityMedia.mediaUrl(item) : '';
    final detailMedia = detail is Map ? CommunityMedia.mediaUrl(detail) : '';
    if ((out['media_url']?.toString().trim().isEmpty ?? true)) {
      out['media_url'] = detailMedia.isNotEmpty ? detailMedia : itemMedia;
    }

    final itemYoutube = item is Map ? CommunityMedia.youtubeUrl(item) : '';
    final detailYoutube =
        detail is Map ? CommunityMedia.youtubeUrl(detail) : '';
    if ((out['youtube_link']?.toString().trim().isEmpty ?? true)) {
      out['youtube_link'] =
          detailYoutube.isNotEmpty ? detailYoutube : itemYoutube;
    }
    return out;
  }

  List _extractReplies(dynamic detail) {
    if (detail is List) return detail;
    if (detail is! Map) return [];
    for (final key in [
      'replies',
      'posts',
      'approved_replies',
      'activity_posts',
      'data'
    ]) {
      final value = detail[key];
      if (value is List) return value;
      if (value is Map) {
        for (final nested in [
          'replies',
          'posts',
          'approved_replies',
          'activity_posts',
          'data'
        ]) {
          final nestedValue = value[nested];
          if (nestedValue is List) return nestedValue;
        }
      }
    }
    return [];
  }
}
