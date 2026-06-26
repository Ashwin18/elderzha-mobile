import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/services.dart';
import '../../widgets/community_media.dart';

class PostDetailScreen extends StatefulWidget {
  final dynamic post;
  const PostDetailScreen({super.key, required this.post});
  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _actSvc = ActivityService();
  final _commSvc = CommunityService();
  final _replyCtrl = TextEditingController();
  List _replies = [];
  bool _loading = true;
  bool _sending = false;

  int get _postId => widget.post['id'] ?? 0;

  @override
  void initState() {
    super.initState();
    _loadReplies();
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  // ── GET /user/get/activity/details/{id} ──────────────────
  Future<void> _loadReplies() async {
    setState(() => _loading = true);
    final res = await _actSvc.getActivityReplies(_postId);
    if (!mounted) return;
    setState(() {
      _replies = res?['data']?['replies'] ?? res?['replies'] ?? [];
      _loading = false;
    });
  }

  // ── POST /user/activity/reply ─────────────────────────────
  Future<void> _sendReply() async {
    if (_replyCtrl.text.trim().isEmpty) return;
    setState(() => _sending = true);
    final res = await _commSvc.submitReply(
        postId: _postId, reply: _replyCtrl.text.trim());
    setState(() => _sending = false);
    if (!mounted) return;
    if (res['status'] == true || res['data'] != null) {
      _replyCtrl.clear();
      FocusScope.of(context).unfocus();
      _loadReplies();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['message'] ?? 'Failed to send reply',
              style: poppins(13)),
          backgroundColor: C.red));
    }
  }

  // ── GET /user/post/like/{id} OR /user/adminpost/like/{id} ──
  Future<void> _like() async {
    final isAdmin =
        widget.post['is_admin'] == true || widget.post['admin_post'] == true;
    if (isAdmin)
      await _actSvc.likeAdminPost(_postId);
    else
      await _actSvc.likePost(_postId);
    _loadReplies();
  }

  // ── GET /user/save/community/post/{id} ───────────────────
  Future<void> _save() async {
    await _commSvc.savePost(_postId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Post saved!', style: poppins(13)),
        backgroundColor: C.green,
        duration: const Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.post['name'] ?? widget.post['user_name'] ?? 'User';
    final init = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final text = CommunityMedia.bodyText(widget.post);
    final time = widget.post['time'] ?? widget.post['created_at'] ?? '';
    final likes = widget.post['likes'] ?? widget.post['like_count'] ?? 0;

    return Scaffold(
      backgroundColor: C.bg,
      body: Column(children: [
        // Header
        Container(
          color: C.yellow,
          child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                child: Row(children: [
                  GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: C.ink)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text('Post',
                          style: poppins(17, w: FontWeight.w700, c: C.ink))),
                  GestureDetector(
                      onTap: _save,
                      child: const Icon(Icons.bookmark_border_rounded,
                          color: C.ink)),
                ]),
              )),
        ),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
                color: C.bg,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28))),
            child: Column(children: [
              Expanded(
                  child: ListView(padding: const EdgeInsets.all(14), children: [
                // Original post
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: C.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: C.bd)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                  color: C.yellowMid,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Center(
                                  child: Text(init,
                                      style: poppins(16,
                                          w: FontWeight.w700,
                                          c: C.yellowDeep)))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(name,
                                    style: poppins(13,
                                        w: FontWeight.w700, c: C.ink)),
                                Text(time, style: poppins(11, c: C.txl)),
                              ])),
                        ]),
                        const SizedBox(height: 10),
                        if (text.isNotEmpty)
                          Text(text, style: poppins(13, c: C.txm, h: 1.55)),
                        CommunityMedia(item: widget.post),
                        const SizedBox(height: 12),
                        Row(children: [
                          GestureDetector(
                              onTap: _like,
                              child: Row(children: [
                                const Icon(Icons.favorite_border_rounded,
                                    size: 16, color: C.txl),
                                const SizedBox(width: 4),
                                Text('$likes', style: poppins(12, c: C.txl))
                              ])),
                          const SizedBox(width: 14),
                          Row(children: [
                            const Icon(Icons.chat_bubble_outline_rounded,
                                size: 16, color: C.txl),
                            const SizedBox(width: 4),
                            Text('${_replies.length}',
                                style: poppins(12, c: C.txl))
                          ]),
                        ]),
                      ]),
                ),
                const SizedBox(height: 14),

                // Replies
                if (_loading)
                  const Center(
                      child: CircularProgressIndicator(color: C.yellowDark))
                else if (_replies.isEmpty)
                  Center(
                      child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text('No replies yet. Be the first!',
                              style: poppins(13, c: C.txl))))
                else
                  ..._replies.map<Widget>((r) {
                    final rName = r['name'] ?? r['user_name'] ?? 'User';
                    final rText = r['reply'] ?? r['text'] ?? r['content'] ?? '';
                    final rTime = r['created_at'] ?? r['time'] ?? '';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: C.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: C.bd)),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                    color: C.bg2, shape: BoxShape.circle),
                                child: Center(
                                    child: Text(
                                        rName.isNotEmpty
                                            ? rName[0].toUpperCase()
                                            : 'U',
                                        style: poppins(13,
                                            w: FontWeight.w700, c: C.txm)))),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(rName,
                                      style: poppins(12,
                                          w: FontWeight.w700, c: C.ink)),
                                  const SizedBox(height: 2),
                                  Text(rText,
                                      style: poppins(12, c: C.txm, h: 1.4)),
                                  const SizedBox(height: 3),
                                  Text(rTime, style: poppins(10, c: C.txl)),
                                ])),
                          ]),
                    );
                  }),
              ])),

              // Reply input
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                color: C.white,
                child: SafeArea(
                  top: false,
                  child: Row(children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                            color: C.bg2,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: C.bd)),
                        child: TextField(
                          controller: _replyCtrl,
                          decoration: InputDecoration(
                              hintText: 'Write a reply...',
                              hintStyle: poppins(13, c: C.txl),
                              border: InputBorder.none,
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10)),
                          style: poppins(13, c: C.ink),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sending ? null : _sendReply,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                            color: C.ink, shape: BoxShape.circle),
                        child: _sending
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                    color: C.yellow, strokeWidth: 2))
                            : const Icon(Icons.send_rounded,
                                color: C.yellow, size: 18),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
