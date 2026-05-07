import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:design_system/design_system.dart';
import '../../../shared/providers/providers.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});
  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _otpCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).verifyOTPAndResetPassword(
        email: widget.email,
        token: _otpCtrl.text.trim(),
        newPassword: _passCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset successful! Please login.'), backgroundColor: AppColors.success),
        );
        context.go('/auth/login');
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'An error occurred. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  Container(
                    width: 70, height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: AppRadius.xl,
                    ),
                    child: const Icon(Icons.security_rounded, color: Colors.white, size: 38),
                  ),
                  const SizedBox(height: 24),
                  const Text('Reset Password', style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: -0.5)),
                  const SizedBox(height: 8),
                  Text('Enter the 6-digit code sent to ${widget.email} and your new password.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 14), textAlign: TextAlign.center),
                  const SizedBox(height: 32),

                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      borderRadius: AppRadius.xxl,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _otpCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Reset Code (OTP)',
                              labelStyle: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMuted),
                              prefixIcon: const Icon(Icons.pin_rounded)),
                            validator: (v) => (v?.length ?? 0) < 6 ? 'Enter 6-digit code' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'New Password',
                              labelStyle: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMuted),
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => (v?.length ?? 0) < 6 ? 'Min 6 characters' : null,
                          ),
                          const SizedBox(height: 24),

                          if (_error != null) ...[
                            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13), textAlign: TextAlign.center),
                            const SizedBox(height: 14),
                          ],

                          PrimaryButton(label: 'Update Password', onPressed: _resetPassword, isLoading: _loading),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
