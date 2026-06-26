import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _dobCtrl;
  String _gender = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _nameCtrl = TextEditingController(
        text: auth.userName == 'User' ? '' : auth.userName);
    _emailCtrl = TextEditingController(text: auth.userEmail);
    _dobCtrl = TextEditingController(text: auth.userDob);
    _gender = auth.userGender;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack('Name cannot be empty');
      return;
    }
    setState(() => _saving = true);
    // ── POST /user/profile/update ──────────────────────────
    final res = await context.read<AuthProvider>().updateProfile(
          name: _nameCtrl.text.trim(),
          phone: context.read<AuthProvider>().userPhone,
          email:
              _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
          dob: _dobCtrl.text.trim().isNotEmpty ? _dobCtrl.text.trim() : null,
          gender: _gender.isNotEmpty ? _gender : null,
        );
    setState(() => _saving = false);
    if (!mounted) return;
    if (res['status'] == true || res['data'] != null) {
      _snack('Profile updated! ✅', ok: true);
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.pop(context);
    } else {
      _snack(res['message'] ?? 'Update failed. Try again.');
    }
  }

  void _snack(String msg, {bool ok = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: poppins(13)),
      backgroundColor: ok ? C.green : C.red,
      duration: const Duration(seconds: 2),
    ));
  }

  Widget _gChip(String val, String emoji, String label) {
    final sel = _gender == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gender = val),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? C.yellowLight : C.white,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: sel ? C.yellow : C.bd, width: sel ? 2 : 1.5),
          ),
          child: Column(children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 3),
            Text(label,
                style: poppins(10,
                    w: FontWeight.w700, c: sel ? C.yellowDeep : C.txm)),
          ]),
        ),
      ),
    );
  }

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
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: C.ink),
                  ),
                  const SizedBox(width: 10),
                  Text('Edit profile',
                      style: poppins(18, w: FontWeight.w700, c: C.ink)),
                ]),
              )),
        ),
        // White slide-up body
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: C.white,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28), topRight: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar picker
                    Center(
                      child: GestureDetector(
                        onTap: () => _snack('Photo upload coming soon'),
                        child: Column(children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: C.yellowMid,
                              shape: BoxShape.circle,
                              border: Border.all(color: C.yellow, width: 3),
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                size: 30, color: C.yellowDark),
                          ),
                          const SizedBox(height: 6),
                          Text('Tap to change photo',
                              style: poppins(11, c: C.txl)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _lbl('Full Name'),
                    _inp(Icons.person_outline_rounded, 'e.g. Suresh Kumar',
                        ctrl: _nameCtrl, active: true),

                    _lbl('Mobile Number'),
                    Consumer<AuthProvider>(
                      builder: (_, auth, __) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                            color: C.bg2,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: C.bd)),
                        child: Row(children: [
                          const Icon(Icons.phone_outlined,
                              size: 18, color: C.txl),
                          const SizedBox(width: 10),
                          Text('+91 ${auth.userPhone}',
                              style: poppins(13, c: C.txl)),
                          const Spacer(),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: C.bg3,
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text('Cannot change',
                                  style: poppins(10, c: C.txl))),
                        ]),
                      ),
                    ),

                    _lbl('Email Address'),
                    _inp(Icons.email_outlined, 'your@email.com',
                        ctrl: _emailCtrl, type: TextInputType.emailAddress),

                    _lbl('Date of Birth'),
                    GestureDetector(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: DateTime(1960),
                          firstDate: DateTime(1930),
                          lastDate: DateTime.now()
                              .subtract(const Duration(days: 365 * 18)),
                          builder: (ctx, child) => Theme(
                            data: ThemeData.light().copyWith(
                                colorScheme: const ColorScheme.light(
                                    primary: C.yellowDark)),
                            child: child!,
                          ),
                        );
                        if (d != null)
                          setState(() => _dobCtrl.text =
                              '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}');
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                            color: C.bg2,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: C.bd)),
                        child: Row(children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 18, color: C.txl),
                          const SizedBox(width: 10),
                          Text(
                              _dobCtrl.text.isNotEmpty
                                  ? _dobCtrl.text
                                  : 'Select date of birth',
                              style: poppins(13,
                                  c: _dobCtrl.text.isNotEmpty ? C.ink : C.txl)),
                        ]),
                      ),
                    ),

                    _lbl('Gender'),
                    Row(children: [
                      _gChip('male', '👨', 'Male'),
                      const SizedBox(width: 8),
                      _gChip('female', '👩', 'Female'),
                      const SizedBox(width: 8),
                      _gChip('other', '🧑', 'Other'),
                    ]),

                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: _saving ? null : _save,
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                            color: C.yellow,
                            borderRadius: BorderRadius.circular(14)),
                        child: Center(
                            child: _saving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        color: C.ink, strokeWidth: 2))
                                : Text('Save changes',
                                    style: poppins(14,
                                        w: FontWeight.w700, c: C.ink))),
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
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(t, style: poppins(12, w: FontWeight.w700, c: C.txl)),
      );

  Widget _inp(IconData icon, String hint,
      {TextEditingController? ctrl, TextInputType? type, bool active = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        style: poppins(13, c: C.ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: poppins(13, c: C.txl),
          prefixIcon:
              Icon(icon, size: 18, color: active ? C.yellowDark : C.txl),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: active ? C.yellow : C.bd, width: active ? 2 : 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: C.yellow, width: 2),
          ),
        ),
      ),
    );
  }
}
