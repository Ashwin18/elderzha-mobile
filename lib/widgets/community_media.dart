import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';

class CommunityMedia extends StatelessWidget {
  final Map item;
  final double height;

  const CommunityMedia({
    super.key,
    required this.item,
    this.height = 190,
  });

  @override
  Widget build(BuildContext context) {
    final media = mediaUrl(item);
    final youtube = youtubeUrl(item);
    final plainUrl = linkUrl(item);
    final type = mediaType(item, media: media, youtube: youtube);

    if (youtube.isNotEmpty) {
      return _YoutubePreview(url: youtube, height: height);
    }
    if (media.isNotEmpty && type == 'video') {
      final thumb = item['banner_image']?.toString();
      return _VideoPreview(url: media, height: height, thumbnailUrl: thumb);
    }
    if (media.isNotEmpty && type == 'image') {
      return _ImagePreview(url: media, height: height);
    }
    if (plainUrl.isNotEmpty) {
      return _LinkPreview(url: plainUrl);
    }
    return const SizedBox.shrink();
  }

  static String bodyText(Map item) {
    return _clean(
      _first([
        item['text_content'],
        item['description'],
        item['content'],
        item['notes'],
        item['body'],
        item['message'],
        item['discription'],
      ]),
    );
  }

  static String mediaUrl(Map item) {
    return _absoluteUrl(
      _first([
        item['media_url'],
        item['media'],
        item['media_path'],
        item['image'],
        item['image_url'],
        item['image_path'],
        item['reply_image'],
        item['reply_image_url'],
        item['upload_image'],
        item['upload_file'],
        item['attachment'],
        item['attachment_url'],
        item['file_url'],
        item['file_path'],
        item['video'],
        item['video_url'],
        item['video_path'],
        item['reply_video'],
        item['reply_video_url'],
        item['file'],
      ]),
    );
  }

  static String youtubeUrl(Map item) {
    final explicit = _first([
      item['youtube_link'],
      item['youtube_url'],
      item['youtube'],
    ]);
    if (_isYoutube(explicit)) return explicit;
    final media = _first([item['media_url'], item['url'], item['link']]);
    return _isYoutube(media) ? media : '';
  }

  static String linkUrl(Map item) {
    final value = _first([item['url'], item['link'], item['web_url']]);
    if (value.startsWith('http')) return value;
    return '';
  }

  static String mediaType(Map item, {String? media, String? youtube}) {
    final type = _first([item['post_type'], item['media_type'], item['type']])
        .toLowerCase();
    if (youtube != null && youtube.isNotEmpty) return 'youtube';
    if (type.contains('youtube')) return 'youtube';
    if (type.contains('video')) return 'video';
    if (type.contains('image')) return 'image';
    final url = (media ?? mediaUrl(item)).toLowerCase();
    if (url.endsWith('.mp4') ||
        url.endsWith('.webm') ||
        url.endsWith('.mov') ||
        url.endsWith('.m3u8')) {
      return 'video';
    }
    if (url.endsWith('.jpg') ||
        url.endsWith('.jpeg') ||
        url.endsWith('.png') ||
        url.endsWith('.webp') ||
        url.endsWith('.gif')) {
      return 'image';
    }
    return url.isEmpty ? '' : 'image';
  }

  static String _first(List values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }

  static String _clean(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _absoluteUrl(String value) {
    if (value.isEmpty) return '';
    if (value.startsWith('http')) return value;
    final clean = value.replaceFirst(RegExp(r'^/+'), '');
    final base = ApiClient.baseUrl.replaceFirst('/api', '');
    if (clean.startsWith('public/')) return '$base/$clean';
    if (clean.startsWith('storage/')) return '$base/$clean';
    return '$base/public/$clean';
  }

  static bool _isYoutube(String value) {
    final lower = value.toLowerCase();
    return lower.contains('youtube.com') || lower.contains('youtu.be');
  }
}

class _ImagePreview extends StatelessWidget {
  final String url;
  final double height;

  const _ImagePreview({required this.url, required this.height});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(14),
          backgroundColor: Colors.black,
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        height: height,
        width: double.infinity,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _MediaError(url: url),
        ),
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  final String url;
  final double height;
  final String? thumbnailUrl;

  const _VideoPreview({required this.url, required this.height, this.thumbnailUrl});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final hasThumb = widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty;
    // A real admin-uploaded thumbnail when available; otherwise a
    // designed placeholder rather than trying to show a real video
    // frame — the very first frame of many videos is genuinely
    // black or not yet decoded, which is what caused the original
    // black-thumbnail issue. The controller/player only loads once
    // the user actually taps to watch.
    return GestureDetector(
      onTap: _loading ? null : () => _openFullScreen(context),
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        height: widget.height,
        width: double.infinity,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: C.ink,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            if (hasThumb)
              Image.network(
                widget.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: C.ink),
              ),
            if (hasThumb) Container(color: Colors.black.withOpacity(.18)),
            _loading
                ? const CircularProgressIndicator(color: C.yellow)
                : Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 11),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFullScreen(BuildContext context) async {
    setState(() => _loading = true);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenVideo(url: widget.url),
      ),
    );
    if (mounted) setState(() => _loading = false);
  }
}

class _FullScreenVideo extends StatefulWidget {
  const _FullScreenVideo({required this.url});
  final String url;

  @override
  State<_FullScreenVideo> createState() => _FullScreenVideoState();
}

class _FullScreenVideoState extends State<_FullScreenVideo> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: !_ready
            ? const CircularProgressIndicator(color: C.yellow)
            : GestureDetector(
                onTap: () => setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                }),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                    if (!_controller.value.isPlaying)
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.56),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 42),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _YoutubePreview extends StatefulWidget {
  final String url;
  final double height;

  const _YoutubePreview({required this.url, required this.height});

  @override
  State<_YoutubePreview> createState() => _YoutubePreviewState();
}

class _YoutubePreviewState extends State<_YoutubePreview> {
  YoutubePlayerController? _controller;
  bool _tapped = false;

  String? _youtubeId(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    if (uri.queryParameters['v']?.isNotEmpty == true) {
      return uri.queryParameters['v'];
    }
    final embed = uri.pathSegments.indexOf('embed');
    if (embed >= 0 && uri.pathSegments.length > embed + 1) {
      return uri.pathSegments[embed + 1];
    }
    return null;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _startPlayback(String id) {
    _controller = YoutubePlayerController(
      initialVideoId: id,
      flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
    );
    setState(() => _tapped = true);
  }

  @override
  Widget build(BuildContext context) {
    final id = _youtubeId(widget.url);

    if (id == null) {
      // Couldn't parse a video ID from this URL — fall back to
      // opening externally rather than showing a broken player.
      return GestureDetector(
        onTap: () =>
            launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
        child: Container(
          margin: const EdgeInsets.only(top: 10),
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(
            child: Icon(Icons.open_in_new_rounded, color: Colors.white, size: 32),
          ),
        ),
      );
    }

    // Stage 2 — tapped: load and play the real inline player.
    if (_tapped && _controller != null) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        height: widget.height,
        width: double.infinity,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
        ),
        child: YoutubePlayer(
          controller: _controller!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: C.yellow,
          progressColors: const ProgressBarColors(
            playedColor: C.yellow,
            handleColor: C.yellowDark,
          ),
        ),
      );
    }

    // Stage 1 (default) — a reliable static thumbnail with a play
    // button overlay. Never black: this image is hosted by
    // YouTube itself and loads immediately, unlike trying to show
    // a live player before it's ready.
    final thumb = 'https://img.youtube.com/vi/$id/hqdefault.jpg';
    return GestureDetector(
      onTap: () => _startPlayback(id),
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        height: widget.height,
        width: double.infinity,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              thumb,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.black),
            ),
            Container(color: Colors.black.withOpacity(.18)),
            Center(
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFFE62117),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkPreview extends StatelessWidget {
  final String url;

  const _LinkPreview({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: C.blueLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.link_rounded, color: Color(0xFF0D47A1)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(url, style: poppins(12, c: const Color(0xFF0D47A1))),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaError extends StatelessWidget {
  final String url;

  const _MediaError({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: C.bg2,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(14),
      child: Text(
        'Unable to load media',
        style: poppins(12, c: C.txl),
        textAlign: TextAlign.center,
      ),
    );
  }
}
