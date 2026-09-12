// lib/screens/auth/signup_add_family_screen.dart
//
// New step inserted into the signup flow, after alarm setup and
// before payment. Explains why family data is being collected
// (it powers Events & Reminders, and the Family Tree feature) and
// lets the user add members right here, or skip for now and add
// them later from the Profile tab where this feature already
// lives permanently.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_routes.dart';
import '../profile/add_member_screen.dart';

class SignupAddFamilyScreen extends StatefulWidget {
  const SignupAddFamilyScreen({super.key});

  @override
  State<SignupAddFamilyScreen> createState() => _SignupAddFamilyScreenState();
}

class _SignupAddFamilyScreenState extends State<SignupAddFamilyScreen> {
  // Tracks members added during this session for display only —
  // AddMemberScreen already handles the actual save to the server.
  final List<String> _addedNames = [];

  void _continue() => Navigator.pushReplacementNamed(context, AppRoutes.payment);

  Future<void> _addMember() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddMemberScreen()),
    );
    if (result == true && mounted) {
      setState(() => _addedNames.add('Family member ${_addedNames.length + 1} added'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, top: 4),
              child: TextButton(
                onPressed: _continue,
                child: Text('Skip for now', style: poppins(14, w: FontWeight.w500, c: C.txl)),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                const SizedBox(height: 8),
                Container(
                  width: 88, height: 88,
                  decoration: const BoxDecoration(color: Color(0xFFFBEAF0), shape: BoxShape.circle),
                  child: const Center(child: Text('🌳', style: TextStyle(fontSize: 40))),
                ),
                const SizedBox(height: 20),
                Text('Add your family', textAlign: TextAlign.center,
                    style: poppins(22, w: FontWeight.w800, c: C.ink)),
                const SizedBox(height: 8),
                Text(
                  "We'll remind you of their birthdays, anniversaries, and important events — and build your Family Tree as you go.",
                  textAlign: TextAlign.center,
                  style: poppins(13.5, c: C.txm, h: 1.5),
                ),
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: _addMember,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: C.bd, width: 1.5),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.add_circle_rounded, color: C.yellowDark, size: 22),
                      const SizedBox(width: 8),
                      Text('Add a family member', style: poppins(14.5, w: FontWeight.w700, c: C.ink)),
                    ]),
                  ),
                ),
                if (_addedNames.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  ..._addedNames.map((label) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF3DE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF27500A)),
                          const SizedBox(width: 8),
                          Text(label, style: poppins(13, w: FontWeight.w600, c: const Color(0xFF27500A))),
                        ]),
                      )),
                ],
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: GestureDetector(
              onTap: _continue,
              child: Container(
                width: double.infinity, height: 52,
                decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(16)),
                child: Center(
                  child: Text(
                    _addedNames.isEmpty ? 'Continue' : 'Continue →',
                    style: poppins(15, w: FontWeight.w700, c: C.yellow),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
