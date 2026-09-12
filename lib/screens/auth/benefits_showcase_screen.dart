// lib/screens/auth/benefits_showcase_screen.dart
//
// Shown right after a new user finishes profile + alarm setup,
// right before the trial/subscription (payment) screen — the
// moment they're about to be asked to commit is exactly when
// they should see what they're committing to.
//
// Same 6-benefit list is reused for the subscription-gate renewal
// case (isRenewal: true) via a shared _BenefitsList widget, so the
// two screens can't drift apart over time.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_routes.dart';

class BenefitsShowcaseScreen extends StatelessWidget {
  final String? userName;
  const BenefitsShowcaseScreen({super.key, this.userName});

  @override
  Widget build(BuildContext context) {
    final name = userName?.trim();
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF8),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 12),
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1726),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.celebration_rounded, color: Color(0xFFFFCC01), size: 24),
                ),
                const SizedBox(height: 14),
                Text(
                  (name != null && name.isNotEmpty)
                      ? 'Welcome to ElderZha, $name'
                      : 'Welcome to ElderZha',
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF1A1726)),
                ),
                const SizedBox(height: 4),
                Text(
                  "Here's everything waiting for you",
                  style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF6B6960)),
                ),
                const SizedBox(height: 18),
                const BenefitsList(),
                const SizedBox(height: 10),
                Text(
                  'SOS alert and Local offers are normally premium-tier — included free while this launch offer lasts.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF854F0B), height: 1.4),
                ),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.payment),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1726),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text('Continue',
                    style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w700, color: const Color(0xFFFFCC01))),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class BenefitsList extends StatelessWidget {
  const BenefitsList({super.key, this.unlocked = false});
  final bool unlocked;

  // (icon, bg, fg, title, subtitle, isLaunchOffer)
  static const _items = [
    (Icons.alarm_rounded, Color(0xFFE6F1FB), Color(0xFF0C447C), 'Reminders and alarms', 'Never miss a dose or appointment', false),
    (Icons.how_to_vote_rounded, Color(0xFFEAF3DE), Color(0xFF27500A), 'Activities and polls', 'Join in and share your voice', false),
    (Icons.forum_rounded, Color(0xFFEEEDFE), Color(0xFF3C3489), 'Community', 'Connect with others like you', false),
    (Icons.menu_book_rounded, Color(0xFFFAECE7), Color(0xFF712B13), 'Daily diary', 'Log your mood and your day', false),
    (Icons.family_restroom_rounded, Color(0xFFFBEAF0), Color(0xFF72243E), 'Family tree', 'See your whole family, visually', false),
    (Icons.sos_rounded, Color(0xFFFAEEDA), Color(0xFF854F0B), 'SOS alert', 'One tap to reach family instantly', true),
    (Icons.card_giftcard_rounded, Color(0xFFFAEEDA), Color(0xFF854F0B), 'Local offers', 'Deals from stores near you', true),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _items.map((item) {
        final (icon, bg, fg, title, subtitle, isLaunchOffer) = item;
        final highlight = isLaunchOffer && !unlocked;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: highlight ? const Color(0xFFFAEEDA) : Colors.white,
            border: Border.all(color: highlight ? const Color(0xFFEF9F27) : const Color(0xFFE8E5DA)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 17, color: fg),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF1A1726))),
                Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF8A8878))),
              ]),
            ),
            if (unlocked)
              const Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF27500A))
            else if (isLaunchOffer)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFEF9F27), borderRadius: BorderRadius.circular(999)),
                child: Text('Launch offer', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF412402))),
              ),
          ]),
        );
      }).toList(),
    );
  }
}
