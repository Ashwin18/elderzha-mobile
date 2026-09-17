// lib/screens/onboarding/onboarding_screen.dart
//
// Intro/onboarding flow replaced (Sep 2026) with the client-provided
// ElderZha_Intro_Flutter design: a cleaner three-page native-widget
// flow (Welcome → Stay Active & Connected → More Safety, More
// Possibilities) using the app's real gold/navy/cream palette and
// three character illustrations. Keeps the same public API as the
// screen it replaces (`OnboardingScreen`, no-arg constructor,
// registered at AppRoutes.onboarding) so main.dart needs no changes,
// and preserves the existing "finish → register" and "skip →
// register" navigation behavior.
import 'package:flutter/material.dart';
import '../../utils/app_routes.dart';

abstract final class _OnboardColors {
  static const gold = Color(0xFFFFB800);
  static const ink = Color(0xFF1A1726);
  static const cream1 = Color(0xFFFFFBEA);
  static const cream2 = Color(0xFFFFF3C4);
  static const cream3 = Color(0xFFFFE9A0);
  static const green = Color(0xFF087A54);
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;
  static const _pageCount = 3;

  Future<void> _next() async {
    if (_page < _pageCount - 1) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } else if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.register);
    }
  }

  void _skip() => Navigator.pushReplacementNamed(context, AppRoutes.register);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _OnboardColors.cream1,
              _OnboardColors.cream2,
              _OnboardColors.cream3,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16, top: 4),
                  child: TextButton(
                    onPressed: _skip,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: _OnboardColors.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (value) => setState(() => _page = value),
                  children: const [
                    _WelcomePage(),
                    _ConnectedPage(),
                    _SafetyPage(),
                  ],
                ),
              ),
              _Pager(page: _page, pageCount: _pageCount, onNext: _next),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 6),
        child: Column(
          children: [
            const Text(
              'ELDERZHA',
              style: TextStyle(
                color: _OnboardColors.ink,
                fontSize: 41,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Life Doesn't Retire.",
              style: TextStyle(
                color: _OnboardColors.ink,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              height: (box.maxHeight * .51).clamp(300, 420).toDouble(),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Colors.white.withOpacity(.88),
                  Colors.white.withOpacity(.12),
                ]),
              ),
              child: Image.asset(
                'assets/images/elderzha_couple.png',
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
              ),
            ),
            const SizedBox(height: 10),
            const _Heading('Welcome to Elderzha!', centered: true),
            const SizedBox(height: 10),
            const _Copy(
              'Your everyday companion for a happier, healthier\nand more connected life.',
              centered: true,
            ),
          ],
        ),
      );
    });
  }
}

class _ConnectedPage extends StatelessWidget {
  const _ConnectedPage();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Heading('Stay Active,\nStay Connected'),
          const SizedBox(height: 10),
          const _Copy(
            'From daily reminders to fun activities, Elderzha keeps you engaged every day.',
          ),
          const SizedBox(height: 16),
          const Row(children: [
            Expanded(
              child: _Feature(
                Icons.notifications_rounded,
                'Reminders\n& Alarms',
                _OnboardColors.gold,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _Feature(
                Icons.psychology_alt_rounded,
                'Activities\n& Polls',
                Color(0xFF8B5CF6),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          const Row(children: [
            Expanded(
              child: _Feature(
                Icons.groups_rounded,
                'Community',
                Color(0xFFEC4899),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _Feature(
                Icons.directions_walk_rounded,
                'Walking',
                Color(0xFF45A85E),
              ),
            ),
          ]),
          SizedBox(
            height: 230,
            width: double.infinity,
            child: Image.asset(
              'assets/images/elderzha_woman_phone.png',
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
            ),
          ),
          const _Reminder(),
        ],
      ),
    );
  }
}

class _SafetyPage extends StatelessWidget {
  const _SafetyPage();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Heading('More Safety.\nMore Possibilities.'),
          const SizedBox(height: 10),
          const _Copy(
            'Get peace of mind with Fall Detection and discover local offers — both included with your sign up!',
          ),
          const SizedBox(height: 16),
          const _Premium(
            Icons.health_and_safety_rounded,
            _OnboardColors.green,
            'Fall Detection',
            'Get help, when you need it most.',
          ),
          const SizedBox(height: 12),
          const _Premium(
            Icons.card_giftcard_rounded,
            Color(0xFF8255D9),
            'Local Offers',
            'Exclusive deals & offers near you.',
          ),
          SizedBox(
            height: 250,
            child: Stack(alignment: Alignment.bottomCenter, children: [
              Positioned(
                right: 6,
                top: 26,
                child: _CircleIcon(
                  Icons.local_offer_rounded,
                  _OnboardColors.gold,
                  size: 56,
                ),
              ),
              Image.asset(
                'assets/images/elderzha_man_phone.png',
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.centered = false});
  final String text;
  final bool centered;
  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: centered ? TextAlign.center : TextAlign.left,
        style: const TextStyle(
          color: _OnboardColors.ink,
          fontSize: 32,
          height: 1.08,
          fontWeight: FontWeight.w900,
          letterSpacing: -.6,
        ),
      );
}

class _Copy extends StatelessWidget {
  const _Copy(this.text, {this.centered = false});
  final String text;
  final bool centered;
  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: centered ? TextAlign.center : TextAlign.left,
        style: const TextStyle(
          color: _OnboardColors.ink,
          fontSize: 16.5,
          height: 1.4,
          fontWeight: FontWeight.w500,
        ),
      );
}

class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        height: 124,
        padding: const EdgeInsets.all(10),
        decoration: _card(),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          _CircleIcon(icon, color),
          const SizedBox(height: 7),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _OnboardColors.ink,
              fontSize: 15,
              height: 1.08,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]),
      );
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon(this.icon, this.color, {this.size = 52});
  final IconData icon;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: size * .55),
      );
}

class _Reminder extends StatelessWidget {
  const _Reminder();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
        decoration: _card(),
        child: const Row(children: [
          Icon(Icons.calendar_month_rounded, color: _OnboardColors.gold, size: 39),
          SizedBox(width: 13),
          Expanded(
            child: Text(
              'Never miss what matters.',
              style: TextStyle(
                color: _OnboardColors.ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ]),
      );
}

class _Premium extends StatelessWidget {
  const _Premium(this.icon, this.color, this.title, this.description);
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: _card(),
        child: Row(children: [
          _CircleIcon(icon, color, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _OnboardColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: _OnboardColors.ink,
                    fontSize: 12.5,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: _OnboardColors.gold,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Premium',
                style: TextStyle(
                  color: _OnboardColors.ink,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 9),
            Container(
              width: 63,
              height: 30,
              padding: const EdgeInsets.only(left: 9, right: 3),
              decoration: BoxDecoration(
                color: _OnboardColors.green,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ON',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  CircleAvatar(radius: 12, backgroundColor: Colors.white),
                ],
              ),
            ),
          ]),
        ]),
      );
}

class _Pager extends StatelessWidget {
  const _Pager({required this.page, required this.pageCount, required this.onNext});
  final int page;
  final int pageCount;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 7, 18, 14),
        child: SizedBox(
          height: 60,
          child: Stack(alignment: Alignment.center, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pageCount,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == page ? 24 : 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: i == page
                        ? _OnboardColors.gold
                        : _OnboardColors.ink.withOpacity(.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: _OnboardColors.gold,
                shape: const CircleBorder(),
                elevation: 5,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onNext,
                  child: const SizedBox(
                    width: 58,
                    height: 58,
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: _OnboardColors.ink,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
}

BoxDecoration _card() => BoxDecoration(
      color: Colors.white.withOpacity(.80),
      borderRadius: BorderRadius.circular(21),
      border: Border.all(color: Colors.white.withOpacity(.92)),
      boxShadow: const [
        BoxShadow(color: Color(0x16000000), blurRadius: 17, offset: Offset(0, 7)),
      ],
    );
