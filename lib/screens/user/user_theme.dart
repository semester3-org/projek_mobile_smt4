import 'package:flutter/material.dart';

class UserTheme {
  UserTheme._();

  static const Color primary = Color(0xFF0B63B6);
  static const Color primaryDark = Color(0xFF00508F);
  static const Color accent = Color(0xFF1D4ED8);
  static const Color background = Color(0xFFF5F7FB);
  static const Color softBlue = Color(0xFFEAF3FF);
  static const Color text = Color(0xFF20242A);
  static const Color muted = Color(0xFF737B8C);
  static const Color success = Color(0xFF18B66A);
  static const Color danger = Color(0xFFD82121);
  static const Color warning = Color(0xFFFFA000);

  static BoxShadow softShadow({double opacity = 0.08}) {
    return BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(opacity),
      blurRadius: 24,
      offset: const Offset(0, 12),
    );
  }
}
