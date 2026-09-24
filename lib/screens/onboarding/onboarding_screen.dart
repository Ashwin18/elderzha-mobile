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
                fontSize: 35,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Life Doesn't Retire.",
              style: TextStyle(
                color: _OnboardColors.ink,
                fontSize: 17,
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

  // (icon, badge color, title, subtitle) — 8 features, 2 per row,
  // matching the client-provided reference layout.
  static const _items = [
    (Icons.alarm_rounded, _OnboardColors.gold, 'Alarm', 'Meal & Medicine,\non time.'),
    (Icons.calendar_month_rounded, Color(0xFF8B5CF6), 'Reminder', 'Never miss the special\ndays & appointments.'),
    (Icons.track_changes_rounded, Color(0xFFEC4899), 'Daily Engagement', 'Move, think, play\n& enjoy.'),
    (Icons.menu_book_rounded, Color(0xFFF97316), 'Daily Diary', 'Thoughts, feelings,\nmemories and moments.'),
    (Icons.photo_camera_rounded, Color(0xFF3B82F6), 'Memories', 'Revisit moments\nthat matter.'),
    (Icons.directions_walk_rounded, _OnboardColors.green, 'Walking & Steps', 'Stay active,\nhealthier and happier.'),
    (Icons.park_rounded, Color(0xFF8255D9), 'Family Tree', 'Keep your loved ones\nclose. Birthdays & more.'),
    (Icons.notifications_active_rounded, Color(0xFFE0435D), 'Notifications', 'Important updates,\nall in one place.'),
  ];

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
          for (var i = 0; i < _items.length; i += 2)
            Padding(
              padding: EdgeInsets.only(bottom: i + 2 < _items.length ? 10 : 0),
              child: Row(children: [
                Expanded(
                  child: _GridFeature(
                    icon: _items[i].$1,
                    color: _items[i].$2,
                    title: _items[i].$3,
                    subtitle: _items[i].$4,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _GridFeature(
                    icon: _items[i + 1].$1,
                    color: _items[i + 1].$2,
                    title: _items[i + 1].$3,
                    subtitle: _items[i + 1].$4,
                  ),
                ),
              ]),
            ),
          const SizedBox(height: 14),
          const Center(
            child: Text(
              'Small steps today, a bigger happier tomorrow',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _OnboardColors.ink,
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridFeature extends StatelessWidget {
  const _GridFeature({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
        height: 78,
        padding: const EdgeInsets.all(10),
        decoration: _card(),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _OnboardColors.ink,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _OnboardColors.ink,
                    fontSize: 9,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(color: _OnboardColors.cream3, shape: BoxShape.circle),
            child: const Icon(Icons.chevron_right_rounded, size: 13, color: _OnboardColors.ink),
          ),
        ]),
      );
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
          fontSize: 27,
          height: 1.12,
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
          fontSize: 14.5,
          height: 1.4,
          fontWeight: FontWeight.w500,
        ),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: _OnboardColors.ink,
                    fontSize: 11.5,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
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
