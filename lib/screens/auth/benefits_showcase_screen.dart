// lib/screens/auth/benefits_showcase_screen.dart
//
// Shown right after OTP verification succeeds, before profile
// setup even begins. Condensed to 2 swipeable pages (not one per
// feature) so new users see everything in a quick glance rather
// than a long swipe sequence:
//   Page 1 — a compact grid of all 5 core features at once
//   Page 2 — a dedicated celebratory moment for the 2 premium
//            features included free as a launch offer
//
// BenefitsList (the flat list variant) is still used separately by
// the subscription-gate renewal screen — unchanged, this file's
// carousel is specifically the new-signup first-impression screen.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../utils/app_routes.dart';

class BenefitsShowcaseScreen extends StatefulWidget {
  final String? userName;
  final Map<String, dynamic>? profileArgs;
  const BenefitsShowcaseScreen({super.key, this.userName, this.profileArgs});

  @override
  State<BenefitsShowcaseScreen> createState() => _BenefitsShowcaseScreenState();
}

class _BenefitsShowcaseScreenState extends State<BenefitsShowcaseScreen> {
  final _ctrl = PageController();
  int _page = 0;

  static const _pageCount = 2;
  static const _bgColors = [Color(0xFFE6F1FB), Color(0xFFFAEEDA)];
  static const _fgColors = [Color(0xFF0C447C), Color(0xFF854F0B)];

  void _goToProfile() =>
      Navigator.pushReplacementNamed(context, AppRoutes.setupProfile, arguments: widget.profileArgs);

  void _next() {
    if (_page < _pageCount - 1) {
      _ctrl.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeInOut);
    } else {
      _goToProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = _bgColors[_page];
    final fg = _fgColors[_page];

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, top: 4),
              child: TextButton(
                onPressed: _goToProfile,
                child: Text('Skip', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: fg.withOpacity(0.6))),
              ),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _ctrl,
              onPageChanged: (i) => setState(() => _page = i),
              children: const [_CoreFeaturesGridPage(), _LaunchOfferPage()],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: Column(children: [
              SmoothPageIndicator(
                controller: _ctrl,
                count: _pageCount,
                effect: ExpandingDotsEffect(
                  activeDotColor: fg, dotColor: fg.withOpacity(0.25),
                  dotHeight: 8, dotWidth: 8, expansionFactor: 3,
                ),
              ),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: _next,
                child: Container(
                  width: double.infinity, height: 52,
                  decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(16)),
                  child: Center(
                    child: Text(
                      _page < _pageCount - 1 ? 'Next →' : 'Get started',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _CoreFeaturesGridPage extends StatelessWidget {
  const _CoreFeaturesGridPage();

  // (emoji, label)
  static const _items = [
    ('⏰', 'Reminders\n& alarms'),
    ('🗳️', 'Activities\n& polls'),
    ('💬', 'Community'),
    ('📖', 'Daily diary'),
    ('🌳', 'Family tree'),
  ];

  @override
  Widget build(BuildContext context) {
    const fg = Color(0xFF042C53);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Everything you need',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: fg)),
          const SizedBox(height: 4),
          Text('5 features, all included',
              style: GoogleFonts.poppins(fontSize: 13.5, color: fg.withOpacity(0.75))),
          const SizedBox(height: 22),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.05,
            children: _items.map((item) {
              return Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.$1, style: const TextStyle(fontSize: 30)),
                    const SizedBox(height: 6),
                    Text(item.$2, textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _LaunchOfferPage extends StatelessWidget {
  const _LaunchOfferPage();

  @override
  Widget build(BuildContext context) {
    const fg = Color(0xFF412402);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(color: const Color(0xFFEF9F27), borderRadius: BorderRadius.circular(999)),
            child: Text('✨ Launch offer', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700, color: fg)),
          ),
          const SizedBox(height: 16),
          Text('Plus, included free',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: fg)),
          const SizedBox(height: 4),
          Text('Normally premium-tier — yours at no extra cost',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: fg.withOpacity(0.75))),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(children: [
                  const Text('🚨', style: TextStyle(fontSize: 36)),
                  const SizedBox(height: 10),
                  Text('SOS alert', style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: fg)),
                ]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(children: [
                  const Text('🎁', style: TextStyle(fontSize: 36)),
                  const SizedBox(height: 10),
                  Text('Local offers', style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: fg)),
                ]),
              ),
            ),
          ]),
        ],
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
