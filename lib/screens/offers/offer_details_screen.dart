import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/services.dart';
import '../../theme/app_theme.dart';

class OfferDetailsScreen extends StatefulWidget {
  final int offerId;
  const OfferDetailsScreen({super.key, required this.offerId});

  @override
  State<OfferDetailsScreen> createState() => _OfferDetailsScreenState();
}

class _OfferDetailsScreenState extends State<OfferDetailsScreen> {
  final _svc = OffersService();
  Map<String, dynamic>? _offer;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await _svc.getOfferDetails(widget.offerId);
    if (!mounted) return;
    final data = res?['data'];
    if (data is! Map) {
      setState(() {
        _error = 'Offer not found';
        _loading = false;
      });
      return;
    }
    setState(() {
      _offer = Map<String, dynamic>.from(data);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(children: [
        Container(
          width: double.infinity,
          color: C.yellow,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: C.ink),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Offer details',
                      style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: C.ink)),
                ),
              ]),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CupertinoActivityIndicator(
                    radius: 14,
                    color: Colors.black,
                  ),
                )
              : _error != null
                  ? _errorState()
                  : _offerContent(),
        ),
      ]),
    );
  }

  Widget _offerContent() {
    final o = _offer!;
    final title = _text(o, ['title', 'offer_title', 'name', 'coupon_code']);
    final subtitle = _text(o, ['subtitle', 'sub_title', 'short_description']);
    final code = _text(o, ['coupon_code', 'code']);
    final qty = _text(o, ['available_quantity', 'quantity', 'stock']);
    final start = _text(o, ['start_date', 'valid_from']);
    final end = _text(o, ['end_date', 'valid_till', 'expiry', 'expires']);
    final location = _text(o, ['store_location', 'location', 'address']);
    final link = _text(o, ['store_link', 'link', 'url', 'website']);
    final desc = _text(o, ['description', 'desc']);
    final content = _text(o, ['content', 'details']);
    final banner = _assetUrl(_text(o, [
      'banner_image',
      'banner_url',
      'image',
      'image_url',
    ]));
    final icon = _assetUrl(_text(o, ['icon_image', 'icon_url', 'icon']));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: C.yellowMid,
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.hardEdge,
            child: banner.isEmpty
                ? const Icon(Icons.local_offer_rounded,
                    size: 54, color: C.yellowDeep)
                : Image.network(
                    banner,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.local_offer_rounded,
                      size: 54,
                      color: C.yellowDeep,
                    ),
                  ),
          ),
          Positioned(
            left: 14,
            bottom: 14,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: C.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: C.yellowBorder),
              ),
              clipBehavior: Clip.hardEdge,
              child: icon.isEmpty
                  ? const Icon(Icons.card_giftcard_rounded, color: C.yellowDark)
                  : Image.network(icon, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                      return const Icon(Icons.card_giftcard_rounded,
                          color: C.yellowDark);
                    }),
            ),
          ),
        ]),
        const SizedBox(height: 18),
        Text(title.isEmpty ? 'Offer' : title,
            style: GoogleFonts.poppins(
                fontSize: 22, fontWeight: FontWeight.w800, color: C.ink)),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(subtitle,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: C.yellowDeep)),
        ],
        const SizedBox(height: 16),
        if (code.isNotEmpty)
          GestureDetector(
            onTap: () => _copyCode(code),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: C.yellowMid,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: C.yellowBorder),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Coupon code',
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: C.yellowDeep)),
                        const SizedBox(height: 4),
                        Text(code,
                            style: GoogleFonts.poppins(
                                fontSize: 24,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w800,
                                color: C.ink)),
                      ]),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: C.ink,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Copy',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
              ]),
            ),
          ),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (qty.isNotEmpty)
            _infoChip(Icons.inventory_2_outlined, '$qty available'),
          if (start.isNotEmpty) _infoChip(Icons.play_arrow_rounded, start),
          if (end.isNotEmpty) _infoChip(Icons.event_available_rounded, end),
          if (location.isNotEmpty)
            _infoChip(Icons.location_on_outlined, location),
        ]),
        if (desc.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(desc,
              style:
                  GoogleFonts.poppins(fontSize: 14, color: C.txm, height: 1.6)),
        ],
        if (content.isNotEmpty) ...[
          const SizedBox(height: 10),
          Html(data: content),
        ],
        if (link.isNotEmpty) ...[
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () => _openLink(link),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: C.ink,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text('Open store link',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: C.yellow)),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _infoChip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: C.bd),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: C.txl),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.poppins(fontSize: 11, color: C.txm)),
        ]),
      );

  Widget _errorState() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_error!, style: GoogleFonts.poppins(color: C.txl)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _load,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                  color: C.yellow, borderRadius: BorderRadius.circular(10)),
              child: Text('Retry',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700, color: C.ink)),
            ),
          ),
        ]),
      );

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code "$code" copied!', style: GoogleFonts.poppins()),
        backgroundColor: C.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _openLink(String link) async {
    final uri = Uri.tryParse(link.startsWith('http') ? link : 'https://$link');
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _text(Map<String, dynamic> o, List<String> keys) {
    for (final key in keys) {
      final value = o[key];
      if (value == null) continue;
      final text = value.toString().replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }

  String _assetUrl(String value) {
    final text = value.trim();
    if (text.isEmpty) return '';
    if (text.startsWith('http')) return text;
    final clean = text.startsWith('/') ? text.substring(1) : text;
    return 'https://elderzhacopy.elderzha.online/$clean';
  }
}
