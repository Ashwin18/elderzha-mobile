import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../services/services.dart';
import '../../utils/join_date_helper.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_routes.dart';
import '../auth/benefits_showcase_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  bool _checking = false; // Fix 11: show spinner during API check
  late AnimationController _logoCtrl, _textCtrl;
  late Animation<double> _logoScale, _textFade, _textSlide;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _logoScale = Tween(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _textFade = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _textSlide = Tween(begin: 0.25, end: 0.0)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _logoCtrl.forward();
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) _textCtrl.forward();
    });
    Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _checking = true);
      _routeAfterSplash();
    });
  }

  Future<void> _routeAfterSplash() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    // No token → new user → onboarding
    if (token.isEmpty) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
      return;
    }

    // Has token — fetch full user status once, up front, so we can
    // correctly resume wherever this user actually left off, the
    // same way otp_screen.dart already does right after
    // verification. Previously this screen only ever checked
    // subscription status and picked Home vs SubscriptionGate —
    // meaning a user who registered but never finished profile or
    // alarm setup got sent straight to SubscriptionGate (or got
    // stuck if that screen then failed to load plans for an
    // incomplete account), skipping required steps entirely.
    Map<String, dynamic>? userRes;
    bool fetchFailed = false;
    try {
      userRes = await AuthService().getUserDetails().timeout(
            const Duration(seconds: 10),
            onTimeout: () => null,
          );
      if (userRes == null) fetchFailed = true;
    } catch (_) {
      fetchFailed = true;
    }
    if (!mounted) return;

    // API unreachable/timed out — fall back to local cache rather
    // than defaulting every flag to false, which would wrongly send
    // an already fully-set-up, actively-paying user back through
    // setup just because of a temporary network hiccup (this was
    // the original code's safety net for the same reason).
    if (fetchFailed) {
      final cachedActive = prefs.getBool('subscription_active_local') == true;
      Navigator.pushReplacementNamed(
        context,
        cachedActive ? AppRoutes.home : AppRoutes.subscriptionGate,
      );
      return;
    }

    // Flags may sit at different nesting depths depending on which
    // endpoint returned them — check top-level first, then the
    // common nested shapes, same fallback spirit as _extractUser
    // elsewhere in the auth flow.
    final nested = userRes?['data'];
    dynamic mergedFlags = {
      ...(userRes is Map ? userRes : {}),
      ...(nested is Map ? nested : {}),
      ...(nested is Map && nested['user'] is Map ? nested['user'] as Map : {}),
    };
    bool truthy(dynamic value) {
      if (value == true) return true;
      if (value is num) return value != 0;
      final text = value?.toString().toLowerCase().trim();
      return text == '1' || text == 'true' || text == 'yes' ||
          text == 'completed' || text == 'approved' || text == 'active';
    }

    final isProfileUpdated = truthy(mergedFlags['is_profile_updated'] ?? mergedFlags['isProfileUpdate']);
    final isAlarmSet = truthy(mergedFlags['daily_alarm_set']);
    final isPlanActiveFlag = truthy(mergedFlags['is_plan_active']);

    // Active plan → Home directly, regardless of anything else,
    // matching otp_screen.dart's exact priority order.
    if (isPlanActiveFlag) {
      try {
        final createdAt = mergedFlags['created_at']?.toString() ?? '';
        if (createdAt.isNotEmpty) await JoinDateHelper.saveJoinDate(createdAt);
      } catch (_) {}
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.home);
      return;
    }

    // Existing user, profile+alarm already done, plan just expired
    // → renewal screen (SubscriptionGate), not the new-user setup
    // steps or the "Welcome" framing meant for first-time signup.
    if (isProfileUpdated && isAlarmSet) {
      Navigator.pushReplacementNamed(context, AppRoutes.subscriptionGate);
      return;
    }

    // Still mid-registration — resume at whichever step was never
    // finished, exactly like otp_screen.dart does.
    if (!isProfileUpdated) {
      Navigator.pushReplacementNamed(context, AppRoutes.setupProfile);
      return;
    }
    if (!isAlarmSet) {
      Navigator.pushReplacementNamed(context, AppRoutes.alarmSetup);
      return;
    }

    // Profile + alarm done, never reached/completed payment.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const BenefitsShowcaseScreen()),
    );
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.yellow,
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          ScaleTransition(
            scale: _logoScale,
            child: Image.asset(
              'assets/images/logo.png',
              width: 220,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 18),
          FadeTransition(
            opacity: _textFade,
            child: SlideTransition(
              position: _textSlide
                  .drive(Tween(begin: const Offset(0, 1), end: Offset.zero)),
              child: Column(children: [
                Text('Your daily wellness companion',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: C.yellowDeep)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
