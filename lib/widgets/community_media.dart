import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

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
      return _VideoPreview(url: media, height: height);
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
        item['upload_image'],
        item['video'],
        item['video_url'],
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

  const _VideoPreview({required this.url, required this.height});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _ready = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      height: widget.height,
      width: double.infinity,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
      ),
      child: !_ready
          ? const Center(child: CircularProgressIndicator(color: C.yellow))
          : Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _controller.value.isPlaying
                          ? _controller.pause()
                          : _controller.play();
                    });
                  },
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.55),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _YoutubePreview extends StatelessWidget {
  final String url;
  final double height;

  const _YoutubePreview({required this.url, required this.height});

  @override
  Widget build(BuildContext context) {
    final id = _youtubeId(url);
    final thumb =
        id == null ? '' : 'https://img.youtube.com/vi/$id/hqdefault.jpg';
    return GestureDetector(
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        height: height,
        width: double.infinity,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumb.isNotEmpty)
              Image.network(thumb, fit: BoxFit.cover)
            else
              Container(color: Colors.black),
            Container(color: Colors.black.withOpacity(.18)),
            Center(
              child: Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: Color(0xFFE62117),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 38),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
