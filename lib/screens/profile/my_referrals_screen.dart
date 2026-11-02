// lib/screens/profile/my_referrals_screen.dart
//
// My Referrals: totals, filter chips, the list of friends with their status
// and seeds earned, a Zha Seeds summary and the trees planted.
import 'package:flutter/material.dart';

import '../../services/referral_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/ez_dates.dart';
import '../../widgets/seeds_earned_dialog.dart';

class MyReferralsScreen extends StatefulWidget {
  const MyReferralsScreen({super.key});

  @override
  State<MyReferralsScreen> createState() => _MyReferralsScreenState();
}

class _MyReferralsScreenState extends State<MyReferralsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await ReferralService.load();
    if (!mounted) return;
    setState(() {
      _data = d;
      _loading = false;
    });
  }

  int _n(String k) => int.tryParse('${(_data?['stats'] as Map?)?[k] ?? 0}') ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: C.ink,
        title: Text('My Referrals',
            style: poppins(17, w: FontWeight.w800, c: C.ink)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: C.yellowDark))
          : _data == null
              ? Center(
                  child: TextButton(
                      onPressed: () {
                        setState(() => _loading = true);
                        _load();
                      },
                      child: const Text('Could not load. Tap to retry.')))
              : RefreshIndicator(color: C.yellowDark, onRefresh: _load, child: _content()),
    );
  }

  Widget _content() {
    final seeds = int.tryParse('${_data!['seeds_total'] ?? 0}') ?? 0;
    final trees = int.tryParse('${_data!['trees'] ?? 0}') ?? 0;
    final all = (_data!['recent'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final shown =
        _filter == 'all' ? all : all.where((e) => e['status'] == _filter).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
      children: [
        Row(children: [
          _stat(const Text('👥', style: TextStyle(fontSize: 24)), '${_n('total')}', 'Total\nReferrals'),
          const SizedBox(width: 8),
          _stat(const SeedBadge(size: 28), '$seeds', 'Seeds\nCollected'),
          const SizedBox(width: 8),
          _stat(const Icon(Icons.check_circle_rounded, color: C.green, size: 26), '${_n('successful')}', 'Successful'),
          const SizedBox(width: 8),
          _stat(const Text('🌳', style: TextStyle(fontSize: 24)), '$trees', 'Trees\nPlanted'),
        ]),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _chip('all', 'All (${_n('total')})'),
            _chip('successful', 'Successful (${_n('successful')})'),
            _chip('in_trial', 'In Trial (${_n('in_trial')})'),
            _chip('invited', 'Invited (${_n('invited')})'),
          ]),
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                color: C.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.bd)),
            child: Text(
              all.isEmpty
                  ? 'No one has joined with your code yet. Share your invite link and they will appear here.'
                  : 'Nobody in this group yet.',
              textAlign: TextAlign.center,
              style: poppins(13, c: C.txm, h: 1.45),
            ),
          )
        else
          ...shown.map(_row),
        const SizedBox(height: 18),
        // Seeds summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: C.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.bd)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('My Seeds Summary', style: poppins(15, w: FontWeight.w800, c: C.ink)),
            const SizedBox(height: 12),
            Row(children: [
              const SeedBadge(size: 30),
              const SizedBox(width: 10),
              Expanded(child: Text('Total earned (Referrals)', style: poppins(13, c: C.txm))),
              Text('$seeds', style: poppins(16, w: FontWeight.w900, c: C.ink)),
            ]),
            const Divider(height: 22),
            Row(children: [
              Expanded(child: Text('Available balance', style: poppins(13, w: FontWeight.w700, c: C.ink))),
              Text('$seeds', style: poppins(22, w: FontWeight.w900, c: C.green)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        // Impact
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: const Color(0xFFE8F6EC), borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            const Text('🌳', style: TextStyle(fontSize: 44)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('My Impact from Referrals',
                    style: poppins(13, w: FontWeight.w700, c: const Color(0xFF1E7A43))),
                Text('$trees ${trees == 1 ? 'Tree' : 'Trees'} Planted',
                    style: poppins(20, w: FontWeight.w900, c: C.ink)),
                Text('Through your successful referrals. Together we are creating a greener and kinder world.',
                    style: poppins(11.5, c: C.txm, h: 1.4)),
              ]),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _stat(Widget icon, String n, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: C.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.bd)),
          child: Column(children: [
            SizedBox(height: 30, child: Center(child: icon)),
            const SizedBox(height: 4),
            Text(n, style: poppins(18, w: FontWeight.w900, c: C.ink)),
            Text(label,
                textAlign: TextAlign.center,
                style: poppins(9.5, w: FontWeight.w600, c: C.txm, h: 1.2)),
          ]),
        ),
      );

  Widget _chip(String key, String label) {
    final sel = _filter == key;
    return GestureDetector(
      onTap: () => setState(() => _filter = key),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? C.ink : C.bg2,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: poppins(12, w: FontWeight.w800, c: sel ? C.yellow : C.txm)),
      ),
    );
  }

  Widget _row(Map<String, dynamic> r) {
    final status = r['status']?.toString() ?? 'invited';
    final (label, bg, fg, sub) = switch (status) {
      'successful' => ('Successful', const Color(0xFFDDF5E6), C.green, 'First payment completed'),
      'in_trial' => ('In Trial', const Color(0xFFFFF3C4), C.yellowDeep, 'In free trial'),
      _ => ('Invited', C.bg2, C.txm, 'Signed up with your code'),
    };
    final joined = parseYmd(r['joined']);
    final seeds = int.tryParse('${r['seeds'] ?? 0}') ?? 0;
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
              Text('Joined on ${fmtDay(joined)}', style: poppins(11.5, c: C.txl)),
            Text(sub, style: poppins(11, c: C.txl)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
            child: Text(label, style: poppins(11.5, w: FontWeight.w800, c: fg)),
          ),
          if (seeds > 0) ...[
            const SizedBox(height: 4),
            Text('+$seeds Seeds', style: poppins(11.5, w: FontWeight.w800, c: C.green)),
          ],
        ]),
      ]),
    );
  }
}
