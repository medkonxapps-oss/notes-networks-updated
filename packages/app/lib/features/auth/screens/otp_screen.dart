import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:design_system/design_system.dart';
import '../../../shared/providers/providers.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String email;
  const OtpScreen({super.key, required this.email});
  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  bool _resending = false;
  bool _resentSuccess = false;
  int _cooldownSeconds = 0;

  Future<void> _resend() async {
    if (_cooldownSeconds > 0) return;
    setState(() { _resending = true; _resentSuccess = false; });
    try {
      await ref.read(supabaseClientProvider).auth.resend(
        type: OtpType.signup,
        email: widget.email,
        emailRedirectTo: 'io.notesnet.app://login-callback',
      );
      if (mounted) {
        setState(() { _resentSuccess = true; _cooldownSeconds = 60; });
        _startCooldown();
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to resend. Try again.'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _startCooldown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _cooldownSeconds--);
      return _cooldownSeconds > 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(color: Colors.white, borderRadius: AppRadius.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: AppRadius.xl),
                      child: const Icon(Icons.mark_email_read_rounded, color: AppColors.primary, size: 36),
                    ),
                    const SizedBox(height: 16),
                    const Text('Check Your Email', style: AppText.headlineMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                      'We sent a verification link to\n${widget.email}',
                      style: AppText.bodyMedium, textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: AppRadius.md),
                      child: const Row(children: [
                        Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                        SizedBox(width: 8),
                        Expanded(child: Text(
                          'Click the link in your email to verify your account, then come back to login.',
                          style: TextStyle(fontSize: 13, color: AppColors.primary, height: 1.4))),
                      ]),
                    ),
                    if (_resentSuccess) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: AppRadius.sm),
                        child: const Row(children: [
                          Icon(Icons.check_circle_outline, color: AppColors.success, size: 16),
                          SizedBox(width: 6),
                          Text('Email resent! Check your inbox.', style: TextStyle(color: AppColors.success, fontSize: 13)),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 24),
                    PrimaryButton(label: 'Go to Login', onPressed: () => context.go('/auth/login')),
                    const SizedBox(height: 12),
                    _resending
                        ? const SizedBox(height: 36, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
                        : TextButton(
                            onPressed: _cooldownSeconds > 0 ? null : _resend,
                            child: Text(
                              _cooldownSeconds > 0
                                  ? 'Resend in ${_cooldownSeconds}s'
                                  : 'Resend Email',
                              style: TextStyle(
                                color: _cooldownSeconds > 0 ? AppColors.textMuted : AppColors.primary,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
