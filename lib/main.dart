import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

import 'firebase_options.dart';
import 'network/connectivity_wrapper.dart';
import 'providers/auth_provider.dart';
import 'services/api_client.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'utils/app_routes.dart';
import 'widgets/main_scaffold.dart';

// ── Screens ───────────────────────────────────────────────────────────────────
import 'screens/onboarding/splash_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/otp_screen.dart';
import 'screens/auth/setup_profile_screen.dart';
import 'screens/auth/payment_screen.dart';
import 'screens/auth/payment_success_screen.dart';
import 'screens/alarms/alarm_setup_screen.dart';
import 'screens/alarms/alarms_screen.dart';
import 'screens/home/check_in_screen.dart';
import 'screens/reminders/reminder_screen.dart';
import 'screens/profile/notifications_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/subscription_screen.dart';
import 'screens/auth/subscription_gate_screen.dart';
import 'screens/profile/autopay_settings_screen.dart';
import 'screens/profile/family_members_screen.dart';
import 'screens/profile/add_member_screen.dart';
import 'screens/profile/polls_screen.dart';
import 'screens/offers/offers_screen.dart';
import 'screens/community/community_screen.dart';
import 'screens/community/activity_detail_screen.dart';
import 'screens/offers/offer_details_screen.dart';
import 'screens/policy/privacy_policy_screen.dart';
import 'screens/policy/terms_screen.dart';
import 'screens/profile/support_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  FCM + local notifications globals
// ─────────────────────────────────────────────────────────────────────────────
final FlutterLocalNotificationsPlugin _localNotifs =
    FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
Timer? _notificationHistoryTimer;
bool _notificationHistoryLoading = false;

const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'ElderZha important notifications',
  importance: Importance.max,
);

// ─────────────────────────────────────────────────────────────────────────────
//  Background FCM handler (top-level, vm:entry-point required)
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (message.notification == null) {
    await _ensureLocalNotificationsReady();
    await _showRemoteMessageNotification(message);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MAIN
// ─────────────────────────────────────────────────────────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Portrait only ──
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // ── Firebase ──
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_bgHandler);

  // ── Timezone ──
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

  await _ensureLocalNotificationsReady(onTap: _onNotifTap);

  if (Platform.isAndroid) {
    await _localNotifs
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // ── FCM setup ──
  await _setupFCM();
  _startNotificationHistoryPolling();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider()..checkAuth(),
      child: const ElderZhaApp(),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  FCM SETUP
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _setupFCM() async {
  final messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(alert: true, badge: true, sound: true);

  final token = await messaging.getToken();
  debugPrint('FCM Token: $token');
  await _syncFCMToken(token);

  messaging.onTokenRefresh.listen(_syncFCMToken);

  FirebaseMessaging.onMessage.listen(_showRemoteMessageNotification);

  // Background tap
  FirebaseMessaging.onMessageOpenedApp.listen(_handleNotifData);

  // Terminated state tap
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) {
    _handleNotifData(initial, delayed: true);
  }
}

Future<void> _syncFCMToken(String? token) async {
  if (token == null || token.isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('fcm_device_token', token);

  final authToken = prefs.getString('auth_token') ?? '';
  if (authToken.isEmpty) return;

  // POST /user/device-token
  try {
    final res = await ApiClient().safePost(
      '/user/device-token',
      data: {'fcm_token': token},
    );
    debugPrint('FCM token synced to server');
    debugPrint('FCM token sync response: $res');
  } catch (e) {
    debugPrint('FCM token sync error: $e');
  }
}

// Simplified — using Dio from api_client
Future<void> _handleNotifData(RemoteMessage msg, {bool delayed = false}) async {
  if (delayed) await Future.delayed(const Duration(seconds: 3));
  final data = {
    ...msg.data,
    if (msg.notification?.title != null) 'title': msg.notification!.title,
    if (msg.notification?.body != null) 'body': msg.notification!.body,
  };
  debugPrint('Notification data: $data');
  if (!_isUsableNotification(data)) return;
  await _rememberNotification(data);
  _openNotificationTarget(data);
}

Future<void> _onNotifTap(NotificationResponse res) async {
  debugPrint('Notification tapped: ${res.payload}');
  if (res.payload == null || res.payload!.trim().isEmpty) return;
  try {
    final decoded = jsonDecode(res.payload!);
    if (decoded is Map) {
      final data = Map<String, dynamic>.from(decoded);
      if (_isUsableNotification(data)) _openNotificationTarget(data);
    }
  } catch (e) {
    debugPrint('Notification payload decode error: $e');
  }
}

Future<void> _ensureLocalNotificationsReady({
  void Function(NotificationResponse)? onTap,
}) async {
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );
  await _localNotifs.initialize(
    initSettings,
    onDidReceiveNotificationResponse: onTap,
  );
  await _localNotifs
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_channel);
}

Future<void> _showRemoteMessageNotification(RemoteMessage msg) async {
  final notif = msg.notification;
  final data = msg.data;
  final title = _firstText([
        notif?.title,
        data['title'],
        data['notification_title'],
        data['heading'],
        data['type'],
      ]) ??
      'ElderZha';
  final body = _firstText([
        notif?.body,
        data['body'],
        data['message'],
        data['notification'],
        data['description'],
      ]) ??
      'You have a new update';
  final payload = {
    ...data,
    'title': title,
    'body': body,
    'created_at': DateTime.now().toIso8601String(),
  };
  if (!_isUsableNotification(payload)) return;
  await _rememberNotification(payload);

  await _localNotifs.show(
    (msg.messageId ?? '$title-$body-${data.hashCode}').hashCode,
    _cleanNotificationText(title),
    _cleanNotificationText(body),
    NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(),
    ),
    payload: jsonEncode(payload),
  );
}

void _openNotificationTarget(Map<String, dynamic> data) {
  final nav = appNavigatorKey.currentState;
  if (nav == null) {
    Future.delayed(
      const Duration(milliseconds: 600),
      () => _openNotificationTarget(data),
    );
    return;
  }

  nav.pushNamedAndRemoveUntil(
    AppRoutes.notifications,
    (route) => false,
    arguments: {'notification': data, 'fromPush': true},
  );
}

void _startNotificationHistoryPolling() {
  _pollNotificationHistory(showNew: false);
  _notificationHistoryTimer ??= Timer.periodic(
    const Duration(seconds: 45),
    (_) => _pollNotificationHistory(),
  );
}

Future<void> _pollNotificationHistory({bool showNew = true}) async {
  if (_notificationHistoryLoading) return;
  _notificationHistoryLoading = true;
  try {
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('auth_token') ?? '';
    if (authToken.isEmpty) return;

    final res = await NotificationService().getNotifications();
    final notifications =
        _extractNotificationItems(res).where(_isUsableNotification).toList();
    if (notifications.isEmpty) return;

    final seen = prefs.getStringList('seen_notification_ids')?.toSet() ?? {};
    final ids = notifications.map(_notificationId).whereType<String>().toSet();

    if (seen.isEmpty || !showNew) {
      await prefs.setStringList('seen_notification_ids', ids.toList());
      return;
    }

    final newItems = notifications
        .where((n) {
          final id = _notificationId(n);
          return id != null && !seen.contains(id);
        })
        .take(3)
        .toList();

    for (final n in newItems.reversed) {
      await _rememberNotification(n);
    }
    await prefs.setStringList(
      'seen_notification_ids',
      {...seen, ...ids}.take(100).toList(),
    );
  } catch (e) {
    debugPrint('Notification history poll error: $e');
  } finally {
    _notificationHistoryLoading = false;
  }
}

Future<void> _showHistoryNotification(Map<String, dynamic> n) async {
  if (!_isUsableNotification(n)) return;
  final title = _firstText([
        n['title'],
        n['type'],
        n['category'],
      ]) ??
      'ElderZha';
  final body = _firstText([
        n['message'],
        n['body'],
        n['notification'],
        n['description'],
      ]) ??
      'You have a new update';
  final payload = {
    ...n,
    'title': title,
    'body': body,
    'created_at': n['created_at'] ?? DateTime.now().toIso8601String(),
  };
  await _rememberNotification(payload);
  await _localNotifs.show(
    (_notificationId(n) ?? '$title-$body').hashCode,
    _cleanNotificationText(title),
    _cleanNotificationText(body),
    NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(),
    ),
    payload: jsonEncode(payload),
  );
}

Future<void> _rememberNotification(Map<String, dynamic> n) async {
  if (!_isUsableNotification(n)) return;
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getStringList('local_notification_history') ?? [];
  final id = _notificationId(n) ??
      '${DateTime.now().millisecondsSinceEpoch}|${n['title'] ?? ''}';
  final normalized = {
    ...n,
    'id': id,
    'created_at': n['created_at'] ?? DateTime.now().toIso8601String(),
  };
  final encoded = jsonEncode(normalized);
  final filtered = existing.where((raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is! Map || decoded['id'] != id;
    } catch (_) {
      return false;
    }
  }).toList();
  await prefs.setStringList(
    'local_notification_history',
    [encoded, ...filtered].take(100).toList(),
  );
  final seen = prefs.getStringList('seen_notification_ids')?.toSet() ?? {};
  await prefs.setStringList(
    'seen_notification_ids',
    {...seen, id}.take(150).toList(),
  );
}

List<Map<String, dynamic>> _extractNotificationItems(
    Map<String, dynamic>? res) {
  if (res == null) return [];
  final out = <Map<String, dynamic>>[];
  _collectNotificationItems(res, out);
  return out;
}

void _collectNotificationItems(
  dynamic value,
  List<Map<String, dynamic>> out, {
  String? groupDate,
}) {
  if (value is List) {
    for (final item in value) {
      _collectNotificationItems(item, out, groupDate: groupDate);
    }
    return;
  }
  if (value is! Map) return;

  final map = Map<String, dynamic>.from(value);
  final nextGroup = (map['date'] ?? map['group_date'])?.toString();
  if (!_isNotificationApiEnvelope(map) && _looksLikeNotificationItem(map)) {
    out.add({
      ...map,
      if (groupDate != null && map['group_date'] == null)
        'group_date': groupDate,
    });
    return;
  }

  for (final key in [
    'data',
    'notifications',
    'notification',
    'notification_history',
    'histories',
    'items',
    'list',
    'history',
    'today',
    'yesterday',
    'earlier',
    'unread',
    'read',
  ]) {
    final child = map[key];
    if (child != null) {
      _collectNotificationItems(child, out, groupDate: nextGroup ?? groupDate);
    }
  }
}

bool _isNotificationApiEnvelope(Map map) {
  final hasListChild = [
    'data',
    'notifications',
    'notification_history',
    'histories',
    'items',
    'list',
    'history',
    'today',
    'yesterday',
    'earlier',
    'unread',
    'read',
  ].any((key) => map[key] is List || map[key] is Map);
  final hasStatusMessage = map.containsKey('status') &&
      (map.containsKey('message') || map.containsKey('msg'));
  return hasListChild && hasStatusMessage;
}

bool _looksLikeNotificationItem(Map map) {
  if (!_isUsableNotification(Map<String, dynamic>.from(map))) return false;
  const keys = [
    'title',
    'message',
    'body',
    'notification',
    'description',
    'module_type',
    'notification_type',
    'type',
    'category',
    'timeline',
    'created_at',
  ];
  return keys.any((key) {
    final value = map[key];
    return value != null && value.toString().trim().isNotEmpty;
  });
}

String? _notificationId(Map<String, dynamic> n) {
  final moduleType = _firstText([
    n['module_type'],
    n['notification_type'],
    n['type'],
    n['category'],
    n['data'] is Map ? n['data']['module_type'] : null,
  ]);
  final moduleId = _firstText([
    n['module_id'],
    n['feed_id'],
    n['post_id'],
    n['poll_id'],
    n['activity_id'],
    n['offer_id'],
    n['coupon_id'],
    n['data'] is Map ? n['data']['module_id'] : null,
  ]);
  if (moduleType != null && moduleId != null) {
    return '${moduleType.toLowerCase()}|$moduleId';
  }
  final id = _firstText([
    n['id'],
    n['notification_id'],
    n['created_at'],
    n['timeline'],
  ]);
  final body = _firstText([n['message'], n['body'], n['title']]);
  if (id == null && body == null) return null;
  return '${id ?? ''}|${body ?? ''}';
}

bool _isUsableNotification(Map<String, dynamic> n) {
  final title = _firstText([n['title'], n['notification_title'], n['heading']]);
  final body = _firstText([
    n['body'],
    n['message'],
    n['notification'],
    n['description'],
    n['response'],
  ]);
  final combined = '${title ?? ''} ${body ?? ''}'.toLowerCase();
  if (combined.trim().isEmpty) return true;
  return !combined.contains('server error') &&
      !combined.contains('client error') &&
      !combined.contains('exception') &&
      !combined.contains('invalid_grant') &&
      !combined.contains('firebase token missing') &&
      !combined.contains('notification history fetched successfully') &&
      !combined.contains('fetched successfully') &&
      !combined.contains('network error');
}

String? _firstText(List values) {
  for (final value in values) {
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
  }
  return null;
}

String _cleanNotificationText(String value) {
  return value.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll('&nbsp;', ' ');
}

// ─────────────────────────────────────────────────────────────────────────────
//  APP
// ─────────────────────────────────────────────────────────────────────────────
class ElderZhaApp extends StatelessWidget {
  const ElderZhaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'ElderZha',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      initialRoute: AppRoutes.splash,
      builder: (context, child) =>
          ConnectivityWrapper(child: child ?? const SizedBox()),
      routes: {
        AppRoutes.splash: (_) => const SplashScreen(),
        AppRoutes.onboarding: (_) => const OnboardingScreen(),
        AppRoutes.register: (_) => const RegisterScreen(),
        AppRoutes.otp: (_) => const OtpScreen(),
        AppRoutes.setupProfile: (_) => const SetupProfileScreen(),
        AppRoutes.alarmSetup: (_) => const AlarmSetupScreen(),
        AppRoutes.payment: (_) => const PaymentScreen(),
        AppRoutes.paymentSuccess: (_) => const PaymentSuccessScreen(),
        AppRoutes.reminder: (_) => const ReminderScreen(),
        AppRoutes.home: (ctx) {
          final args = ModalRoute.of(ctx)?.settings.arguments;
          final map = args is Map ? Map<String, dynamic>.from(args) : const {};
          return MainScaffold(
            initialIndex: int.tryParse((map['tab'] ?? 0).toString()) ?? 0,
            communityInitialTab:
                int.tryParse((map['communityTab'] ?? 0).toString()) ?? 0,
          );
        },
        AppRoutes.checkIn: (_) => const CheckInScreen(),
        AppRoutes.notifications: (_) => const NotificationsScreen(),
        AppRoutes.profile: (_) => const ProfileScreen(),
        AppRoutes.alarms: (_) => const AlarmsScreen(),
        AppRoutes.subscription: (_) => const SubscriptionScreen(),
        AppRoutes.autopaySettings: (_) => const AutoPaySettingsScreen(),
        AppRoutes.familyMembers: (_) => const FamilyMembersScreen(),
        AppRoutes.addMember: (_) => const AddMemberScreen(),
        AppRoutes.editProfile: (_) => const EditProfileScreen(),
        AppRoutes.polls: (_) => const PollsScreen(),
        AppRoutes.offers: (_) => const OffersScreen(),
        AppRoutes.community: (ctx) {
          final args = ModalRoute.of(ctx)?.settings.arguments;
          final map = args is Map ? Map<String, dynamic>.from(args) : const {};
          return CommunityScreen(
            initialTab: int.tryParse(
                    (map['communityTab'] ?? map['tab'] ?? 0).toString()) ??
                0,
          );
        },
        AppRoutes.coupons: (_) => const OffersScreen(),
        '/activity-detail': (_) => const ActivityDetailScreen(),
        '/offer-detail': (ctx) {
          final id = ModalRoute.of(ctx)!.settings.arguments as int;
          return OfferDetailsScreen(offerId: id);
        },
        '/privacy-policy': (_) => const PrivacyPolicyScreen(),
        '/terms': (_) => const TermsScreen(),
        '/support': (_) => const SupportScreen(),
      },
    );
  }
}
