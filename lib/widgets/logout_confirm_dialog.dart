import 'package:flutter/material.dart';

Future<bool> confirmLogout(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Yakin ingin log out?'),
      content: const Text('Anda perlu masuk kembali untuk menggunakan akun ini.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Tidak'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Ya, log out'),
        ),
      ],
    ),
  );
  return result == true;
}
