import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_routes.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _phoneCtrl = TextEditingController();
  bool _loading = false;

  void _send() async {
    final phone = _phoneCtrl.text.trim();
    if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
      _snack('Please enter a valid 10-digit mobile number');
      return;
    }
    setState(() => _loading = true);
    final ok = await context.read<AuthProvider>().phoneLogin(phone);
    setState(() => _loading = false);
    if (!mounted) return;
    if (ok) {
      Navigator.pushNamed(context, AppRoutes.otp, arguments: {'phone': phone});
    } else {
      _snack(context.read<AuthProvider>().error ?? 'Failed to send OTP');
    }
  }

  void _snack(String m, {bool ok = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(m, style: GoogleFonts.poppins(fontSize: 15)),
          backgroundColor: ok ? C.green : C.red,
          duration: const Duration(seconds: 3)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(children: [

        // ── Yellow header ──────────────────────────────────────────
        Container(
          width: double.infinity,
          color: C.yellow,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo mark
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                        color: C.ink,
                        borderRadius: BorderRadius.circular(16)),
                    child: Center(
                      child: Text('EZ',
                          style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: C.yellow,
                              letterSpacing: -1)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Welcome!',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: C.yellowDeep)),
                  const SizedBox(height: 4),
                  Text('Enter your\nmobile number',
                      style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: C.ink,
                          height: 1.15)),
                ],
              ),
            ),
          ),
        ),

        // ── White body ─────────────────────────────────────────────
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
                color: C.white,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32))),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Label ───────────────────────────────────────
                  Text('Mobile number',
                      style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: C.ink)),
                  const SizedBox(height: 10),

                  // ── Phone input — BIG ────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                        color: C.bg2,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: C.yellow, width: 2.5)),
                    child: Row(children: [
                      // Country code
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 18),
                        decoration: BoxDecoration(
                          border: Border(
                              right: BorderSide(color: C.bd, width: 1.5)),
                        ),
                        child: Text('+91',
                            style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: C.ink)),
                      ),
                      // Number field
                      Expanded(
                        child: TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: C.ink,
                              letterSpacing: 2),
                          decoration: InputDecoration(
                            hintText: '98XXXXXXXX',
                            hintStyle: GoogleFonts.poppins(
                                fontSize: 20,
                                color: C.txl,
                                letterSpacing: 1),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 18),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 12),

                  // ── Helper text ─────────────────────────────────
                  Row(children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 18, color: Color(0xFF888680)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "We'll send a 4-digit code to this number",
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: const Color(0xFF888680),
                            height: 1.4),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 32),

                  // ── Send OTP button — BIG ────────────────────────
                  _loading
                      ? const Center(
                          child: SizedBox(
                              width: 32,
                              height: 32,
                              child:
                                  CircularProgressIndicator(color: C.ink)))
                      : GestureDetector(
                          onTap: _send,
                          child: Container(
                            width: double.infinity,
                            height: 60,
                            decoration: BoxDecoration(
                                color: C.ink,
                                borderRadius: BorderRadius.circular(16)),
                            child: Center(
                              child: Text('Send OTP  →',
                                  style: GoogleFonts.poppins(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w700,
                                      color: C.yellow)),
                            ),
                          ),
                        ),

                  const SizedBox(height: 28),

                  // ── Divider ──────────────────────────────────────
                  Row(children: [
                    Expanded(child: Divider(color: C.bd, thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text('or',
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: C.txl)),
                    ),
                    Expanded(child: Divider(color: C.bd, thickness: 1)),
                  ]),

                  const SizedBox(height: 20),

                  // ── Returning user ───────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: C.bg2,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: C.bd),
                    ),
                    child: Column(children: [
                      const Icon(Icons.phone_android_rounded,
                          size: 28, color: Color(0xFF888680)),
                      const SizedBox(height: 8),
                      Text('Already registered?',
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: C.ink)),
                      const SizedBox(height: 4),
                      Text(
                        'Enter your same number above.\nWe will send an OTP to log you in.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: C.txl,
                            height: 1.5),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
