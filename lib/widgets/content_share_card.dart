import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';

/// A visual card used purely for image capture + sharing — rendered
/// off-screen, never shown directly to the user. Used for Feed posts,
/// Polls, and Activities alike, matching the same design/branding as
/// the Home day-summary share card.
class ContentShareCard extends StatelessWidget {
  const ContentShareCard({
    super.key,
    required this.typeLabel,
    required this.typeEmoji,
    required this.title,
    this.subtitle,
    this.extraLines = const [],
  });

  final String typeLabel; // "Feed" / "Poll" / "Activity"
  final String typeEmoji;
  final String title;
  final String? subtitle;
  final List<String> extraLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFDD66), C.yellow],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(typeEmoji, style: const TextStyle(fontSize: 19)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                typeLabel,
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, color: C.ink),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: C.ink, height: 1.3),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: GoogleFonts.poppins(fontSize: 12.5, color: C.txm, height: 1.5),
            ),
          ],
          for (final line in extraLines) ...[
            const SizedBox(height: 8),
            Text(line, style: GoogleFonts.poppins(fontSize: 12, color: C.txm)),
          ],
          const SizedBox(height: 18),
          Container(height: 1, color: C.bd),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Team ElderZha 💛',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w800, color: C.yellowDeep)),
              // TODO: replace with the real Play Store listing URL
              // once the app is published.
              Text('play.google.com/elderzha',
                  style: GoogleFonts.poppins(fontSize: 9.5, color: C.txl)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Captures the widget behind [key] as a PNG image and shares it via
/// the native share sheet, alongside [captionText]. The widget must
/// already be attached to the tree and rendered — typically via
/// [ShareCardHost] positioned far off-screen.
Future<bool> captureAndShareCard({
  required GlobalKey key,
  required String captionText,
  required String fileNamePrefix,
}) async {
  try {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject == null || renderObject is! RenderRepaintBoundary) {
      return false;
    }
    final image = await renderObject.toImage(pixelRatio: 2.5);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return false;

    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/${fileNamePrefix}_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());

    await Share.shareXFiles([XFile(file.path)], text: captionText);
    return true;
  } catch (_) {
    return false;
  }
}

/// Waits for two full rendered frames — more reliable than a fixed
/// delay across different device speeds, needed before capturing a
/// freshly-updated off-screen widget.
Future<void> waitForTwoFrames() async {
  Future<void> waitOne() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
    return completer.future;
  }

  await waitOne();
  await waitOne();
}

/// A fully self-contained share button — manages its own capture
/// state internally, so it can be dropped into any card (Stateless
/// or Stateful) without the parent needing its own GlobalKey or
/// share-card state. Renders a small "Share" pill; on tap, captures
/// an off-screen ContentShareCard built from the given content and
/// shares it as an image.
class ContentShareButton extends StatefulWidget {
  const ContentShareButton({
    super.key,
    required this.typeLabel,
    required this.typeEmoji,
    required this.title,
    this.subtitle,
    this.extraLines = const [],
  });

  final String typeLabel;
  final String typeEmoji;
  final String title;
  final String? subtitle;
  final List<String> extraLines;

  @override
  State<ContentShareButton> createState() => _ContentShareButtonState();
}

class _ContentShareButtonState extends State<ContentShareButton> {
  final _key = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    await waitForTwoFrames();
    if (!mounted) return;
    final ok = await captureAndShareCard(
      key: _key,
      captionText: '${widget.title}\n\nShared from ElderZha 💛',
      fileNamePrefix: 'elderzha_share',
    );
    if (mounted) {
      setState(() => _busy = false);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share this')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      GestureDetector(
        onTap: _share,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: C.bg2,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _busy
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5))
                : const Icon(Icons.share_rounded, size: 14, color: C.txm),
            const SizedBox(width: 5),
            Text('Share',
                style: GoogleFonts.poppins(
                    fontSize: 11, fontWeight: FontWeight.w700, color: C.txm)),
          ]),
        ),
      ),
      Positioned(
        left: -9999,
        top: -9999,
        child: RepaintBoundary(
          key: _key,
          child: Material(
            color: Colors.transparent,
            child: ContentShareCard(
              typeLabel: widget.typeLabel,
              typeEmoji: widget.typeEmoji,
              title: widget.title,
              subtitle: widget.subtitle,
              extraLines: widget.extraLines,
            ),
          ),
        ),
      ),
    ]);
  }
}
