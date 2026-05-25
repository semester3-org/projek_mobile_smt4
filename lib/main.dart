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

  @override
  void initState() {
    super.initState();
    _auth = AuthState();
    _auth.restoreSession();
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
