import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Design tokens (exact from reference HTML CSS variables) ──────────────
class C {
  static const yellow = Color(0xFFFFCC01); // --y
  static const yellowDark = Color(0xFFD4A800); // --yd
  static const yellowDeep = Color(0xFF7A5800); // --yk
  static const yellowLight = Color(0xFFFFFDF0); // --ylt
  static const yellowMid = Color(0xFFFFF8CC); // --ylm
  static const yellowBorder = Color(0xFFF0DC60); // --ylb
  static const ink = Color(0xFF1A1726); // --ink
  static const txm = Color(0xFF4A4560); // --txm
  static const txl = Color(0xFF9491A8); // --txl
  static const bg = Color(0xFFFAFAF8); // --bg
  static const bg2 = Color(0xFFF4F3EE); // --bg2
  static const bg3 = Color(0xFFEEECEA); // --bg3
  static const white = Color(0xFFFFFFFF); // --wh
  static const bd = Color(0xFFE8E5DA); // --bd
  static const bd2 = Color(0xFFD4D0C4); // --bd2
  static const green = Color(0xFF22A85A); // --g
  static const greenLight = Color(0xFFE6F7EE); // --glt
  static const red = Color(0xFFE53935); // --r
  static const redLight = Color(0xFFFDECEA); // --rlt
  static const blue = Color(0xFF2979FF); // --b
  static const blueLight = Color(0xFFE8F0FF); // --blt
  static const purple = Color(0xFF7C4DFF); // --p
  static const purpleLight = Color(0xFFF0EBFF); // --plt
  static const orange = Color(0xFFFF6D00); // --or
  static const orangeLight = Color(0xFFFFF0E6); // --olt
}

class AppColors {
  static const yellow = C.yellow;
  static const yellowDark = C.yellowDark;
  static const yellowDeep = C.yellowDeep;
  static const yellowLight = C.yellowLight;
  static const yellowSoft = C.yellowMid;
  static const ink = C.ink;
  static const inkMuted = C.txm;
  static const inkLight = C.txl;
  static const bg = C.bg;
  static const bgCard = C.white;
  static const bgMuted = C.bg2;
  static const border = C.bd;
  static const borderStrong = C.bd2;
  static const green = C.green;
  static const greenLight = C.greenLight;
  static const red = C.red;
  static const redLight = C.redLight;
  static const blue = C.blue;
  static const blueLight = C.blueLight;
  static const purple = C.purple;
  static const purpleLight = C.purpleLight;
  static const orange = C.orange;
}

class AppTheme {
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: C.bg,
        fontFamily: GoogleFonts.poppins().fontFamily,
        colorScheme: ColorScheme.fromSeed(seedColor: C.yellow).copyWith(
          primary: C.yellow,
          onPrimary: C.ink,
          surface: C.bg,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: C.yellow,
          foregroundColor: C.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
          titleTextStyle: GoogleFonts.poppins(
              fontSize: 17, fontWeight: FontWeight.w700, color: C.ink),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: C.ink,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            minimumSize: const Size(double.infinity, 48),
            textStyle:
                GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: C.bg2,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: C.bd, width: 1.5)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: C.bd, width: 1.5)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: C.yellow, width: 2)),
          hintStyle: GoogleFonts.poppins(fontSize: 13, color: C.txl),
        ),
        cardTheme: CardThemeData(
          color: C.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: C.bd)),
        ),
      );
}

// ── Reusable helpers ─────────────────────────────────────────────────────
TextStyle poppins(double size,
        {FontWeight w = FontWeight.w400, Color c = C.ink, double h = 1.4}) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: h);

Widget pill(String label, Color bg, Color fg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: poppins(11, w: FontWeight.w700, c: fg)),
    );

// Yellow pill
Widget pillY(String label) => pill(label, C.yellowMid, C.yellowDeep);
// Green pill
Widget pillG(String label) =>
    pill(label, C.greenLight, const Color(0xFF145C30));
// Blue pill
Widget pillB(String label) => pill(label, C.blueLight, const Color(0xFF0D47A1));
// Red pill
Widget pillR(String label) => pill(label, C.redLight, const Color(0xFF7A1C1C));
// Purple pill
Widget pillP(String label) =>
    pill(label, C.purpleLight, const Color(0xFF3D007A));
// Orange pill
Widget pillO(String label) =>
    pill(label, C.orangeLight, const Color(0xFF7A3500));

// ── Input field styled like reference .inp ────────────────────────────────
Widget inpField(IconData icon, String hint,
        {TextEditingController? ctrl,
        TextInputType? type,
        bool readOnly = false,
        VoidCallback? onTap,
        String? prefixText}) =>
    Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        readOnly: readOnly,
        onTap: onTap,
        style: poppins(13, c: C.ink),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, size: 18, color: C.txl),
          prefixText: prefixText,
          prefixStyle: poppins(13, c: C.txl),
        ),
      ),
    );
