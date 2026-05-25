import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/app_theme.dart';
import '../../core/api_service.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;
  
  const ResetPasswordPage({
    super.key, 
    required this.email,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _tokenCtrls = List.generate(6, (_) => TextEditingController());
  final _tokenFocusNodes = List.generate(6, (_) => FocusNode());
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _isResending = false;
  String? _message;
  bool _isMessageError = false;
  bool _isSuccess = false;

  @override
  void dispose() {
    for (final controller in _tokenCtrls) {
      controller.dispose();
    }
    for (final focusNode in _tokenFocusNodes) {
      focusNode.dispose();
    }
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  String get _token => _tokenCtrls.map((controller) => controller.text).join();

  void _handleTokenChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.length > 1) {
      for (var i = 0; i < _tokenCtrls.length; i++) {
        _tokenCtrls[i].text = i < digits.length ? digits[i] : '';
      }
      final nextIndex = digits.length >= _tokenCtrls.length
          ? _tokenCtrls.length - 1
          : digits.length;
      _tokenFocusNodes[nextIndex].requestFocus();
      return;
    }

    _tokenCtrls[index].text = digits;
    _tokenCtrls[index].selection = TextSelection.collapsed(offset: digits.length);

    if (digits.isNotEmpty && index < _tokenFocusNodes.length - 1) {
      _tokenFocusNodes[index + 1].requestFocus();
    }
  }

  void _handleTokenBackspace(int index, KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.backspace) {
      return;
    }

    if (_tokenCtrls[index].text.isEmpty && index > 0) {
      _tokenFocusNodes[index - 1].requestFocus();
      _tokenCtrls[index - 1].clear();
    }
  }

  Future<void> _submitReset() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    setState(() { 
      _isLoading = true; 
      _message = null; 
      _isMessageError = false;
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
        token: _token,
        email: widget.email,
        newPassword: _newPassCtrl.text,
      );
      
      if (mounted) Navigator.of(context).pop();
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _isSuccess = result['success'] == true;
        _isMessageError = !_isSuccess;
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
        _isMessageError = true;
      });
    }
  }

  Future<void> _resendToken() async {
    setState(() {
      _isResending = true;
      _message = null;
      _isMessageError = false;
    });

    final result = await ApiService.forgotPassword(email: widget.email);

    if (!mounted) return;

    setState(() {
      _isResending = false;
      _isMessageError = result['success'] != true;
      _message = result['message'] ??
          (result['success'] == true
              ? 'Token baru telah dikirim ke email Anda.'
              : 'Gagal mengirim ulang token.');
    });
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
                                    Text(widget.email, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        FormField<String>(
                          validator: (_) {
                            if (_token.isEmpty) return 'Token wajib diisi';
                            if (!RegExp(r'^\d{6}$').hasMatch(_token)) {
                              return 'Token harus 6 digit angka';
                            }
                            return null;
                          },
                          builder: (field) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Token dari Email',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(
                                  _tokenCtrls.length,
                                  (index) => SizedBox(
                                    width: 44,
                                    height: 52,
                                    child: Focus(
                                      onKeyEvent: (_, event) {
                                        _handleTokenBackspace(index, event);
                                        return KeyEventResult.ignored;
                                      },
                                      child: TextFormField(
                                        controller: _tokenCtrls[index],
                                        focusNode: _tokenFocusNodes[index],
                                        keyboardType: TextInputType.number,
                                        textInputAction: index == _tokenCtrls.length - 1
                                            ? TextInputAction.done
                                            : TextInputAction.next,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          LengthLimitingTextInputFormatter(6),
                                        ],
                                        decoration: InputDecoration(
                                          counterText: '',
                                          contentPadding: EdgeInsets.zero,
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: field.hasError
                                                  ? Colors.red
                                                  : Colors.grey.shade300,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                              color: AppTheme.primaryGreen,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        onChanged: (value) {
                                          _handleTokenChanged(index, value);
                                          field.didChange(_token);
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (field.hasError) ...[
                                const SizedBox(height: 8),
                                Text(
                                  field.errorText!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
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
                            if ((v ?? '').length < 8) return 'Minimal 8 karakter';
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
                          Text(
                            _message!,
                            style: TextStyle(
                              color: _isMessageError ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _isLoading ? null : _submitReset,
                          child: _isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Simpan Password Baru'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _isLoading || _isResending ? null : _resendToken,
                          child: _isResending
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Kirim Ulang Token'),
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
