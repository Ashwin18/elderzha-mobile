// lib/screens/auth/benefits_showcase_screen.dart
//
// Shown right after OTP verification succeeds, before profile
// setup even begins. Visual design matches the client-provided
// reference: soft yellow gradient background, navy headings,
// Nunito typography, feature cards with a circular arrow button,
// and a dedicated launch-offer moment for the 2 premium features.
//
// BenefitsList (the flat list variant) is still used separately by
// the subscription-gate renewal screen — unchanged, this file's
// carousel is specifically the new-signup first-impression screen.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../utils/app_routes.dart';

// ── Design tokens, per the client-provided design reference ──────
class _DT {
  static const primaryYellow = Color(0xFFFFB800);
  static const brightYellow = Color(0xFFFFC928);
  static const softBg = Color(0xFFFFF8DC);
  static const navy = Color(0xFF102A56);
  static const white = Color(0xFFFFFFFF);
  static const softCard = Color(0xFFFFF3C4);
}

TextStyle _heading(double size, {Color color = _DT.navy}) =>
    GoogleFonts.nunito(fontSize: size, fontWeight: FontWeight.w800, color: color);
TextStyle _body(double size, {Color color = _DT.navy, FontWeight w = FontWeight.w500}) =>
    GoogleFonts.nunito(fontSize: size, fontWeight: w, color: color);
TextStyle _button(double size, {Color color = _DT.white}) =>
    GoogleFonts.nunito(fontSize: size, fontWeight: FontWeight.w700, color: color);

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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_DT.softBg, _DT.softCard],
          ),
        ),
        child: SafeArea(
          child: Stack(children: [
            // Soft decorative sparkle accents, matching the reference
            const Positioned(top: 30, right: 40, child: Text('✦', style: TextStyle(fontSize: 18, color: _DT.primaryYellow))),
            const Positioned(top: 90, left: 20, child: Text('✦', style: TextStyle(fontSize: 12, color: _DT.primaryYellow))),
            Column(children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 4),
                  child: TextButton(
                    onPressed: _goToProfile,
                    child: Text('Skip', style: _body(14, color: _DT.navy.withOpacity(0.55), w: FontWeight.w600)),
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
                    effect: const ExpandingDotsEffect(
                      activeDotColor: _DT.navy, dotColor: Color(0x33102A56),
                      dotHeight: 8, dotWidth: 8, expansionFactor: 3,
                    ),
                  ),
                  const SizedBox(height: 22),
                  GestureDetector(
                    onTap: _next,
                    child: Container(
                      width: double.infinity, height: 54,
                      decoration: BoxDecoration(
                        color: _DT.primaryYellow,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [BoxShadow(color: _DT.primaryYellow.withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 6))],
                      ),
                      child: Center(
                        child: Text(
                          _page < _pageCount - 1 ? 'Next →' : 'Get started →',
                          style: _button(17, color: _DT.navy),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _CoreFeaturesGridPage extends StatelessWidget {
  const _CoreFeaturesGridPage();

  // (emoji, title, subtitle)
  static const _items = [
    ('⏰', 'Reminders\n& alarms', 'Meals, medicines,\nimportant times'),
    ('🗳️', 'Activities\n& polls', 'Stay engaged,\nbe heard'),
    ('👨‍👩‍👧', 'Community', 'Connect, share,\nmake friends'),
    ('📖', 'Daily diary', 'Keep track,\nfeel in control'),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // Soft organic blob shapes behind the heading, approximating
      // the reference's wavy background accent.
      Positioned(
        top: -40, left: -60,
        child: Container(
          width: 180, height: 180,
          decoration: BoxDecoration(color: _DT.brightYellow.withOpacity(0.25), shape: BoxShape.circle),
        ),
      ),
      Positioned(
        top: 10, right: -70,
        child: Container(
          width: 160, height: 160,
          decoration: BoxDecoration(color: _DT.primaryYellow.withOpacity(0.2), shape: BoxShape.circle),
        ),
      ),
      SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text('Everything you need', textAlign: TextAlign.center, style: _heading(26)),
            const SizedBox(height: 4),
            Text('5 features, all included', style: _body(14, color: _DT.navy.withOpacity(0.7))),
            const SizedBox(height: 4),
            Container(width: 90, height: 3, decoration: BoxDecoration(color: _DT.primaryYellow, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.95,
              children: _items.map((item) => _FeatureCard(emoji: item.$1, title: item.$2, subtitle: item.$3)).toList(),
            ),
            const SizedBox(height: 12),
            _FamilyTreeCard(),
          ],
        ),
      ),
    ]);
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.emoji, required this.title, required this.subtitle});
  final String emoji, title, subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _DT.softCard, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 46, height: 46,
          decoration: const BoxDecoration(color: _DT.white, shape: BoxShape.circle),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
        ),
        const Spacer(),
        Text(title, style: _heading(15)),
        const SizedBox(height: 3),
        Text(subtitle, style: _body(11.5, color: _DT.navy.withOpacity(0.65))),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: 30, height: 30,
            decoration: const BoxDecoration(color: _DT.brightYellow, shape: BoxShape.circle),
            child: const Icon(Icons.arrow_forward_rounded, size: 15, color: _DT.navy),
          ),
        ),
      ]),
    );
  }
}

class _FamilyTreeCard extends StatelessWidget {
  const _FamilyTreeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _DT.softCard, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Container(
          width: 50, height: 50,
          decoration: const BoxDecoration(color: _DT.white, shape: BoxShape.circle),
          child: const Center(child: Text('🌳', style: TextStyle(fontSize: 24))),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Family tree', style: _heading(16)),
            const SizedBox(height: 2),
            Text('Keep your loved ones close', style: _body(11.5, color: _DT.navy.withOpacity(0.65))),
          ]),
        ),
        Container(
          width: 32, height: 32,
          decoration: const BoxDecoration(color: _DT.brightYellow, shape: BoxShape.circle),
          child: const Icon(Icons.arrow_forward_rounded, size: 16, color: _DT.navy),
        ),
      ]),
    );
  }
}

class _LaunchOfferPage extends StatelessWidget {
  const _LaunchOfferPage();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            child: Image.asset(
              'assets/images/home_header_photo_v3.jpg',
              height: 190,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 0),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: _DT.brightYellow, borderRadius: BorderRadius.circular(999)),
                child: Text('🚀  Launch offer', style: _button(13.5, color: _DT.navy)),
              ),
              const SizedBox(height: 18),
              Text('Plus, included free', textAlign: TextAlign.center, style: _heading(28)),
              const SizedBox(height: 6),
              Text('Premium features — no extra cost',
                  textAlign: TextAlign.center, style: _body(14, color: _DT.navy.withOpacity(0.7))),
              const SizedBox(height: 26),
              Row(children: [
                Expanded(child: _LaunchOfferCard(emoji: '🚨', title: 'SOS alert', subtitle: 'Quick help,\nwhen it matters')),
                const SizedBox(width: 12),
                Expanded(child: _LaunchOfferCard(emoji: '🎁', title: 'Local offers', subtitle: 'Special deals,\nnear you')),
              ]),
              const SizedBox(height: 22),
              Text('More care. More moments. ♥',
                  style: GoogleFonts.caveat(fontSize: 18, fontWeight: FontWeight.w600, color: _DT.navy)),
              const SizedBox(height: 12),
            ]),
          ),
        ],
      ),
    );
  }
}

class _LaunchOfferCard extends StatelessWidget {
  const _LaunchOfferCard({required this.emoji, required this.title, required this.subtitle});
  final String emoji, title, subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _DT.softCard, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 34)),
        const SizedBox(height: 10),
        Text(title, textAlign: TextAlign.center, style: _heading(15)),
        const SizedBox(height: 3),
        Text(subtitle, textAlign: TextAlign.center, style: _body(11, color: _DT.navy.withOpacity(0.65))),
      ]),
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
                Text(title, style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF1A1726))),
                Text(subtitle, style: GoogleFonts.nunito(fontSize: 11, color: const Color(0xFF8A8878))),
              ]),
            ),
            if (unlocked)
              const Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF27500A))
            else if (isLaunchOffer)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFEF9F27), borderRadius: BorderRadius.circular(999)),
                child: Text('Launch offer', style: GoogleFonts.nunito(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF412402))),
              ),
          ]),
        );
      }).toList(),
    );
  }
}
