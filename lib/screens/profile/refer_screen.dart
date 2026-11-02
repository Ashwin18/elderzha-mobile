// lib/screens/profile/refer_screen.dart
//
// Refer a Friend. Refer and track only (no rewards).
//  - Members who have paid see their code, a big Share button and the list
//    of friends they invited with a status (Invited / In Trial / Successful).
//  - Everyone else sees a gentle "unlocks after your first payment" note.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/referral_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/ez_dates.dart';

class ReferScreen extends StatefulWidget {
  const ReferScreen({super.key});

  @override
  State<ReferScreen> createState() => _ReferScreenState();
}

class _ReferScreenState extends State<ReferScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final d = await ReferralService.load();
    if (!mounted) return;
    setState(() {
      _data = d;
      _failed = d == null;
      _loading = false;
    });
  }

  String get _code => _data?['code']?.toString() ?? '';
  String get _link => _data?['link']?.toString() ?? '';
  String get _shareText => _data?['share_text']?.toString() ?? '';

  void _copy(String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$what copied')));
  }

  void _share() => Share.share(_shareText);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: C.ink,
        title: Text('Refer a Friend',
            style: poppins(18, w: FontWeight.w800, c: C.ink)),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: C.bgGradient),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: C.yellowDark))
            : _failed
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('Could not load. Check your internet.',
                          style: poppins(13, c: C.txm)),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ]),
                  )
                : RefreshIndicator(
                    color: C.yellowDark,
                    onRefresh: _load,
                    child: _data!['eligible'] == true ? _body() : _locked(),
                  ),
      ),
    );
  }

  // ── Not paid yet ──────────────────────────────────────────────────────
  Widget _locked() => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 40, 22, 30),
        children: [
          const Center(child: Text('🔒', style: TextStyle(fontSize: 56))),
          const SizedBox(height: 16),
          Text('Refer a Friend unlocks soon',
              textAlign: TextAlign.center,
              style: poppins(20, w: FontWeight.w800, c: C.ink)),
          const SizedBox(height: 10),
          Text(
            'Once your first payment is done, you can invite your friends and family to ElderZha from here.',
            textAlign: TextAlign.center,
            style: poppins(14.5, c: C.txm, h: 1.5),
          ),
        ],
      );

  // ── Paid member ───────────────────────────────────────────────────────
  Widget _body() {
    final stats = Map<String, dynamic>.from(_data!['stats'] as Map? ?? {});
    final recent = (_data!['recent'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: C.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: C.yellowBorder.withOpacity(.7)),
            boxShadow: const [
              BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6)),
            ],
          ),
          child: Column(children: [
            const Text('🤝', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 8),
            Text('Good friends make a better tomorrow',
                textAlign: TextAlign.center,
                style: poppins(19, w: FontWeight.w800, c: C.ink, h: 1.25)),
            const SizedBox(height: 8),
            Text(
              'Invite your friends and family to join ElderZha.',
              textAlign: TextAlign.center,
              style: poppins(14, c: C.txm, h: 1.45),
            ),
            const SizedBox(height: 16),
            // Code box
            GestureDetector(
              onTap: () => _copy(_code, 'Referral code'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: C.yellowLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: C.yellowBorder),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Your code  ', style: poppins(12.5, c: C.txm)),
                  Text(_code,
                      style: poppins(20, w: FontWeight.w900, c: C.ink)
                          .copyWith(letterSpacing: 2)),
                  const SizedBox(width: 10),
                  const Icon(Icons.copy_rounded, size: 18, color: C.txm),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _share,
                icon: const Icon(Icons.share_rounded, color: C.yellow),
                label: Text('Share Invite',
                    style: poppins(16, w: FontWeight.w800, c: C.yellow)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.ink,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _copy(_link, 'Invite link'),
              icon: const Icon(Icons.link_rounded, size: 18, color: C.txm),
              label: Text('Copy invite link',
                  style: poppins(13, w: FontWeight.w700, c: C.txm)),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        Row(children: [
          _stat('${stats['total'] ?? 0}', 'Invited', Icons.groups_rounded, C.yellowDeep),
          const SizedBox(width: 10),
          _stat('${stats['in_trial'] ?? 0}', 'In Trial', Icons.hourglass_bottom_rounded, const Color(0xFFF59E0B)),
          const SizedBox(width: 10),
          _stat('${stats['successful'] ?? 0}', 'Successful', Icons.check_circle_rounded, C.green),
        ]),
        const SizedBox(height: 22),
        Text('Recent Referrals', style: poppins(16, w: FontWeight.w800, c: C.ink)),
        const SizedBox(height: 10),
        if (recent.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: C.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.bd)),
            child: Text(
              'No one has joined with your code yet. Share your invite and they will appear here.',
              textAlign: TextAlign.center,
              style: poppins(13, c: C.txm, h: 1.45),
            ),
          )
        else
          ...recent.map(_row),
      ],
    );
  }

  Widget _stat(String n, String label, IconData icon, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
              color: C.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.bd)),
          child: Column(children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(n, style: poppins(22, w: FontWeight.w900, c: C.ink)),
            Text(label, style: poppins(11.5, w: FontWeight.w600, c: C.txm)),
          ]),
        ),
      );

  Widget _row(Map<String, dynamic> r) {
    final status = r['status']?.toString() ?? 'invited';
    final (label, bg, fg) = switch (status) {
      'successful' => ('Successful', const Color(0xFFDDF5E6), C.green),
      'in_trial' => ('In Trial', C.yellowLight, C.yellowDeep),
      _ => ('Invited', C.bg2, C.txm),
    };
    final joined = parseYmd(r['joined']);
    final img = r['image']?.toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: C.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.bd)),
      child: Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: C.yellowLight,
          backgroundImage: (img != null && img.isNotEmpty) ? NetworkImage(img) : null,
          child: (img == null || img.isEmpty)
              ? const Icon(Icons.person_rounded, color: C.yellowDeep)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r['name']?.toString() ?? 'New member',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: poppins(14.5, w: FontWeight.w700, c: C.ink)),
            if (joined != null)
              Text('Joined on ${fmtDay(joined)}', style: poppins(12, c: C.txl)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: poppins(12, w: FontWeight.w800, c: fg)),
        ),
      ]),
    );
  }
}
