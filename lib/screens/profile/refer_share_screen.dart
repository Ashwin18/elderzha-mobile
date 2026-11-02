// lib/screens/profile/refer_share_screen.dart
//
// Share Invite Link: the member's invite link, a big WhatsApp button, quick
// WhatsApp / SMS / Copy / More options and a ready-made message to send.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';

class ReferShareScreen extends StatelessWidget {
  const ReferShareScreen({
    super.key,
    required this.link,
    required this.code,
    required this.message,
  });

  final String link;
  final String code;
  final String message;

  void _copy(BuildContext context, String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$what copied')));
  }

  Future<void> _whatsApp(BuildContext context) async {
    final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    await Share.share(message);
  }

  Future<void> _sms() async {
    final uri = Uri.parse('sms:?body=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    } catch (_) {}
    await Share.share(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: C.ink,
        title: Text('Share Invite Link',
            style: poppins(17, w: FontWeight.w800, c: C.ink)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 30),
        children: [
          // Link box
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3C4),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your Invite Link',
                  style: poppins(13, w: FontWeight.w800, c: C.ink)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                decoration: BoxDecoration(
                    color: C.white, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Expanded(
                    child: Text(link,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: poppins(11.5, c: C.txm)),
                  ),
                  IconButton(
                    onPressed: () => _copy(context, link, 'Invite link'),
                    icon: const Icon(Icons.copy_rounded, size: 20, color: C.ink),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Text('Your code  ', style: poppins(12.5, c: C.txm)),
                Text(code,
                    style: poppins(16, w: FontWeight.w900, c: C.ink)
                        .copyWith(letterSpacing: 2)),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          // WhatsApp
          SizedBox(
            height: 58,
            child: ElevatedButton.icon(
              onPressed: () => _whatsApp(context),
              icon: const Icon(Icons.chat_rounded, color: Colors.white),
              label: Text('Share on WhatsApp',
                  style: poppins(16, w: FontWeight.w800, c: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1FA855),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            _opt(Icons.chat_rounded, const Color(0xFF1FA855), 'WhatsApp', () => _whatsApp(context)),
            _opt(Icons.sms_rounded, const Color(0xFF2F80ED), 'SMS', _sms),
            _opt(Icons.link_rounded, C.ink, 'Copy Link', () => _copy(context, link, 'Invite link')),
            _opt(Icons.more_horiz_rounded, C.ink, 'More', () => Share.share(message)),
          ]),
          const SizedBox(height: 22),
          Text('Suggested Message',
              style: poppins(15, w: FontWeight.w800, c: C.ink)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            decoration: BoxDecoration(
              color: C.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: C.bd),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(message, style: poppins(12.5, c: C.txm, h: 1.5)),
              ),
              IconButton(
                onPressed: () => _copy(context, message, 'Message'),
                icon: const Icon(Icons.copy_rounded, size: 20, color: C.ink),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _opt(IconData icon, Color color, String label, VoidCallback onTap) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Column(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: C.white,
                shape: BoxShape.circle,
                border: Border.all(color: C.bd),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(label, style: poppins(11.5, w: FontWeight.w600, c: C.txm)),
          ]),
        ),
      );
}
