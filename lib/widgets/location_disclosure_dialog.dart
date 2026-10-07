// lib/widgets/location_disclosure_dialog.dart
//
// Shown before the OS location-permission prompt ever appears, so the
// user always sees a clear, specific explanation first rather than just
// the generic system dialog. Location is only ever read while a Fall
// Detection / SOS screen is on-screen (never in the background), so this
// only needs "While using the app" permission.
//
// This dialog is shown right before any call that can trigger the
// Android location-permission prompt for the Fall Detection / SOS
// feature (see fall_settings_screen.dart and fall_alert_screen.dart).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Shows the prominent in-app location disclosure.
/// Returns true if the user tapped "Allow & Continue", false otherwise.
Future<bool> showLocationDisclosureDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.location_on_rounded,
              color: Color(0xFF2E7D32), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text('Location for Fall Detection & SOS',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w700, color: C.ink)),
        ),
      ]),
      content: Text(
        'ElderZha accesses your device location only to power the Fall '
        'Detection and SOS safety feature, while the SOS screen is open '
        'on your device.\n\n'
        'When a fall is detected or an SOS alert is sent, your current '
        'location is shared with your registered SOS contact and admin '
        'so they can find and help you quickly.\n\n'
        'Your location is never accessed for any other purpose, and is '
        'never sold, shared for advertising, or used for profiling.',
        style: GoogleFonts.poppins(fontSize: 13, color: C.txm, height: 1.5),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Not Now',
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600, color: C.txl)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('Allow & Continue',
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ],
    ),
  );
  return result ?? false;
}
