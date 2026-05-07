import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:design_system/design_system.dart';
import '../../../shared/providers/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;
  int _failedAttempts = 0;
  bool _isLockedOut = false;
  int _lockoutSeconds = 0;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _startLockout(int seconds) {
    setState(() { _isLockedOut = true; _lockoutSeconds = seconds; });
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _lockoutSeconds--);
      if (_lockoutSeconds <= 0) {
        setState(() { _isLockedOut = false; _failedAttempts = 0; });
        return false;
      }
      return true;
    });
  }

  Future<void> _login() async {
    if (_isLockedOut) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).signIn(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      if (mounted) context.go('/home');
    } on AuthException catch (e) {
      // Track failed login attempts for client-side lockout
      if (e.statusCode != '403') {
        _failedAttempts++;
        if (_failedAttempts >= 5) {
          _startLockout(30); // 30 second lockout after 5 failures
        }
      }
      if (e.statusCode == '403') {
        if (mounted) {
          final isPending = e.message.contains('pending');
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(
                    isPending ? Icons.pending_actions_rounded : Icons.block_flipped, 
                    color: isPending ? Colors.orange : AppColors.danger
                  ),
                  const SizedBox(width: 12),
                  Text(isPending ? 'Review Pending' : 'Account Restricted'),
                ],
              ),
              content: Text(
                isPending 
                  ? 'Your teacher account is currently under review by our admin team.\n\nThis usually takes 24-48 hours. You will receive an email once approved.'
                  : 'Your account has been deactivated or deleted. Please contact support for more information.'
              ),
              actions: [
                PrimaryButton(
                  label: 'Got it',
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          );
        }
        return;
      }
      setState(() => _error = _friendlyError(e.message));
    }
 catch (e) {
      setState(() => _error = 'An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String message) {
    if (message.contains('Invalid login credentials')) return 'Invalid email or password.';
    if (message.contains('Email not confirmed')) return 'Please verify your email before logging in.';
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.primary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: AppRadius.xl,
                    ),
                    child: const Icon(Icons.sticky_note_2_rounded, color: Colors.white, size: 44),
                  ),
                  const SizedBox(height: 16),
                  const Text('NotesNet', style: TextStyle(
                    fontSize: 30, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: -0.5)),
                  const SizedBox(height: 6),
                  Text('Where your notes go viral.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 14)),
                  const SizedBox(height: 32),

                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      borderRadius: AppRadius.xxl,
                      boxShadow: isDark ? [] : [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 32, offset: const Offset(0, 12),
                      )],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Welcome Back', 
                            style: AppText.headlineMedium.copyWith(color: isDark ? Colors.white : AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          Text('Sign in to your account', 
                            style: AppText.bodyMedium.copyWith(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
                          const SizedBox(height: 24),

                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Email',
                              labelStyle: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMuted),
                              prefixIcon: const Icon(Icons.email_outlined)),
                            validator: (v) => (v?.contains('@') == false) ? 'Enter valid email' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMuted),
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => (v?.length ?? 0) < 6 ? 'Min 6 characters' : null,
                          ),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => context.push('/auth/forgot-password'),
                              child: const Text('Forgot Password?',
                                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                            ),
                          ),

                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.08),
                                borderRadius: AppRadius.sm,
                                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                              ),
                              child: Row(children: [
                                const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13))),
                              ]),
                            ),
                            const SizedBox(height: 14),
                          ],

                          PrimaryButton(
                            label: _isLockedOut ? 'Try again in ${_lockoutSeconds}s' : 'Login',
                            onPressed: _isLockedOut ? null : _login,
                            isLoading: _loading,
                          ),
                          const SizedBox(height: 20),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text("Don't have an account? ", 
                              style: AppText.bodyMedium.copyWith(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
                            GestureDetector(
                              onTap: () => context.go('/auth/signup'),
                              child: const Text('Sign Up', style: TextStyle(
                                color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                            ),
                          ]),
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
