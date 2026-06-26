import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  final _pages = const [
    _Page('💊', 'Never miss a dose', 'Smart medication reminders timed perfectly around your meals — morning, afternoon, and night.', Color(0xFFFFCC01)),
    _Page('📅', 'Stay on top of your day', 'Track birthdays, anniversaries, doctor appointments and family events all in one place.', Color(0xFFFFF8CC)),
    _Page('🌿', 'Your wellness, your story', 'Log your mood, meals, and activities daily. See your health journey unfold month by month.', Color(0xFFE6F7EE)),
  ];

  void _next() {
    if (_page < 2) {
      _ctrl.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeInOut);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.register);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pages[_page].bg,
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.topRight,
            child: TextButton(
              onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.register),
              child: Text('Skip', style: poppins(14, w: FontWeight.w500, c: C.txl)),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _ctrl,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: 3,
              itemBuilder: (_, i) => _PageView(page: _pages[i]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(children: [
              SmoothPageIndicator(
                controller: _ctrl, count: 3,
                effect: ExpandingDotsEffect(
                  activeDotColor: C.ink, dotColor: C.ink.withOpacity(0.2),
                  dotHeight: 8, dotWidth: 8, expansionFactor: 3,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _next,
                child: Container(
                  width: double.infinity, height: 50,
                  decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(14)),
                  child: Center(child: Text(_page < 2 ? 'Next →' : 'Get started', style: poppins(14, w: FontWeight.w700, c: Colors.white))),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _PageView extends StatelessWidget {
  final _Page page;
  const _PageView({required this.page});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 130, height: 130,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), shape: BoxShape.circle),
        child: Center(child: Text(page.emoji, style: const TextStyle(fontSize: 60))),
      ),
      const SizedBox(height: 36),
      Text(page.title, textAlign: TextAlign.center, style: poppins(24, w: FontWeight.w700, c: C.ink, h: 1.25)),
      const SizedBox(height: 14),
      Text(page.subtitle, textAlign: TextAlign.center, style: poppins(14, c: C.txm, h: 1.6)),
    ]),
  );
}

class _Page {
  final String emoji, title, subtitle;
  final Color bg;
  const _Page(this.emoji, this.title, this.subtitle, this.bg);
}
