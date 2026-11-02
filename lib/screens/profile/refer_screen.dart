// lib/screens/profile/refer_screen.dart
//
// Refer & Earn: the hero page. Members who have paid see what they earn
// (Zha Seeds + a tree per successful referral), a Share Invite Link button
// and a shortcut to My Referrals. Everyone else sees a gentle
// "unlocks after your first payment" note.
import 'package:flutter/material.dart';

import '../../services/feature_flags.dart';
import '../../services/referral_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/seeds_earned_dialog.dart';
import 'my_referrals_screen.dart';
import 'refer_share_screen.dart';

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
    final unseen = int.tryParse('${d?['unseen_seeds'] ?? 0}') ?? 0;
    if (unseen > 0 && mounted) {
      FeatureFlags.unseenSeeds = 0;
      await showSeedsEarnedDialog(context, unseen, onViewReferrals: _openMy);
    }
  }

  int get _per => int.tryParse('${_data?['seeds_per_referral'] ?? 100}') ?? 100;

  void _openMy() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const MyReferralsScreen()));

  void _openShare() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ReferShareScreen(
                  link: _data!['link']?.toString() ?? '',
                  code: _data!['code']?.toString() ?? '',
                  message: _data!['share_text']?.toString() ?? '',
                )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.yellow,
        elevation: 0,
        foregroundColor: C.ink,
        title: Text('Refer & Earn',
            style: poppins(18, w: FontWeight.w800, c: C.ink)),
        centerTitle: true,
      ),
      body: _loading
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
    );
  }

  Widget _locked() => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 50, 22, 30),
        children: [
          const Center(child: Text('🔒', style: TextStyle(fontSize: 56))),
          const SizedBox(height: 16),
          Text('Refer & Earn unlocks soon',
              textAlign: TextAlign.center,
              style: poppins(20, w: FontWeight.w800, c: C.ink)),
          const SizedBox(height: 10),
          Text(
            'Once your first payment is done, you can invite your friends and family to ElderZha and earn Zha Seeds from here.',
            textAlign: TextAlign.center,
            style: poppins(14.5, c: C.txm, h: 1.5),
          ),
        ],
      );

  Widget _body() {
    final stats = Map<String, dynamic>.from(_data!['stats'] as Map? ?? {});
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        // Hero
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 26),
          decoration: const BoxDecoration(
            color: C.yellow,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          child: Row(children: [
            Expanded(
              flex: 6,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Good Friends\nMake a Better\nTomorrow',
                    style: poppins(25, w: FontWeight.w900, c: C.ink, h: 1.15)),
                const SizedBox(height: 10),
                Text(
                  'Invite your friends to ElderZha. For every successful referral, you earn $_per Zha Seeds and we plant 1 tree.',
                  style: poppins(12.5, w: FontWeight.w500, c: C.yellowDeep, h: 1.45),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            const Expanded(
              flex: 3,
              child: Center(child: Text('🌱', style: TextStyle(fontSize: 76))),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          child: Column(children: [
            _infoRow(const SeedBadge(size: 46), 'You earn $_per Zha Seeds',
                'for every successful referral'),
            _infoRow(const Text('🌳', style: TextStyle(fontSize: 38)),
                'We plant 1 tree', 'for each successful referral'),
            _infoRow(const Text('👥', style: TextStyle(fontSize: 34)),
                'Help more seniors', 'discover ElderZha'),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton.icon(
                onPressed: _openShare,
                icon: const Icon(Icons.ios_share_rounded, color: C.yellow),
                label: Text('Share Invite Link',
                    style: poppins(16, w: FontWeight.w800, c: C.yellow)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.ink,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
            const SizedBox(height: 18),
            // My referrals shortcut
            GestureDetector(
              onTap: _openMy,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: C.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: C.bd),
                ),
                child: Row(children: [
                  const SeedBadge(size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('My Referrals',
                          style: poppins(15, w: FontWeight.w800, c: C.ink)),
                      Text(
                          '${stats['successful'] ?? 0} successful · ${_data!['seeds_total'] ?? 0} Zha Seeds · ${_data!['trees'] ?? 0} trees',
                          style: poppins(12, c: C.txm)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: C.ink),
                ]),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _infoRow(Widget lead, String title, String sub) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: C.bd),
        ),
        child: Row(children: [
          SizedBox(width: 48, child: Center(child: lead)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: poppins(14.5, w: FontWeight.w800, c: C.ink)),
              Text(sub, style: poppins(12, c: C.txm)),
            ]),
          ),
        ]),
      );
}
