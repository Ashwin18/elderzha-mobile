import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../theme/app_theme.dart';
import '../../services/services.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});
  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  final _svc = SupportService();
  String? _content;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    // GET /user/policy/terms
    final res = await _svc.getPolicy('terms');
    if (!mounted) return;
    setState(() {
      _content = res?['data']?['content'] ?? res?['content'] ?? '<p>Terms and conditions coming soon.</p>';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    body: Column(children: [
      Container(color: C.yellow, child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
        child: Row(children: [
          GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: C.ink)),
          const SizedBox(width: 10),
          Text('Terms & Conditions', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink)),
        ]),
      ))),
      Expanded(child: Container(
        decoration: const BoxDecoration(color: C.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28))),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: C.yellowDark))
            : SingleChildScrollView(padding: const EdgeInsets.all(18), child: Html(data: _content)),
      )),
    ]),
  );
}
