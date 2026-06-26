import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/services.dart';
import '../../theme/app_theme.dart';
import 'offer_details_screen.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  final _svc = OffersService();
  List _offers = [];
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
    final res = await _svc.getOffersList();
    if (!mounted) return;
    setState(() {
      _offers = _extractOffers(res);
      _error = res == null ? 'Unable to load offers' : null;
      _loading = false;
    });
  }

  List _extractOffers(Map<String, dynamic>? res) {
    if (res == null) return [];
    return _firstOfferList(res)
        .map((item) => _normalizeOffer(item))
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  List _firstOfferList(dynamic value) {
    if (value is List) return value;
    if (value is! Map) return [];
    for (final key in [
      'data',
      'offers',
      'offer',
      'coupons',
      'list',
      'items',
      'records',
      'results',
    ]) {
      final list = _firstOfferList(value[key]);
      if (list.isNotEmpty) return list;
    }
    for (final child in value.values) {
      final list = _firstOfferList(child);
      if (list.isNotEmpty) return list;
    }
    return [];
  }

  Map<String, dynamic> _normalizeOffer(dynamic item) {
    if (item is! Map) return {};
    final map = Map<String, dynamic>.from(item);
    for (final key in ['offer', 'admin_offer', 'coupon']) {
      final nested = map[key];
      if (nested is Map) {
        return {
          ...Map<String, dynamic>.from(nested),
          ...map,
        };
      }
    }
    return map;
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
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Offers',
                        style: poppins(24, w: FontWeight.w800, c: C.ink)),
                    Text('Coupons, stores and wellness deals',
                        style:
                            poppins(12, w: FontWeight.w600, c: C.yellowDeep)),
                  ]),
            ),
          ),
        ),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: C.bg,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: C.yellowDark))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: C.yellowDark,
                    child: _offers.isEmpty
                        ? _emptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(14),
                            itemCount: _offers.length,
                            itemBuilder: (_, i) {
                              final raw = _offers[i];
                              final offer = raw is Map
                                  ? Map<String, dynamic>.from(raw)
                                  : <String, dynamic>{};
                              return _offerCard(offer);
                            },
                          ),
                  ),
          ),
        ),
      ]),
    );
  }

  Widget _offerCard(Map<String, dynamic> o) {
    final id = _offerId(o);
    final title = _text(o, ['title', 'offer_title', 'name', 'coupon_code']);
    final subtitle = _text(o, ['subtitle', 'sub_title', 'short_description']);
    final desc = _text(o, ['description', 'content', 'desc']);
    final code = _text(o, ['coupon_code', 'code']);
    final qty = _text(o, ['available_quantity', 'quantity', 'stock']);
    final start = _text(o, ['start_date', 'valid_from']);
    final end = _text(o, ['end_date', 'valid_till', 'expiry', 'expires']);
    final location = _text(o, ['store_location', 'location', 'address']);
    final link = _text(o, ['store_link', 'link', 'url', 'website']);
    final banner = _assetUrl(_text(o, [
      'banner_image',
      'banner_url',
      'image',
      'image_url',
    ]));
    final icon = _assetUrl(_text(o, ['icon_image', 'icon_url', 'icon']));
    final lowStock = int.tryParse(qty) != null && int.parse(qty) <= 5;

    return GestureDetector(
      onTap: id == 0 ? null : () => _openOfferDetails(id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: C.bd),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0E000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            _imageBox(banner, height: 150, fallbackIcon: Icons.local_offer),
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: C.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: C.yellowBorder),
                ),
                clipBehavior: Clip.hardEdge,
                child: icon.isNotEmpty
                    ? Image.network(icon, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                        return const Icon(Icons.card_giftcard_rounded,
                            color: C.yellowDark);
                      })
                    : const Icon(Icons.card_giftcard_rounded,
                        color: C.yellowDark),
              ),
            ),
            if (lowStock)
              Positioned(
                right: 12,
                top: 12,
                child: _pill('Low stock', C.red.withOpacity(.12), C.red),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title.isEmpty ? 'Offer' : title,
                            style: poppins(16,
                                w: FontWeight.w800, c: C.ink, h: 1.25)),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(subtitle,
                              style: poppins(12, c: C.yellowDeep, h: 1.35)),
                        ],
                      ]),
                ),
                if (code.isNotEmpty)
                  GestureDetector(
                    onTap: () => _copy(code),
                    child: _pill(code, C.yellowMid, C.yellowDeep),
                  ),
              ]),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: poppins(12, c: C.txm, h: 1.45)),
              ],
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (qty.isNotEmpty)
                  _miniInfo(Icons.inventory_2_outlined, '$qty available'),
                if (start.isNotEmpty || end.isNotEmpty)
                  _miniInfo(Icons.event_available_rounded,
                      '${start.isNotEmpty ? start : 'Now'} - ${end.isNotEmpty ? end : 'Open'}'),
                if (location.isNotEmpty)
                  _miniInfo(Icons.location_on_outlined, location),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                if (link.isNotEmpty)
                  Expanded(
                    child: _actionButton(
                      'Open store',
                      Icons.open_in_new_rounded,
                      () => _openLink(link),
                      outlined: true,
                    ),
                  ),
                if (link.isNotEmpty) const SizedBox(width: 10),
                Expanded(
                  child: _actionButton(
                    'View offer',
                    Icons.arrow_forward_rounded,
                    id == 0 ? null : () => _openOfferDetails(id),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _imageBox(String url,
      {required double height, required IconData fallbackIcon}) {
    return Container(
      height: height,
      width: double.infinity,
      color: C.yellowMid,
      child: url.isEmpty
          ? Icon(fallbackIcon, size: 42, color: C.yellowDeep)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Icon(fallbackIcon, size: 42, color: C.yellowDeep),
            ),
    );
  }

  Widget _pill(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text,
            style: poppins(10, w: FontWeight.w800, c: fg),
            overflow: TextOverflow.ellipsis),
      );

  Widget _miniInfo(IconData icon, String text) => Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: C.bg2,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: C.txl),
          const SizedBox(width: 5),
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: poppins(10, w: FontWeight.w700, c: C.txm)),
          ),
        ]),
      );

  Widget _actionButton(String label, IconData icon, VoidCallback? onTap,
      {bool outlined = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: outlined ? C.white : C.ink,
          border: Border.all(color: outlined ? C.bd2 : C.ink),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label,
              style: poppins(12,
                  w: FontWeight.w800, c: outlined ? C.ink : Colors.white)),
          const SizedBox(width: 6),
          Icon(icon, size: 16, color: outlined ? C.ink : C.yellow),
        ]),
      ),
    );
  }

  int _offerId(Map<String, dynamic> o) =>
      int.tryParse(
          (o['offer_id'] ?? o['id'] ?? o['coupon_id'] ?? 0).toString()) ??
      0;

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

  void _copy(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$code copied', style: poppins(13)),
        backgroundColor: C.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _openLink(String link) async {
    final uri = Uri.tryParse(link.startsWith('http') ? link : 'https://$link');
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openOfferDetails(int offerId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OfferDetailsScreen(offerId: offerId)),
    );
  }

  Widget _emptyState() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 120),
        Icon(
          _error == null
              ? Icons.local_offer_outlined
              : Icons.cloud_off_outlined,
          size: 42,
          color: C.txl,
        ),
        const SizedBox(height: 12),
        Text(_error ?? 'No offers available yet',
            style: poppins(14, w: FontWeight.w700, c: C.ink),
            textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(
          _error == null
              ? 'Admin offers and coupons will appear here automatically.'
              : 'Pull down to retry once the connection is available.',
          style: poppins(12, c: C.txl, h: 1.45),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
