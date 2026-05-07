import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';
import '../../../shared/providers/providers.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _emailSent = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).resetPassword(_emailCtrl.text.trim());
      if (mounted) {
        setState(() { _emailSent = true; _loading = false; });
      }
    } on AuthException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() { _error = 'An error occurred. Try again.'; _loading = false; });
    }
  }

  void _goToReset() {
    if (_emailCtrl.text.trim().isEmpty) return;
    context.push(
      '/auth/reset-password?email=${Uri.encodeComponent(_emailCtrl.text.trim())}',
    );
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
                    child: const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 38),
                  ),
                  const SizedBox(height: 24),
                  const Text('Forgot Password?', style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: -0.5)),
                  const SizedBox(height: 8),
                  Text(
                    _emailSent
                        ? 'A recovery code has been sent to your email. Check your inbox and tap "Enter Code" below.'
                        : 'Enter your email to receive a recovery code.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
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
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_emailSent,
                            style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              labelStyle: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMuted),
                              prefixIcon: const Icon(Icons.email_outlined)),
                            validator: (v) => (v?.contains('@') == false) ? 'Enter valid email' : null,
                          ),
                          const SizedBox(height: 24),

                          if (_error != null) ...[
                            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13), textAlign: TextAlign.center),
                            const SizedBox(height: 14),
                          ],

                          if (!_emailSent) ...[
                            PrimaryButton(label: 'Send Code', onPressed: _requestReset, isLoading: _loading),
                          ] else ...[
                            // Show success message + button to go to reset screen
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: AppRadius.md,
                                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Code sent! Check your email inbox.',
                                      style: TextStyle(color: AppColors.success, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            PrimaryButton(label: 'Enter Code & Reset Password', onPressed: _goToReset),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => setState(() { _emailSent = false; _error = null; }),
                              child: Text('Resend Code', style: TextStyle(color: isDark ? AppColors.primary : AppColors.primary)),
                            ),
                          ],
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
