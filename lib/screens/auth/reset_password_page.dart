import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../core/api_service.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;
  final String? token;
  
  const ResetPasswordPage({
    super.key, 
    required this.email,
    this.token,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _tokenCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _message;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    if (widget.token != null && widget.token!.isNotEmpty) {
      _tokenCtrl.text = widget.token!;
    }
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitReset() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    setState(() { 
      _isLoading = true; 
      _message = null; 
    });

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Mereset password...'),
                ],
              ),
            ),
          ),
        ),
      );

      final result = await ApiService.resetPassword(
        token: _tokenCtrl.text.trim(),
        email: widget.email,
        newPassword: _newPassCtrl.text,
      );
      
      if (mounted) Navigator.of(context).pop();
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _isSuccess = result['success'] == true;
        _message = result['message'] ?? (_isSuccess
            ? 'Password berhasil diubah.'
            : 'Gagal mereset password.');
      });
      
      if (_isSuccess) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Berhasil!'),
            content: Text(_message!),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      setState(() { 
        _isLoading = false; 
        _message = 'Terjadi kesalahan: $e'; 
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceTint,
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            Text(
              'Password Baru',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold, 
                color: AppTheme.primaryGreen
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Masukkan token dari email dan password baru Anda.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600
              ),
            ),
            const SizedBox(height: 24),

            if (_isSuccess) ...[
              Card(
                color: Colors.green.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _message!,
                        style: const TextStyle(
                          color: Colors.green, 
                          fontWeight: FontWeight.w500
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Masuk dengan Password Baru'),
                ),
              ),
            ] else ...[
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.email, color: Colors.blue.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Email:', style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
                                    Text(widget.email, style: TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _tokenCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Token dari Email',
                            prefixIcon: Icon(Icons.vpn_key_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          validator: (v) {
                            if ((v ?? '').trim().isEmpty) return 'Token wajib diisi';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _newPassCtrl,
                          obscureText: _obscureNew,
                          decoration: InputDecoration(
                            labelText: 'Password Baru',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscureNew = !_obscureNew),
                              icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            ),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          validator: (v) {
                            if ((v ?? '').isEmpty) return 'Password wajib diisi';
                            if ((v ?? '').length < 4) return 'Minimal 4 karakter';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPassCtrl,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Konfirmasi Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            ),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          validator: (v) {
                            if ((v ?? '').isEmpty) return 'Konfirmasi password wajib diisi';
                            if (v != _newPassCtrl.text) return 'Password tidak cocok';
                            return null;
                          },
                        ),
                        if (_message != null && !_isSuccess) ...[
                          const SizedBox(height: 12),
                          Text(_message!, style: const TextStyle(color: Colors.red)),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _isLoading ? null : _submitReset,
                          child: _isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Simpan Password Baru'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}