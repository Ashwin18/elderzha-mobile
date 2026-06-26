import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/services.dart';
import '../../widgets/ez_button.dart';
import '../../widgets/yellow_header_scaffold.dart';

class AddMemberScreen extends StatefulWidget {
  const AddMemberScreen({super.key});
  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final _authService = AuthService();
  final _nameCtrl = TextEditingController();
  final _birthdayCtrl = TextEditingController();
  final _anniversaryCtrl = TextEditingController();
  DateTime? _birthdayDate;
  DateTime? _anniversaryDate;
  String _relation = '';
  bool _saving = false;

  final _relations = [
    'Spouse',
    'Child',
    'Parent',
    'Sibling',
    'Friend',
    'Other'
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-fill if editing
    final existing = ModalRoute.of(context)?.settings.arguments as Map?;
    if (existing != null) {
      _nameCtrl.text = existing['name']?.toString() ?? '';
      _relation = existing['relation'] is Map
          ? (existing['relation']['name']?.toString() ?? '')
          : (existing['relation']?.toString() ?? '');
      final eventType =
          (existing['event_type'] ?? existing['type'] ?? '').toString();
      final fallbackDate =
          (existing['date'] ?? existing['event_date'] ?? '').toString();
      _birthdayCtrl.text =
          (existing['birthday_date'] ?? existing['birthday'] ?? '').toString();
      _anniversaryCtrl.text = (existing['anniversary_date'] ?? '').toString();
      if (_birthdayCtrl.text.isEmpty && eventType.contains('birthday')) {
        _birthdayCtrl.text = fallbackDate;
      }
      if (_anniversaryCtrl.text.isEmpty &&
          eventType.toLowerCase().contains('anniversary')) {
        _anniversaryCtrl.text = fallbackDate;
      }
      _birthdayDate = _parseDate(_birthdayCtrl.text);
      _anniversaryDate = _parseDate(_anniversaryCtrl.text);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _birthdayCtrl.dispose();
    _anniversaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required TextEditingController ctrl,
    required ValueChanged<DateTime?> onPicked,
    required DateTime? initialDate,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 120),
      lastDate: DateTime(DateTime.now().year + 20),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.yellowDark),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      onPicked(picked);
      ctrl.text = _formatDate(picked);
    });
  }

  void _save() async {
    final hasBirthday = _birthdayCtrl.text.trim().isNotEmpty;
    final hasAnniversary = _anniversaryCtrl.text.trim().isNotEmpty;
    if (_nameCtrl.text.trim().isEmpty ||
        _relation.isEmpty ||
        (!hasBirthday && !hasAnniversary)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Add name, relation and at least one date',
              style: GoogleFonts.poppins()),
          backgroundColor: AppColors.red));
      return;
    }
    setState(() => _saving = true);
    final existing = ModalRoute.of(context)?.settings.arguments as Map?;
    Map<String, dynamic> res;
    if (existing != null && existing['id'] != null) {
      final id = int.tryParse(existing['id'].toString()) ?? 0;
      res = await _authService.updateFamily(
          id: id,
          name: _nameCtrl.text.trim(),
          relation: _relation,
          birthdayDate: _birthdayCtrl.text.trim().isEmpty
              ? null
              : _birthdayCtrl.text.trim(),
          anniversaryDate: _anniversaryCtrl.text.trim().isEmpty
              ? null
              : _anniversaryCtrl.text.trim());
    } else {
      res = await _authService.addFamily(
          name: _nameCtrl.text.trim(),
          relation: _relation,
          birthdayDate: _birthdayCtrl.text.trim().isEmpty
              ? null
              : _birthdayCtrl.text.trim(),
          anniversaryDate: _anniversaryCtrl.text.trim().isEmpty
              ? null
              : _anniversaryCtrl.text.trim());
    }
    setState(() => _saving = false);
    if (!mounted) return;
    if (res['status'] == true || res['data'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Member added! Alarm scheduled 🎉',
              style: GoogleFonts.poppins()),
          backgroundColor: AppColors.green));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(res['message'] ?? 'Error', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return YellowHeaderScaffold(
      headerHeight: 120,
      headerContent: Padding(
        padding: const EdgeInsets.fromLTRB(18, 52, 18, 0),
        child: Text('Add family member',
            style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.ink)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 4),

          // Relation chips
          _label('RELATION'),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _relations.map((r) {
                final sel = _relation == r;
                return GestureDetector(
                  onTap: () => setState(() => _relation = r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.yellowSoft : AppColors.bgCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: sel ? AppColors.yellowDark : AppColors.border,
                          width: sel ? 1.5 : 1),
                    ),
                    child: Text(r,
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: sel
                                ? AppColors.yellowDeep
                                : AppColors.inkMuted)),
                  ),
                );
              }).toList()),

          const SizedBox(height: 16),
          _label('MEMBER NAME'),
          TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  hintText: 'e.g. Father',
                  prefixIcon: Icon(Icons.person_outline_rounded))),

          const SizedBox(height: 16),
          _label('IMPORTANT DATES'),
          Row(children: [
            Expanded(
              child: _dateTile(
                emoji: '🎂',
                title: 'Birthday',
                ctrl: _birthdayCtrl,
                onTap: () => _pickDate(
                  ctrl: _birthdayCtrl,
                  initialDate: _birthdayDate,
                  onPicked: (d) => _birthdayDate = d,
                ),
                onClear: () => setState(() {
                  _birthdayCtrl.clear();
                  _birthdayDate = null;
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _dateTile(
                emoji: '💍',
                title: 'Anniversary',
                ctrl: _anniversaryCtrl,
                onTap: () => _pickDate(
                  ctrl: _anniversaryCtrl,
                  initialDate: _anniversaryDate,
                  onPicked: (d) => _anniversaryDate = d,
                ),
                onClear: () => setState(() {
                  _anniversaryCtrl.clear();
                  _anniversaryDate = null;
                }),
              ),
            ),
          ]),

          const SizedBox(height: 14),
          // Auto reminder banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.yellowSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.yellowLight)),
            child: Row(children: [
              const Text('🔔', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                      "You'll receive a reminder 1 day before this date every year automatically",
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.yellowDeep))),
            ]),
          ),

          const SizedBox(height: 24),
          EzButton(label: 'Save member', onTap: _save, loading: _saving),
        ]),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.inkLight,
                letterSpacing: 0.6)),
      );

  Widget _dateTile({
    required String emoji,
    required String title,
    required TextEditingController ctrl,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final hasDate = ctrl.text.trim().isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasDate ? AppColors.yellowSoft : AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasDate ? AppColors.yellowDark : AppColors.border,
            width: hasDate ? 2 : 1,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const Spacer(),
            if (hasDate)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded,
                    size: 16, color: AppColors.inkLight),
              ),
          ]),
          const SizedBox(height: 8),
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: hasDate ? AppColors.yellowDeep : AppColors.inkMuted)),
          const SizedBox(height: 5),
          Text(hasDate ? ctrl.text : 'Select date',
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: hasDate ? AppColors.ink : AppColors.inkLight)),
        ]),
      ),
    );
  }

  DateTime? _parseDate(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      final parts = raw.split('-');
      if (parts.length != 3) return null;
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      final c = int.tryParse(parts[2]);
      if (a == null || b == null || c == null) return null;
      return parts[0].length == 4 ? DateTime(a, b, c) : DateTime(c, b, a);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
}
