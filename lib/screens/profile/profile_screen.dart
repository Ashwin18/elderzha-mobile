import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/auth_provider.dart';
import '../../services/services.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_routes.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _subscriptionService = SubscriptionService();
  final _notificationService = NotificationService();
  final _alarmService = AlarmService();

  bool _loading = true;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _plan;
  Map<String, dynamic>? _alarm;
  int _familyCount = 0;
  int _notificationCount = 0;
  bool _localMedicalConfigured = false;
  bool _localFoodConfigured = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await context.read<AuthProvider>().loadUser();
    final results = await Future.wait([
      _subscriptionService.getPurchasedPlan(),
      _authService.getProfileWithFamily(),
      _notificationService.getNotifications(),
      _alarmService.getMedicalRecords(),
    ]);
    final fallbackFamily = await _loadSetupFamilyFallback();
    final localAlarmState = await _loadLocalAlarmState();
    if (!mounted) return;
    final family = _mergeFamily(_extractFamily(results[1]), fallbackFamily);
    setState(() {
      _plan = _extractMap(results[0]);
      _profile = _extractProfile(results[1]);
      _familyCount = family.length;
      _notificationCount =
          _extractList(results[2], ['data', 'notifications', 'today', 'unread'])
              .length;
      _alarm = _extractMap(results[3]);
      _localMedicalConfigured = localAlarmState.$1;
      _localFoodConfigured = localAlarmState.$2;
      _loading = false;
    });
  }

  Map<String, dynamic>? _extractMap(Map<String, dynamic>? res) {
    final data = res?['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return res;
  }

  Map<String, dynamic>? _extractProfile(Map<String, dynamic>? res) {
    if (res == null) return null;
    for (final value in [
      res['user'],
      res['profile'],
      res['data'],
      res['data'] is Map ? res['data']['user'] : null,
      res['data'] is Map ? res['data']['profile'] : null,
    ]) {
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return null;
  }

  List _extractFamily(Map<String, dynamic>? res) {
    if (res == null) return [];
    final candidates = [
      res['family'],
      res['members'],
      res['family_members'],
      res['data'] is Map ? res['data']['family'] : null,
      res['data'] is Map ? res['data']['members'] : null,
      res['data'] is Map ? res['data']['family_members'] : null,
      res['data'] is Map && res['data']['user'] is Map
          ? res['data']['user']['family']
          : null,
      res['data'] is Map && res['data']['profile'] is Map
          ? res['data']['profile']['family']
          : null,
    ];
    for (final value in candidates) {
      if (value is List) return value;
      if (value is Map) {
        for (final key in ['data', 'items', 'list', 'members']) {
          final nested = value[key];
          if (nested is List) return nested;
        }
      }
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _loadSetupFamilyFallback() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('setup_family_members');
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<(bool, bool)> _loadLocalAlarmState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('setup_alarm_summary');
    if (raw == null || raw.trim().isEmpty) return (false, false);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return (false, false);
      var medical = false;
      var food = false;
      for (final item in decoded) {
        if (item is! Map) continue;
        final label = (item['label'] ?? '').toString().toLowerCase();
        final icon = (item['icon'] ?? '').toString();
        if (label.contains('medication') || icon.contains('💊')) {
          medical = true;
        }
        if (label.contains('breakfast') ||
            label.contains('lunch') ||
            label.contains('dinner') ||
            icon.contains('🍳') ||
            icon.contains('🍱') ||
            icon.contains('🍽')) {
          food = true;
        }
      }
      return (medical, food);
    } catch (_) {
      return (false, false);
    }
  }

  List _mergeFamily(List remote, List<Map<String, dynamic>> fallback) {
    if (fallback.isEmpty) return remote;
    final seen = <String>{};
    final out = <dynamic>[];
    for (final item in [...remote, ...fallback]) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final relation = map['relation'] is Map
          ? (map['relation']['name'] ?? '')
          : (map['relation'] ?? '');
      final key = [
        (map['id'] ?? '').toString(),
        (map['name'] ?? '').toString().toLowerCase().trim(),
        relation.toString().toLowerCase().trim(),
        (map['birthday_date'] ?? map['birthday'] ?? map['date'] ?? '')
            .toString()
            .trim(),
        (map['anniversary_date'] ?? map['anniversary'] ?? '').toString().trim(),
      ].join('|');
      if (seen.add(key)) out.add(map);
    }
    return out;
  }

  List _extractList(Map<String, dynamic>? res, List<String> keys) {
    if (res == null) return [];
    for (final key in keys) {
      final value = res[key];
      if (value is List) return value;
      if (value is Map) {
        for (final nested in keys) {
          final nestedValue = value[nested];
          if (nestedValue is List) return nestedValue;
        }
      }
    }
    return [];
  }

  bool _truthy(dynamic value) {
    if (value == true) return true;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase().trim();
    return text == '1' || text == 'true' || text == 'yes' || text == 'active';
  }

  String get _planName {
    final p = _plan;
    if (p == null || p.isEmpty) return 'No active plan';
    return (p['plan_name'] ??
            p['name'] ??
            p['title'] ??
            p['plan']?['name'] ??
            'Subscribed')
        .toString();
  }

  String get _planStatus {
    final p = _plan;
    if (p == null || p.isEmpty) return 'Payment pending';
    final raw = p['status'] ?? p['subscription_status'] ?? 'Active';
    if (_truthy(raw)) return 'Active';
    final text = raw.toString();
    return text.toLowerCase() == 'true' ? 'Active' : text;
  }

  String get _planSubtitle {
    final p = _plan;
    if (p == null || p.isEmpty)
      return 'Choose a plan to activate monthly renewal';
    final expiry = p['end_date'] ?? p['expires_at'] ?? p['expiry_date'];
    return expiry != null ? 'Expires $expiry' : 'Subscription active';
  }

  String get _subscriptionHeaderText => _plan == null || _plan!.isEmpty
      ? 'Subscription pending'
      : 'Subscription active';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final medicalConfigured =
        _truthy(_alarm?['medical_alarm']) || _localMedicalConfigured;
    final foodConfigured =
        _truthy(_alarm?['food_alarm']) || _localFoodConfigured;
    final photoUrl = _profilePhotoUrl(auth.user);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.yellowDark,
        child: Column(children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.yellow,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Row(children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.34),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: photoUrl.isNotEmpty
                        ? Image.network(photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.person_rounded,
                                size: 36,
                                color: AppColors.ink))
                        : const Icon(Icons.person_rounded,
                            size: 36, color: AppColors.ink),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('My profile',
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.yellowDeep)),
                          const SizedBox(height: 2),
                          Text(auth.userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink)),
                          const SizedBox(height: 2),
                          Text(
                            auth.userPhone.isNotEmpty
                                ? '+91 ${auth.userPhone}'
                                : 'Mobile not available',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.yellowDeep),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _headerPill(_subscriptionHeaderText),
                          ),
                        ]),
                  ),
                ]),
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: AppColors.bg,
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.yellowDark))
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                      child: Column(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.yellowSoft,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.yellowLight),
                          ),
                          child: Row(children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(
                                      _plan == null || _plan!.isEmpty
                                          ? 'Subscription pending'
                                          : 'Subscription active',
                                      style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.yellowDeep)),
                                  Text(_planSubtitle,
                                      style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: AppColors.yellowDark)),
                                ])),
                            GestureDetector(
                              onTap: () => Navigator.pushNamed(
                                      context, AppRoutes.subscription)
                                  .then((_) => _load()),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                    color: AppColors.ink,
                                    borderRadius: BorderRadius.circular(10)),
                                child: Text('Manage',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                              color: AppColors.bgCard,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border)),
                          child: Column(children: [
                            _menuRow(
                                context,
                                Icons.person_outline_rounded,
                                AppColors.yellowDark,
                                'Edit profile',
                                null,
                                () => Navigator.pushNamed(
                                        context, AppRoutes.editProfile)
                                    .then((_) => _load())),
                            _menuRow(
                                context,
                                Icons.medication_rounded,
                                AppColors.yellowDark,
                                'Medical alarm',
                                medicalConfigured ? 'Configured' : 'Not set',
                                () => Navigator.pushNamed(
                                        context, AppRoutes.alarms)
                                    .then((_) => _load()),
                                valueColor: medicalConfigured
                                    ? AppColors.yellowDark
                                    : AppColors.inkLight),
                            _menuRow(
                                context,
                                Icons.restaurant_rounded,
                                AppColors.green,
                                'Food alarm',
                                foodConfigured ? 'Configured' : 'Not set',
                                () => Navigator.pushNamed(
                                        context, AppRoutes.alarms)
                                    .then((_) => _load()),
                                valueColor: foodConfigured
                                    ? AppColors.green
                                    : AppColors.inkLight),
                            _menuRow(
                                context,
                                Icons.people_rounded,
                                AppColors.blue,
                                'Family members',
                                '$_familyCount added',
                                () => Navigator.pushNamed(
                                        context, AppRoutes.familyMembers)
                                    .then((_) => _load()),
                                valuePill: true,
                                valueColor: AppColors.blue),
                            _menuRow(
                                context,
                                Icons.credit_card_rounded,
                                AppColors.yellowDark,
                                'Subscription & payment',
                                null,
                                () => Navigator.pushNamed(
                                        context, AppRoutes.subscription)
                                    .then((_) => _load())),
                            _menuRow(
                                context,
                                Icons.autorenew_rounded,
                                AppColors.green,
                                'AutoPay settings',
                                'Enabled',
                                () => Navigator.pushNamed(
                                        context, AppRoutes.autopaySettings)
                                    .then((_) => _load()),
                                valueColor: AppColors.green),
                            _menuRow(
                                context,
                                Icons.notifications_rounded,
                                AppColors.red,
                                'Notifications',
                                '$_notificationCount new',
                                () => Navigator.pushNamed(
                                        context, AppRoutes.notifications)
                                    .then((_) => _load()),
                                valuePill: true,
                                valueColor: AppColors.red),
                            _menuRow(
                                context,
                                Icons.support_agent_rounded,
                                AppColors.inkMuted,
                                'Support & feedback',
                                null,
                                () => Navigator.pushNamed(context, '/support')),
                            _menuRow(
                                context,
                                Icons.description_outlined,
                                AppColors.inkMuted,
                                'Privacy policy',
                                null,
                                () => Navigator.pushNamed(
                                    context, '/privacy-policy')),
                            _menuRow(
                                context,
                                Icons.article_outlined,
                                AppColors.inkMuted,
                                'Terms & conditions',
                                null,
                                () => Navigator.pushNamed(context, '/terms')),
                            _menuRow(context, Icons.logout_rounded,
                                AppColors.red, 'Logout', null, () async {
                              await context.read<AuthProvider>().logout();
                              if (context.mounted)
                                Navigator.pushReplacementNamed(
                                    context, AppRoutes.register);
                            }, isRed: true, isLast: true),
                          ]),
                        ),
                      ]),
                    ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _headerPill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(999)),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.ink)),
      );

  String _profilePhotoUrl(Map<String, dynamic>? authUser) {
    final source = {
      ...?_profile,
      ...?authUser,
    };
    for (final key in [
      'profile_photo_url',
      'photo_url',
      'avatar_url',
      'image_url',
      'profile_image',
      'image',
      'photo',
      'avatar',
    ]) {
      final value = source[key]?.toString().trim() ?? '';
      if (value.isEmpty || value.toLowerCase() == 'null') continue;
      if (value.startsWith('http')) return value;
      final clean = value.startsWith('/') ? value.substring(1) : value;
      return 'https://elderzhacopy.elderzha.online/$clean';
    }
    return '';
  }

  Widget _menuRow(BuildContext context, IconData icon, Color color,
      String label, String? value, VoidCallback onTap,
      {bool valuePill = false,
      Color? valueColor,
      bool isRed = false,
      bool isLast = false}) {
    return Column(children: [
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: Radius.zero,
          bottom: isLast ? const Radius.circular(20) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Icon(icon, size: 18, color: isRed ? AppColors.red : color),
            const SizedBox(width: 10),
            Expanded(
                child: Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isRed ? AppColors.red : AppColors.inkMuted))),
            if (value != null && !valuePill)
              Text(value,
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: valueColor ?? AppColors.inkMuted)),
            if (value != null && valuePill)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: (valueColor ?? AppColors.blue).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(value,
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: valueColor ?? AppColors.blue)),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 16, color: isRed ? AppColors.red : AppColors.inkLight),
          ]),
        ),
      ),
      if (!isLast) const Divider(height: 1, indent: 14, endIndent: 14),
    ]);
  }
}
