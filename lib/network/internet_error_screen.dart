import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class InternetErrorScreen extends StatelessWidget {
  const InternetErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.yellow,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off_rounded, size: 56, color: C.ink),
            ),
            const SizedBox(height: 24),
            Text('No Internet', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: C.ink)),
            const SizedBox(height: 8),
            Text('Check your internet connection\nand try again', style: GoogleFonts.poppins(fontSize: 14, color: C.yellowDeep, height: 1.5), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => (context as Element).markNeedsBuild(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(14)),
                child: Text('Retry', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: C.yellow)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
