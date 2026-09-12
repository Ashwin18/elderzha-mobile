// lib/screens/auth/benefits_showcase_screen.dart
//
// Shown right after OTP verification succeeds, before profile
// setup even begins — a swipeable, colorful carousel introducing
// every feature the app has, so new users know exactly what
// they're signing up for from the very first moment.
//
// BenefitsList (the flat list variant) is still used separately by
// the subscription-gate renewal screen — this file's carousel is
// specifically the new-signup first-impression experience.
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

  // (emoji, title, subtitle, bg, fg, isLaunchOffer)
  static const _pages = [
    ('⏰', 'Reminders and alarms', 'Never miss a dose or appointment — smart alarms timed around your day.', Color(0xFFE6F1FB), Color(0xFF0C447C), false),
    ('🗳️', 'Activities and polls', 'Join in on daily activities and share your voice in community polls.', Color(0xFFEAF3DE), Color(0xFF27500A), false),
    ('💬', 'Community', 'Connect, share, and hear from others who understand your journey.', Color(0xFFEEEDFE), Color(0xFF3C3489), false),
    ('📖', 'Daily diary', 'Log your mood, your day, and watch your story unfold over time.', Color(0xFFFAECE7), Color(0xFF712B13), false),
    ('🌳', 'Family tree', 'See your whole family, beautifully, as you add them one by one.', Color(0xFFFBEAF0), Color(0xFF72243E), false),
    ('🚨', 'SOS alert', 'One tap instantly reaches your family in an emergency.', Color(0xFFFAEEDA), Color(0xFF854F0B), true),
    ('🎁', 'Local offers', 'Deals and discounts from stores and services near you.', Color(0xFFFAEEDA), Color(0xFF854F0B), true),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _ctrl.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeInOut);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.setupProfile, arguments: widget.profileArgs);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _pages[_page];
    final bg = current.$4;
    final fg = current.$5;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, top: 4),
              child: TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.setupProfile, arguments: widget.profileArgs),
                child: Text('Skip', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: fg.withOpacity(0.6))),
              ),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _ctrl,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: _pages.length,
              itemBuilder: (_, i) => _FeaturePage(
                emoji: _pages[i].$1,
                title: _pages[i].$2,
                subtitle: _pages[i].$3,
                fg: _pages[i].$5,
                isLaunchOffer: _pages[i].$6,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: Column(children: [
              SmoothPageIndicator(
                controller: _ctrl,
                count: _pages.length,
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
                      _page < _pages.length - 1 ? 'Next →' : 'Get started',
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

class _FeaturePage extends StatelessWidget {
  const _FeaturePage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.fg,
    required this.isLaunchOffer,
  });
  final String emoji;
  final String title;
  final String subtitle;
  final Color fg;
  final bool isLaunchOffer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 64))),
          ),
          const SizedBox(height: 32),
          if (isLaunchOffer) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(999)),
              child: Text('✨ Included free — launch offer',
                  style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w800, color: fg),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 14.5, color: fg.withOpacity(0.75), height: 1.5),
          ),
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
