// lib/screens/onboarding/onboarding_screen.dart
//
// The very first screen a new user sees, before any login/signup.
// Redesigned to match the app's actual yellow/navy theme (the
// earlier green-themed version came from a client reference and
// didn't match the rest of the app), reusing the same feature-card
// language as the post-signup showcase for visual consistency.
// This "premium" pass adds layered glow decorations, glass-style
// panels, gradient icon badges with their own shadows, and a
// swipe hint on the first page — all built directly in code, no
// external assets beyond the existing real photo already used
// elsewhere in the app.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../utils/app_routes.dart';

class _DT {
  static const ink = Color(0xFF1A1726);
  static const bgTop = Color(0xFFFFFBEA);
  static const bgMid = Color(0xFFFFF3C4);
  static const bgBottom = Color(0xFFFFE9A0);
  static const yellowDark = Color(0xFFFFB800);
  static const yellowLight = Color(0xFFFFC928);
  static const purple = Color(0xFF8B6FE8);
  static const pink = Color(0xFFEE6B9E);
  static const green = Color(0xFF4E9E3C);
  static const orange = Color(0xFFEF9F27);
  static const txm = Color(0xFF6B6858);
}

TextStyle _heading(double size) =>
    GoogleFonts.nunito(fontSize: size, fontWeight: FontWeight.w800, color: _DT.ink, height: 1.2);
TextStyle _body(double size, {FontWeight w = FontWeight.w500}) =>
    GoogleFonts.nunito(fontSize: size, fontWeight: w, color: _DT.txm, height: 1.4);

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
            colors: [_DT.bgTop, _DT.bgMid, _DT.bgBottom],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            Expanded(
              child: PageView(
                controller: _ctrl,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _WelcomePage(onSkip: _skip, showSwipeHint: _page == 0),
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
                    activeDotColor: _DT.ink, dotColor: _DT.ink.withOpacity(0.2),
                    dotHeight: 7, dotWidth: 7, expansionFactor: 3,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _next,
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 140),
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_DT.yellowLight, _DT.yellowDark]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: _DT.yellowDark.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 8))],
                    ),
                    child: Center(
                      child: Text(_page < _pageCount - 1 ? 'Next →' : 'Get started →',
                          style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: _DT.ink)),
                    ),
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

// Soft radial glow, used behind hero content for depth.
Widget _glow({required double top, double? left, double? right, required double size, required Color color}) {
  return Positioned(
    top: top, left: left, right: right,
    child: Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withOpacity(0.32), color.withOpacity(0.0)]),
      ),
    ),
  );
}

// Semi-transparent "glass" panel — a lightweight stand-in for a
// true blur effect, kept simple for smooth performance across
// devices.
BoxDecoration _glassPanel({double radius = 20}) => BoxDecoration(
      color: Colors.white.withOpacity(0.55),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 6))],
    );

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
  const _WelcomePage({required this.onSkip, required this.showSwipeHint});
  final VoidCallback onSkip;
  final bool showSwipeHint;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      _glow(top: -30, right: -50, size: 170, color: _DT.yellowDark),
      _glow(top: 260, left: -60, size: 190, color: _DT.yellowLight),
      Column(children: [
        _skipButton(onSkip),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(children: [
              const SizedBox(height: 4),
              Container(
                width: double.infinity, height: 190,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(fit: StackFit.expand, children: [
                  Image.asset('assets/images/home_header_photo_v3.jpg', fit: BoxFit.cover),
                  Positioned(
                    left: 0, right: 0, bottom: 0, height: 56,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                            colors: [Colors.black.withOpacity(0.18), Colors.transparent]),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: _glassPanel(),
                child: Column(children: [
                  Text('Welcome to ElderZha!', textAlign: TextAlign.center, style: _heading(20)),
                  const SizedBox(height: 6),
                  Text('Your everyday companion for a happier, healthier and more connected life.',
                      textAlign: TextAlign.center, style: _body(12.5)),
                ]),
              ),
            ]),
          ),
        ),
      ]),
      if (showSwipeHint)
        Positioned(
          right: 8, bottom: 88,
          child: IgnorePointer(
            child: Row(children: [
              Text('swipe', style: GoogleFonts.nunito(fontSize: 11.5, fontWeight: FontWeight.w700, color: _DT.ink.withOpacity(0.55))),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, size: 15, color: _DT.ink.withOpacity(0.55)),
            ]),
          ),
        ),
    ]);
  }
}

class _FeaturesPage extends StatelessWidget {
  const _FeaturesPage({required this.onSkip});
  final VoidCallback onSkip;

  static const _items = [
    ('⏰', 'Reminders\n& Alarms', _DT.yellowDark),
    ('🗳️', 'Activities\n& Polls', _DT.purple),
    ('💬', 'Community', _DT.pink),
    ('📖', 'Daily Diary', Color(0xFFD9713F)),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      _glow(top: -20, left: -40, size: 150, color: _DT.purple),
      _glow(top: 300, right: -50, size: 160, color: _DT.pink),
      Column(children: [
        _skipButton(onSkip),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Column(children: [
              Text('Everything you need', textAlign: TextAlign.center, style: _heading(21)),
              const SizedBox(height: 4),
              Text('5 features, all included', style: _body(12)),
              const SizedBox(height: 18),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.15,
                children: _items.map((i) => _featureBadge(i.$1, i.$2, i.$3)).toList(),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: _glassPanel(radius: 16),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF7BC26B), _DT.green]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.park_rounded, color: Colors.white, size: 17),
                  ),
                  const SizedBox(width: 10),
                  Text('Family Tree', style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w700, color: _DT.ink)),
                ]),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: _glassPanel(radius: 16),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.calendar_month_rounded, color: _DT.ink, size: 17),
                  const SizedBox(width: 8),
                  Text('Never miss what matters.', style: _body(12.5, w: FontWeight.w700)),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    ]);
  }

  Widget _featureBadge(String emoji, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _glassPanel(radius: 18),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [color.withOpacity(0.8), color]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
        ),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: _DT.ink)),
      ]),
    );
  }
}

class _SafetyPage extends StatelessWidget {
  const _SafetyPage({required this.onSkip});
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      _glow(top: -30, right: -30, size: 170, color: _DT.orange),
      Column(children: [
        _skipButton(onSkip),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_DT.yellowLight, _DT.orange]),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [BoxShadow(color: _DT.orange.withOpacity(0.5), blurRadius: 14, offset: const Offset(0, 6))],
                ),
                child: Text('✨ Launch offer', style: GoogleFonts.nunito(fontSize: 11.5, fontWeight: FontWeight.w800, color: const Color(0xFF412402))),
              ),
              const SizedBox(height: 16),
              Text('Plus, included free', textAlign: TextAlign.center, style: _heading(20)),
              const SizedBox(height: 4),
              Text('Premium features — no extra cost', style: _body(12)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _premiumCard('🚨', const [Color(0xFF5A7D4E), Color(0xFF2F5A22)], 'SOS Alert')),
                const SizedBox(width: 12),
                Expanded(child: _premiumCard('🎁', const [_DT.purple, Color(0xFF7A4FD9)], 'Local Offers')),
              ]),
              const SizedBox(height: 18),
              Container(
                width: double.infinity, height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 18, offset: const Offset(0, 8))],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset('assets/images/home_header_photo_v3.jpg', fit: BoxFit.cover),
              ),
            ]),
          ),
        ),
      ]),
    ]);
  }

  Widget _premiumCard(String emoji, List<Color> gradient, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: _glassPanel(radius: 20),
      child: Column(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: gradient.last.withOpacity(0.45), blurRadius: 12, offset: const Offset(0, 5))],
          ),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
        ),
        const SizedBox(height: 10),
        Text(title, style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w800, color: _DT.ink)),
      ]),
    );
  }
}
