import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../services/services.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
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
    Timer(const Duration(milliseconds: 2600), _routeAfterSplash);
  }

  Future<void> _routeAfterSplash() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final isSubscribed = token.isNotEmpty
        ? await SubscriptionService().hasActiveSubscription()
        : false;
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      token.isEmpty
          ? AppRoutes.onboarding
          : isSubscribed
              ? AppRoutes.home
              : AppRoutes.payment,
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
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                  color: C.ink, borderRadius: BorderRadius.circular(28)),
              child: Center(
                  child: Text('EZ',
                      style: GoogleFonts.poppins(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: C.yellow,
                          letterSpacing: -1))),
            ),
          ),
          const SizedBox(height: 22),
          FadeTransition(
            opacity: _textFade,
            child: SlideTransition(
              position: _textSlide
                  .drive(Tween(begin: const Offset(0, 1), end: Offset.zero)),
              child: Column(children: [
                Text('ElderZha',
                    style: GoogleFonts.poppins(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: C.ink,
                        letterSpacing: -0.5)),
                const SizedBox(height: 4),
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
