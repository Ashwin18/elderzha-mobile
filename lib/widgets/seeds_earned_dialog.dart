import 'package:flutter/material.dart';

import '../services/referral_service.dart';
import '../theme/app_theme.dart';

/// Gold "Zha Seed" badge used across Refer & Earn.
class SeedBadge extends StatelessWidget {
  const SeedBadge({super.key, this.size = 44});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFE27A), Color(0xFFF0A500)],
          ),
        ),
        child: Icon(Icons.eco_rounded, color: Colors.white, size: size * .55),
      );
}

/// "Hooray! You earned N Zha Seeds!" — shown once after a friend's first
/// payment. [onViewReferrals] opens the My Referrals page.
Future<void> showSeedsEarnedDialog(BuildContext context, int seeds,
    {VoidCallback? onViewReferrals}) async {
  ReferralService.markSeen();
  await showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(.5),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
        decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SeedBadge(size: 84),
          const SizedBox(height: 14),
          Text('Hooray!', style: poppins(26, w: FontWeight.w900, c: C.ink)),
          const SizedBox(height: 4),
          Text('You earned $seeds Zha Seeds!',
              textAlign: TextAlign.center,
              style: poppins(18, w: FontWeight.w800, c: C.ink)),
          const SizedBox(height: 8),
          Text('Your friend has completed the trial and made the first payment.',
              textAlign: TextAlign.center,
              style: poppins(13.5, c: C.txm, h: 1.45)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F6EC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              const Text('🌳', style: TextStyle(fontSize: 34)),
              const SizedBox(width: 10),
              Expanded(
                child: Text('We have also planted 1 tree for a greener tomorrow.',
                    style: poppins(13, w: FontWeight.w700, c: const Color(0xFF1E7A43), h: 1.4)),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                onViewReferrals?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: C.yellow,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('View My Referrals',
                  style: poppins(15, w: FontWeight.w800, c: C.ink)),
            ),
          ),
        ]),
      ),
    ),
  );
}
