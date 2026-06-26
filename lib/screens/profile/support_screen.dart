import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/services.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _svc = SupportService();
  final _msgCtrl = TextEditingController();
  List _issueTypes = [];
  int? _selectedType;
  bool _loading = true;
  bool _submitting = false;
  bool _submitted = false;
  List _faqs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _svc.getIssueTypes(), // GET /user/get/issue/type
      _svc.getFaqs(), // GET /user/faqs
    ]);
    if (!mounted) return;
    setState(() {
      _issueTypes = results[0]?['data'] ?? [];
      _faqs = results[1]?['data'] ?? [];
      if (_issueTypes.isNotEmpty) _selectedType = _issueTypes[0]['id'];
      _loading = false;
    });
  }

  Future<void> _submit() async {
    if (_selectedType == null || _msgCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Please fill all fields', style: GoogleFonts.poppins()),
          backgroundColor: C.red));
      return;
    }
    setState(() => _submitting = true);
    // POST /user/store/support/ticket
    await _svc.storeSupportTicket(
        issueTypeId: _selectedType!, description: _msgCtrl.text.trim());
    setState(() {
      _submitting = false;
      _submitted = true;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: C.bg,
        body: Column(children: [
          Container(
              width: double.infinity,
              color: C.yellow,
              child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                    child: Row(children: [
                      GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              size: 18, color: C.ink)),
                      const SizedBox(width: 10),
                      Text('Support & Feedback',
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: C.ink)),
                    ]),
                  ))),
          Expanded(
              child: Container(
            decoration: const BoxDecoration(
                color: C.white,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28))),
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: C.yellowDark))
                : _submitted
                    ? _successView()
                    : _formView(),
          )),
        ]),
      );

  Widget _formView() => SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Issue type',
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w700, color: C.txl)),
        const SizedBox(height: 8),
        if (_issueTypes.isNotEmpty)
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _issueTypes.map<Widget>((t) {
                final sel = _selectedType == t['id'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = t['id']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                        color: sel ? C.yellowLight : C.bg2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: sel ? C.yellow : C.bd,
                            width: sel ? 1.5 : 1)),
                    child: Text(t['name'] ?? t['title'] ?? '',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: sel ? C.yellowDeep : C.txm)),
                  ),
                );
              }).toList())
        else ...[
          for (final t in [
            'Technical issue',
            'Billing',
            'Alarm not working',
            'Other'
          ])
            Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GestureDetector(
                    onTap: () {},
                    child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: C.bg2,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: C.bd)),
                        child: Text(t,
                            style: GoogleFonts.poppins(fontSize: 12))))),
        ],
        const SizedBox(height: 16),
        Text('Describe your issue',
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w700, color: C.txl)),
        const SizedBox(height: 8),
        TextField(
            controller: _msgCtrl,
            maxLines: 5,
            style: GoogleFonts.poppins(fontSize: 13, color: C.ink),
            decoration: InputDecoration(
                hintText: 'Tell us what happened...',
                hintStyle: GoogleFonts.poppins(fontSize: 13, color: C.txl))),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _submitting ? null : _submit,
          child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                  color: C.yellow, borderRadius: BorderRadius.circular(14)),
              child: Center(
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: C.ink, strokeWidth: 2))
                      : Text('Submit ticket',
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: C.ink)))),
        ),
        if (_faqs.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('FAQs',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w700, color: C.ink)),
          const SizedBox(height: 10),
          ..._faqs.take(5).map<Widget>((f) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: C.bg2, borderRadius: BorderRadius.circular(12)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f['question'] ?? '',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: C.ink)),
                      const SizedBox(height: 4),
                      Text(f['answer'] ?? '',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: C.txm, height: 1.5)),
                    ]),
              )),
        ],
      ]));

  Widget _successView() => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('✅', style: TextStyle(fontSize: 60)),
        const SizedBox(height: 16),
        Text('Ticket submitted!',
            style: GoogleFonts.poppins(
                fontSize: 20, fontWeight: FontWeight.w700, color: C.ink)),
        const SizedBox(height: 8),
        Text('We will get back to you within 24 hours',
            style: GoogleFonts.poppins(fontSize: 13, color: C.txm),
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                    color: C.yellow, borderRadius: BorderRadius.circular(14)),
                child: Text('Back',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: C.ink)))),
      ]));
}
