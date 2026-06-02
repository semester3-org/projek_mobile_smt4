import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ExitGuard extends StatefulWidget {
  const ExitGuard({
    super.key,
    required this.child,
    this.message = 'Tekan kembali sekali lagi untuk keluar dari aplikasi.',
    this.timeout = const Duration(seconds: 2),
  });

  final Widget child;
  final String message;
  final Duration timeout;

  @override
  State<ExitGuard> createState() => _ExitGuardState();
}

class _ExitGuardState extends State<ExitGuard> {
  DateTime? _lastBackPressedAt;

  void _handleBack(bool didPop) {
    if (didPop) return;

    final now = DateTime.now();
    final shouldExit = _lastBackPressedAt != null &&
        now.difference(_lastBackPressedAt!) <= widget.timeout;

    if (shouldExit) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPressedAt = now;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(widget.message),
          duration: widget.timeout,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _handleBack(didPop),
      child: widget.child,
    );
  }
}
