// lib/screens/onboarding/onboarding_screen.dart
//
// The very first screen a new user sees, before any login/signup.
// Rebuilt to match the client-provided design reference exactly:
// illustrated characters, green Nunito typography on a soft yellow
// background, and small circular Next buttons. Screen 3's feature
// cards intentionally show NO toggle switch — confirmed with the
// client that the reference's toggles were just a mockup sample,
// not something to actually build (these aren't real, user-
// changeable settings at this onboarding stage).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../utils/app_routes.dart';

class _DT {
  static const green = Color(0xFF1B5E3F);
  static const bgTop = Color(0xFFFFE97A);
  static const bgBottom = Color(0xFFFFD23F);
  static const yellow = Color(0xFFFFB800);
  static const purple = Color(0xFF8B6FE8);
  static const pink = Color(0xFFEE6B9E);
  static const white = Colors.white;
}

TextStyle _heading(double size) =>
    GoogleFonts.nunito(fontSize: size, fontWeight: FontWeight.w800, color: _DT.green, height: 1.2);
TextStyle _body(double size, {Color color = _DT.green, FontWeight w = FontWeight.w500}) =>
    GoogleFonts.nunito(fontSize: size, fontWeight: w, color: color.withOpacity(0.85), height: 1.4);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;
  static const _pageCount = 3;

  void _next() {
    if (_page < _pageCount - 1) {
      _ctrl.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeInOut);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.register);
    }
  }

  void _skip() => Navigator.pushReplacementNamed(context, AppRoutes.register);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_DT.bgTop, _DT.bgBottom],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            Expanded(
              child: PageView(
                controller: _ctrl,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _WelcomePage(onSkip: _skip),
                  _FeaturesPage(onSkip: _skip),
                  _SafetyPage(onSkip: _skip),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
              child: Row(children: [
                SmoothPageIndicator(
                  controller: _ctrl,
                  count: _pageCount,
                  effect: ExpandingDotsEffect(
                    activeDotColor: _DT.green, dotColor: _DT.green.withOpacity(0.25),
                    dotHeight: 7, dotWidth: 7, expansionFactor: 3,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _next,
                  child: Container(
                    width: 52, height: 52,
                    decoration: const BoxDecoration(color: _DT.green, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

Widget _skipButton(VoidCallback onSkip) => Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 20, top: 4),
        child: TextButton(
          onPressed: onSkip,
          child: Text('Skip', style: _body(13, w: FontWeight.w700)),
        ),
      ),
    );

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onSkip});
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _skipButton(onSkip),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(children: [
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ELDERZHA', style: GoogleFonts.nunito(fontSize: 30, fontWeight: FontWeight.w900, color: _DT.green, letterSpacing: 0.5)),
                Text("Life Doesn't Retire.", style: _heading(17)),
              ]),
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset('assets/images/onboarding_couple.png', height: 260, fit: BoxFit.cover),
            ),
            const SizedBox(height: 20),
            Text('Welcome to Elderzha!', textAlign: TextAlign.center, style: _heading(24)),
            const SizedBox(height: 8),
            Text('Your everyday companion for a happier, healthier and more connected life.',
                textAlign: TextAlign.center, style: _body(13.5)),
          ]),
        ),
      ),
    ]);
  }
}

class _FeaturesPage extends StatelessWidget {
  const _FeaturesPage({required this.onSkip});
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _skipButton(onSkip),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(children: [
            Text('Stay Active,\nStay Connected', textAlign: TextAlign.center, style: _heading(24)),
            const SizedBox(height: 8),
            Text('From daily reminders to fun activities, Elderzha keeps you engaged every day.',
                textAlign: TextAlign.center, style: _body(13)),
            const SizedBox(height: 18),
            Stack(alignment: Alignment.center, children: [
              ClipOval(
                child: Image.asset('assets/images/onboarding_woman.png', width: 190, height: 190, fit: BoxFit.cover),
              ),
              Positioned(top: 0, left: 0, child: _iconBadge('🔔', 'Reminders\n& Alarms', _DT.yellow)),
              Positioned(top: 0, right: 0, child: _iconBadge('🧠', 'Activities\n& Polls', _DT.purple)),
              Positioned(bottom: 6, left: 6, child: _iconBadge('👥', 'Community', _DT.pink)),
              Positioned(bottom: 6, right: 6, child: _iconBadge('🚶', 'Walking', const Color(0xFF3FA35E))),
            ]),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: _DT.white.withOpacity(0.6), borderRadius: BorderRadius.circular(16)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.calendar_month_rounded, color: _DT.green, size: 18),
                const SizedBox(width: 8),
                Text('Never miss what matters.', style: _body(13, w: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _iconBadge(String emoji, String label, Color color) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 54, height: 54,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
      ),
      const SizedBox(height: 4),
      Text(label, textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: _DT.green)),
    ]);
  }
}

class _SafetyPage extends StatelessWidget {
  const _SafetyPage({required this.onSkip});
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _skipButton(onSkip),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(children: [
            Text('More Safety.\nMore Possibilities.', textAlign: TextAlign.center, style: _heading(23)),
            const SizedBox(height: 8),
            Text('Get peace of mind with Fall Detection and discover local offers — both included with your sign up!',
                textAlign: TextAlign.center, style: _body(13)),
            const SizedBox(height: 18),
            _featureCard('🛡️', _DT.green, 'Fall Detection', 'Get help, when you need it most.'),
            const SizedBox(height: 10),
            _featureCard('🎁', _DT.purple, 'Local Offers', 'Exclusive deals & offers near you.'),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset('assets/images/onboarding_man.png', height: 170, fit: BoxFit.cover),
            ),
          ]),
        ),
      ),
    ]);
  }

  // No toggle switch here — confirmed with the client that the
  // reference design's ON toggle was just a mockup sample, not an
  // actual setting to build; this is purely informational.
  Widget _featureCard(String emoji, Color color, String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _DT.white.withOpacity(0.7), borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(title, style: GoogleFonts.nunito(fontSize: 14.5, fontWeight: FontWeight.w800, color: _DT.green)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: _DT.yellow, borderRadius: BorderRadius.circular(999)),
                child: Text('Premium', style: GoogleFonts.nunito(fontSize: 9, fontWeight: FontWeight.w800, color: _DT.green)),
              ),
            ]),
            const SizedBox(height: 2),
            Text(subtitle, style: _body(11.5)),
          ]),
        ),
      ]),
    );
  }
}
