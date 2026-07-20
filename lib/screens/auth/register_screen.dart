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
      _snack('Enter a valid 10-digit mobile number (digits only)');
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

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m, style: poppins(13)),
      backgroundColor: C.red,
      duration: const Duration(seconds: 2)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(children: [
        // Yellow header
        Container(
          width: double.infinity,
          color: C.yellow,
          child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome! 👋',
                          style:
                              poppins(13, w: FontWeight.w600, c: C.yellowDeep)),
                      const SizedBox(height: 4),
                      Text('Create your\naccount',
                          style: poppins(28,
                              w: FontWeight.w800, c: C.ink, h: 1.2)),
                    ]),
              )),
        ),
        // White slide-up body
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
                color: C.white,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28))),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    _lbl('Mobile Number'),
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                          color: C.bg2,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: C.bd, width: 1.5)),
                      child: Row(children: [
                        Padding(
                            padding: const EdgeInsets.only(left: 14),
                            child: Text('+91',
                                style:
                                    poppins(13, w: FontWeight.w600, c: C.ink))),
                        const SizedBox(width: 4),
                        Container(width: 1, height: 20, color: C.bd),
                        Expanded(
                            child: TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10)
                          ],
                          style: poppins(13, c: C.ink),
                          decoration: InputDecoration(
                            hintText: '10-digit mobile number',
                            hintStyle: poppins(13, c: C.txl),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            filled: false,
                          ),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 24),
                    _loading
                        ? const Center(
                            child: CircularProgressIndicator(color: C.ink))
                        : GestureDetector(
                            onTap: _send,
                            child: Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                  color: C.yellow,
                                  borderRadius: BorderRadius.circular(14)),
                              child: Center(
                                  child: Text('Send OTP →',
                                      style: poppins(14,
                                          w: FontWeight.w700, c: C.ink))),
                            ),
                          ),
                    const SizedBox(height: 14),
                    Center(
                        child: Text(
                            'We will send a 4-digit OTP to verify your number',
                            style: poppins(12, c: C.txl),
                            textAlign: TextAlign.center)),
                    const SizedBox(height: 20),
                    Center(
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: poppins(13, c: C.txl),
                          children: [
                            const TextSpan(text: 'Already registered? '),
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: () {
                                  // Same flow — OTP works for both new + returning users
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Enter your registered mobile number and we\'ll send an OTP to log you in.',
                                        style: poppins(12),
                                      ),
                                      backgroundColor: C.green,
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Login with same number',
                                  style: poppins(13, w: FontWeight.w700, c: C.yellowDeep),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _lbl(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(t, style: poppins(12, w: FontWeight.w700, c: C.txl)));
}
