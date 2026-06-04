import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../auth/auth_scope.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  String? _errorText;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final auth = AuthScope.of(context);
      final success = await auth.loginWithCredentials(
        email: _emailCtrl.text,
        password: _passCtrl.text,
      );

      if (!mounted) return;

      if (!success) {
        setState(() {
          _errorText = auth.lastLoginError ??
              'Email atau kata sandi tidak cocok. Periksa kembali.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Terjadi kesalahan: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _submitGoogle() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final errorMsg = await AuthScope.of(context).loginWithGoogle();

      if (!mounted) return;

      if (errorMsg != null) {
        setState(() {
          _errorText = errorMsg;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Terjadi kesalahan: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceTint,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            const SizedBox(height: 12),
            const _Header(
              title: 'Masuk ke Akun',
              subtitle: 'Masukkan email dan kata sandi Anda.',
            ),
            const SizedBox(height: 18),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'Email wajib diisi';
                          if (!s.contains('@')) {
                            return 'Format email tidak valid';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Kata Sandi',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (v) {
                          final s = (v ?? '');
                          if (s.isEmpty) return 'Password wajib diisi';
                          if (s.length < 4) return 'Minimal 4 karakter';
                          return null;
                        },
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const ForgotPasswordPage(),
                              ),
                            );
                          },
                          child: const Text('Lupa?'),
                        ),
                      ),
                      if (_errorText != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _errorText!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : const Text('Masuk'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const RegisterPage(),
                              ),
                            );
                          },
                          child: const Text('Belum punya akun? Daftar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                'Atau masuk dengan',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _submitGoogle,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              icon: const _GoogleLogoMark(),
              label: const Text(
                'Google',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogoMark extends StatelessWidget {
  const _GoogleLogoMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.15;
    final rect = Rect.fromLTWH(
      stroke,
      stroke,
      size.width - stroke * 2,
      size.height - stroke * 2,
    );
    Paint segment(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.square;

    canvas.drawArc(
      rect,
      math.pi * 1.15,
      math.pi * 0.42,
      false,
      segment(const Color(0xFFEA4335)),
    );
    canvas.drawArc(
      rect,
      math.pi * 0.78,
      math.pi * 0.37,
      false,
      segment(const Color(0xFFFBBC05)),
    );
    canvas.drawArc(
      rect,
      math.pi * 0.28,
      math.pi * 0.50,
      false,
      segment(const Color(0xFF34A853)),
    );
    canvas.drawArc(
      rect,
      -math.pi * 0.05,
      math.pi * 0.43,
      false,
      segment(const Color(0xFF4285F4)),
    );

    final blue = segment(const Color(0xFF4285F4));
    canvas.drawLine(
      Offset(size.width * 0.52, size.height * 0.5),
      Offset(size.width * 0.9, size.height * 0.5),
      blue,
    );
    canvas.drawLine(
      Offset(size.width * 0.78, size.height * 0.5),
      Offset(size.width * 0.78, size.height * 0.68),
      blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
        ),
      ],
    );
  }
}
