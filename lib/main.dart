import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app/app_theme.dart';
import 'auth/auth_scope.dart';
import 'auth/auth_state.dart';
import 'auth/roles.dart';
import 'core/app_navigator.dart';
import 'core/notification_delivery_service.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KosFinderApp());

  _configureFirebaseMessaging();
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _ensureFirebaseInitialized();
}

Future<void> _configureFirebaseMessaging() async {
  try {
    _fcmLog('Starting Firebase Messaging setup...');
    await _ensureFirebaseInitialized();
    _fcmLog('Firebase initialized.');

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    _fcmLog('Firebase Messaging auto-init enabled.');

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    _fcmLog('Notification permission: ${settings.authorizationStatus}');

    _fcmLog('Requesting FCM token...');
    final token = await FirebaseMessaging.instance.getToken().timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        _fcmLog('FCM token request timeout after 20 seconds.');
        return null;
      },
    );
    _fcmLog('================ FCM TOKEN ================');
    _fcmLog(token ?? 'TOKEN NULL');
    _fcmLog('===========================================');

    if (token != null) {
      await NotificationDeliveryService.instance.updateFcmToken(token);
      _fcmLog('FCM token stored for backend sync.');
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _fcmLog('FCM TOKEN REFRESHED: $newToken');
      NotificationDeliveryService.instance.updateFcmToken(newToken);
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundRemoteMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedRemoteMessage);
  } catch (error, stackTrace) {
    _fcmLog('Firebase notification setup skipped: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

void _fcmLog(String message) {
  final text = '[FCM] $message';
  // ignore: avoid_print
  print(text);
  debugPrint(text);
}

void _handleForegroundRemoteMessage(RemoteMessage message) {
  final title = message.notification?.title ??
      message.data['title']?.toString() ??
      'Notifikasi baru';
  final body = message.notification?.body ??
      message.data['body']?.toString() ??
      'Pesan Firebase diterima saat aplikasi terbuka.';

  debugPrint('FCM foreground message: $title | $body');

  final messenger = appScaffoldMessengerKey.currentState;
  if (messenger == null) return;

  messenger.hideCurrentMaterialBanner();
  messenger.showMaterialBanner(
    MaterialBanner(
      backgroundColor: const Color(0xFFEAF4FF),
      leading: const Icon(
        Icons.notifications_active_outlined,
        color: Color(0xFF005EA8),
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, height: 1.3),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: messenger.hideCurrentMaterialBanner,
          child: const Text('Tutup'),
        ),
      ],
    ),
  );
  Future.delayed(const Duration(seconds: 5), () {
    messenger.hideCurrentMaterialBanner();
  });
}

void _handleOpenedRemoteMessage(RemoteMessage message) {
  debugPrint('FCM notification opened: ${message.messageId ?? '-'}');
}

Future<void> _ensureFirebaseInitialized() async {
  if (Firebase.apps.isNotEmpty) return;
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class KosFinderApp extends StatelessWidget {
  const KosFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const _KosFinderRoot();
  }
}

class _KosFinderRoot extends StatefulWidget {
  const _KosFinderRoot();

  @override
  State<_KosFinderRoot> createState() => _KosFinderRootState();
}

class _KosFinderRootState extends State<_KosFinderRoot> {
  late final AuthState _auth;
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _auth = AuthState();
    _auth.addListener(_syncNotificationDelivery);
    _auth.restoreSession();
    _initDeepLinks();
  }

  void _syncNotificationDelivery() {
    final session = _auth.session;
    if (session?.role == UserRole.user || session?.role == UserRole.merchant) {
      NotificationDeliveryService.instance.start(
        role: session!.role,
        merchantType: session.merchantType,
      );
    } else {
      NotificationDeliveryService.instance.stop();
    }
  }

  Future<void> _initDeepLinks() async {
    try {
      final initial = await _appLinks.getInitialLink();
      _handlePaymentDeepLink(initial);
      _appLinks.uriLinkStream.listen(_handlePaymentDeepLink);
    } catch (_) {}
  }

  void _handlePaymentDeepLink(Uri? uri) {
    if (uri == null) return;
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    if (host.contains('midtrans') ||
        path.contains('payment') ||
        uri.queryParameters.containsKey('transaction_status')) {
      if (!mounted) return;
      appScaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content:
              Text('Pembayaran diterima. Status akan diperbarui otomatis.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_syncNotificationDelivery);
    NotificationDeliveryService.instance.stop();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      auth: _auth,
      child: MaterialApp(
        navigatorKey: appNavigatorKey,
        scaffoldMessengerKey: appScaffoldMessengerKey,
        title: 'KosFinder',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        builder: (context, child) {
          final media = MediaQuery.of(context);
          final scale = media.textScaler.scale(1);
          final cappedScale = scale.clamp(1.0, 1.15).toDouble();
          return MediaQuery(
            data: media.copyWith(textScaler: TextScaler.linear(cappedScale)),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const SplashScreen(),
      ),
    );
  }
}
