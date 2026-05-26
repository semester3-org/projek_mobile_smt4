import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import 'app/app_theme.dart';
import 'auth/auth_scope.dart';
import 'auth/auth_state.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KosFinderApp());
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
    _auth.restoreSession();
    _initDeepLinks();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pembayaran diterima. Status akan diperbarui otomatis.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      auth: _auth,
      child: MaterialApp(
        title: 'KosFinder',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const SplashScreen(),
      ),
    );
  }
}
