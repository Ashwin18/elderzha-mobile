import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_routes.dart';

class SetupProfileScreen extends StatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _picker = ImagePicker();

  String _phone = '';
  String _gender = '';
  File? _photo;
  bool _saving = false;
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _phone = args['phone']?.toString() ?? '';
      _nameCtrl.text = args['name']?.toString() ?? '';
      _gender = args['gender']?.toString() ?? '';
    }
    _seeded = true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dobCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file != null) setState(() => _photo = File(file.path));
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 60, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: C.yellowDark),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _dobCtrl.text =
          '${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}';
    });
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _dobCtrl.text.trim().isEmpty ||
        _gender.isEmpty) {
      _snack('Please complete name, DOB, and gender');
      return;
    }

    setState(() => _saving = true);
    final res = await context.read<AuthProvider>().updateProfile(
          name: _nameCtrl.text.trim(),
          phone: _phone,
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          dob: _dobCtrl.text.trim(),
          gender: _gender,
          photo: _photo,
          submitForAdmin: true,
        );
    setState(() => _saving = false);
    if (!mounted) return;

    if (res['status'] == true || res['data'] != null) {
      Navigator.pushReplacementNamed(context, AppRoutes.alarmSetup);
    } else {
      _snack(res['message'] ?? 'Could not submit profile');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: poppins(13)),
        backgroundColor: C.red,
      ),
    );
  }

  Widget _genderChip(String value, String emoji, String label) {
    final selected = _gender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gender = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? C.yellowLight : C.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? C.yellow : C.bd,
              width: selected ? 2 : 1.5,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 4),
              Text(
                label,
                style: poppins(
                  11,
                  w: FontWeight.w700,
                  c: selected ? C.yellowDeep : C.txm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(
        children: [
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
                    Text(
                      'Profile review',
                      style: poppins(13, w: FontWeight.w600, c: C.yellowDeep),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create your\nwellness profile',
                      style: poppins(26, w: FontWeight.w800, c: C.ink, h: 1.2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: C.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _pickPhoto,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 46,
                              backgroundColor: C.yellowMid,
                              backgroundImage:
                                  _photo == null ? null : FileImage(_photo!),
                              child: _photo == null
                                  ? const Icon(
                                      Icons.person_rounded,
                                      size: 42,
                                      color: C.yellowDark,
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: const BoxDecoration(
                                  color: C.ink,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 15,
                                  color: C.yellow,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _label('Full name'),
                    inpField(
                      Icons.person_outline_rounded,
                      'e.g. Suresh Kumar',
                      ctrl: _nameCtrl,
                      type: TextInputType.name,
                    ),
                    _label('Date of birth'),
                    GestureDetector(
                      onTap: _pickDob,
                      child: AbsorbPointer(
                        child: inpField(
                          Icons.calendar_today_rounded,
                          'DD-MM-YYYY',
                          ctrl: _dobCtrl,
                          type: TextInputType.datetime,
                        ),
                      ),
                    ),
                    _label('Email optional'),
                    inpField(
                      Icons.email_outlined,
                      'name@example.com',
                      ctrl: _emailCtrl,
                      type: TextInputType.emailAddress,
                    ),
                    _label('Gender'),
                    Row(
                      children: [
                        _genderChip('male', '👨', 'Male'),
                        const SizedBox(width: 8),
                        _genderChip('female', '👩', 'Female'),
                        const SizedBox(width: 8),
                        _genderChip('other', '🧑', 'Other'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: _saving ? null : _submit,
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: C.ink,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: C.yellow,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Submit profile →',
                                  style: poppins(
                                    14,
                                    w: FontWeight.w700,
                                    c: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(
          text,
          style: poppins(12, w: FontWeight.w700, c: C.txl),
        ),
      );
}
