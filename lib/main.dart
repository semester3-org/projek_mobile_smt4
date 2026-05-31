import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'app/app_theme.dart';
import 'auth/auth_scope.dart';
import 'auth/auth_state.dart';
import 'auth/roles.dart';
import 'core/app_navigator.dart';
import 'core/notification_delivery_service.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await _ensureFirebaseInitialized();
  } catch (error, stackTrace) {
    _fcmLog('Firebase initialization failed before runApp: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
  runApp(const KosFinderApp());

  _configureFirebaseMessaging(requestPermission: false);
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _ensureFirebaseInitialized();
}

bool _firebaseMessagingBaseConfigured = false;
bool _firebaseMessagingListenersConfigured = false;

Future<void> _configureFirebaseMessaging({
  bool requestPermission = true,
}) async {
  try {
    _fcmLog('Starting Firebase Messaging setup...');
    await _ensureFirebaseInitialized();
    _fcmLog('Firebase initialized.');

    if (!_firebaseMessagingBaseConfigured) {
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      _firebaseMessagingBaseConfigured = true;
      _fcmLog('Firebase Messaging auto-init enabled.');
    }

    if (!_firebaseMessagingListenersConfigured) {
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _fcmLog('FCM TOKEN REFRESHED: $newToken');
        NotificationDeliveryService.instance.updateFcmToken(newToken);
      });

      FirebaseMessaging.onMessage.listen(_handleForegroundRemoteMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedRemoteMessage);
      _firebaseMessagingListenersConfigured = true;
    }

    var settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (requestPermission) {
      settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    _fcmLog('Notification permission: ${settings.authorizationStatus}');
    if (settings.authorizationStatus == AuthorizationStatus.notDetermined &&
        !requestPermission) {
      _fcmLog('Notification permission will be requested after login.');
      return;
    }
    if (settings.authorizationStatus == AuthorizationStatus.denied ||
        settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      _fcmLog(
        'Notification permission denied/blocked. Aktifkan izin notifikasi dari pengaturan aplikasi untuk menerima push di luar app.',
      );
      return;
    }

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
  } catch (error, stackTrace) {
    _fcmLog('Firebase notification setup skipped: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

void _fcmLog(String message) {
  final text = '[FCM] $message';
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
        color: Colors.black,
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
  String? _lastPermissionPromptKey;
  bool _requestingLoginPermissions = false;

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
    if (session?.role == UserRole.user ||
        session?.role == UserRole.merchant ||
        session?.role == UserRole.owner) {
      NotificationDeliveryService.instance.start(
        role: session!.role,
        merchantType: session.merchantType,
      );
      final permissionKey = '${session.email}:${session.role.name}';
      if (_lastPermissionPromptKey != permissionKey) {
        _lastPermissionPromptKey = permissionKey;
        unawaited(_requestLoginRuntimePermissions());
      }
    } else {
      _lastPermissionPromptKey = null;
      NotificationDeliveryService.instance.stop();
    }
  }

  Future<void> _requestLoginRuntimePermissions() async {
    if (_requestingLoginPermissions) return;
    _requestingLoginPermissions = true;
    try {
      await _configureFirebaseMessaging(requestPermission: true);
      await _requestLocationPermission();
    } finally {
      _requestingLoginPermissions = false;
    }
  }

  Future<void> _requestLocationPermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        debugPrint('[Location] Location service is disabled.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        debugPrint(
          '[Location] Permission denied forever. User needs to enable it from app settings.',
        );
      }
    } catch (error) {
      debugPrint('[Location] Permission request skipped: $error');
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
