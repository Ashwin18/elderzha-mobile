// lib/screens/onboarding/onboarding_screen.dart
//
// The swipe slides shown before login (Welcome → Stay Active & Connected →
// More Safety, More Possibilities).
//
// Oct 2026: restyled to match the rest of the app — the same yellow-to-
// off-white background, fonts and colours as every other screen — and made
// easier for older eyes: bigger type, bigger buttons, roomier cards, one
// clear message per page. Same public API (`OnboardingScreen`, no-arg
// constructor, AppRoutes.onboarding) and the same navigation: finish or
// skip → register.
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/app_routes.dart';

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
        duration: const Duration(milliseconds: 450),
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
    final last = _page == _pageCount - 1;
    return Scaffold(
      backgroundColor: C.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: C.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Logo on the left, a large easy-to-tap Skip on the right.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 8, 0),
                child: Row(children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 46,
                        errorBuilder: (_, __, ___) => Text('ElderZha',
                            style: poppins(22, w: FontWeight.w800)),
                      ),
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: last ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: TextButton(
                      onPressed: last ? null : _skip,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(72, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text('Skip',
                          style: poppins(16, w: FontWeight.w700, c: C.ink)),
                    ),
                  ),
                ]),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (v) => setState(() => _page = v),
                  children: const [
                    _WelcomePage(),
                    _ConnectedPage(),
                    _SafetyPage(),
                  ],
                ),
              ),
              _BottomBar(
                page: _page,
                pageCount: _pageCount,
                onNext: _next,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Page 1 — Welcome
// ─────────────────────────────────────────────────────────────────────────
class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final heroH = (box.maxHeight * .52).clamp(260.0, 420.0).toDouble();
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
        child: Column(
          children: [
            Text(
              "Life Doesn't Retire.",
              textAlign: TextAlign.center,
              style: poppins(19, w: FontWeight.w700, c: C.yellowDeep, h: 1.2)
                  .copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            // A tall "arch window" frame around the couple — soft, warm and
            // clearly the focus of the screen.
            Container(
              height: heroH,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(heroH),
                  topRight: Radius.circular(heroH),
                  bottomLeft: const Radius.circular(32),
                  bottomRight: const Radius.circular(32),
                ),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Color(0xFFFFF1BE)],
                ),
                border: Border.all(color: Colors.white, width: 5),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x26B58300),
                      blurRadius: 28,
                      offset: Offset(0, 12)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/images/elderzha_couple.png',
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
              ),
            ),
            const SizedBox(height: 22),
            Text('Welcome to ElderZha!',
                textAlign: TextAlign.center, style: _headline),
            const SizedBox(height: 10),
            Text(
              'Your everyday companion for a happier, healthier and more connected life.',
              textAlign: TextAlign.center,
              style: _body,
            ),
          ],
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Page 2 — Stay Active, Stay Connected
// ─────────────────────────────────────────────────────────────────────────
class _ConnectedPage extends StatelessWidget {
  const _ConnectedPage();

  // (icon, colour, title, subtitle)
  static const _items = [
    (Icons.alarm_rounded, Color(0xFFF59E0B), 'Alarm', 'Meal & medicine, on time.'),
    (Icons.calendar_month_rounded, Color(0xFF8B5CF6), 'Reminder', 'Never miss special days & appointments.'),
    (Icons.track_changes_rounded, Color(0xFFEC4899), 'Daily Engagement', 'Move, think, play & enjoy.'),
    (Icons.menu_book_rounded, Color(0xFFF97316), 'Daily Diary', 'Thoughts, feelings and memories.'),
    (Icons.photo_camera_rounded, Color(0xFF3B82F6), 'Memories', 'Revisit moments that matter.'),
    (Icons.directions_walk_rounded, Color(0xFF087A54), 'Walking & Steps', 'Stay active and healthy.'),
    (Icons.park_rounded, Color(0xFF7C4DDB), 'Family Tree', 'Keep loved ones close.'),
    (Icons.notifications_active_rounded, Color(0xFFE0435D), 'Notifications', 'Important updates in one place.'),
  ];

  @override
  Widget build(BuildContext context) {
    // Everything fits on one screen: the content is laid out at the page
    // width and, if a small phone is short on height, scaled down to fit
    // instead of scrolling.
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth - 40;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stay Active,\nStay Connected', style: _headline),
                const SizedBox(height: 8),
                Text(
                  'From daily reminders to fun activities, ElderZha keeps you engaged every day.',
                  style: poppins(15, w: FontWeight.w500, c: C.txm, h: 1.4),
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < _items.length; i += 2)
                  Padding(
                    padding: EdgeInsets.only(bottom: i == _items.length - 2 ? 0 : 10),
                    child: IntrinsicHeight(
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _FeatureCard(_items[i])),
                            const SizedBox(width: 10),
                            Expanded(child: _FeatureCard(_items[i + 1])),
                          ]),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard(this.item);
  final (IconData, Color, String, String) item;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        decoration: _card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.$2,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                        color: item.$2.withOpacity(.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: Icon(item.$1, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(item.$3,
                    style: poppins(13.5, w: FontWeight.w800, c: C.ink, h: 1.15)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(item.$4, style: poppins(12, c: C.txm, h: 1.3)),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────
//  Page 3 — More Safety, More Possibilities
// ─────────────────────────────────────────────────────────────────────────
class _SafetyPage extends StatelessWidget {
  const _SafetyPage();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('More Safety.\nMore Possibilities.', style: _headline),
          const SizedBox(height: 10),
          Text(
            'Get peace of mind with Fall Detection and discover local offers — both included with your sign up!',
            style: _body,
          ),
          const SizedBox(height: 18),
          const _PremiumCard(
            Icons.health_and_safety_rounded,
            Color(0xFF087A54),
            'Fall Detection',
            'Get help, when you need it most.',
          ),
          const SizedBox(height: 12),
          const _PremiumCard(
            Icons.card_giftcard_rounded,
            Color(0xFF7C4DDB),
            'Local Offers',
            'Exclusive deals & offers near you.',
          ),
          SizedBox(
            height: 250,
            child: Stack(alignment: Alignment.bottomCenter, children: [
              Positioned(
                right: 8,
                top: 24,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: C.yellow,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: C.yellowDark.withOpacity(.4),
                          blurRadius: 14,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: const Icon(Icons.local_offer_rounded,
                      color: C.ink, size: 30),
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

class _PremiumCard extends StatelessWidget {
  const _PremiumCard(this.icon, this.color, this.title, this.description);
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: _card(),
        child: Row(children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(.35),
                    blurRadius: 12,
                    offset: const Offset(0, 5)),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: poppins(17, w: FontWeight.w800, c: C.ink, h: 1.2)),
                const SizedBox(height: 4),
                Text(description, style: poppins(13.5, c: C.txm, h: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: C.ink,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Premium',
                style: poppins(11.5, w: FontWeight.w800, c: C.yellow, h: 1.1)),
          ),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────
//  Bottom bar: progress dots + one big, clear button
// ─────────────────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.page,
    required this.pageCount,
    required this.onNext,
  });
  final int page;
  final int pageCount;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final last = page == pageCount - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14000000), blurRadius: 20, offset: Offset(0, -6)),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            pageCount,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == page ? 30 : 10,
              height: 10,
              decoration: BoxDecoration(
                color: i == page ? C.ink : C.ink.withOpacity(.18),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Material(
          color: C.yellow,
          borderRadius: BorderRadius.circular(20),
          elevation: 3,
          shadowColor: C.yellowDark.withOpacity(.5),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onNext,
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(last ? 'Get Started' : 'Next',
                    style: poppins(18, w: FontWeight.w800, c: C.ink)),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_rounded, color: C.ink, size: 26),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── shared styles ───────────────────────────────────────────────────────
TextStyle get _headline =>
    poppins(30, w: FontWeight.w800, c: C.ink, h: 1.15).copyWith(letterSpacing: -.5);

TextStyle get _body => poppins(16.5, w: FontWeight.w500, c: C.txm, h: 1.5);

BoxDecoration _card() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: C.yellowBorder.withOpacity(.7)),
      boxShadow: const [
        BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6)),
      ],
    );
