import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:design_system/design_system.dart';
import '../../../shared/providers/providers.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      // Step 1: Re-authenticate with current password to verify identity
      final client = ref.read(supabaseClientProvider);
      final email = client.auth.currentUser?.email;
      if (email == null) throw Exception('Session expired. Please login again.');

      // Verify current password by trying to sign in
      try {
        await client.auth.signInWithPassword(
          email: email,
          password: _currentPassCtrl.text.trim(),
        );
      } on AuthException catch (_) {
        setState(() { _error = 'Current password is incorrect.'; _loading = false; });
        return;
      }

      // Step 2: Update to new password
      await client.auth.updateUser(
        UserAttributes(password: _newPassCtrl.text.trim()),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password updated successfully!'),
          backgroundColor: AppColors.success,
        ));
        context.pop();
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        title: Text('Change Password',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
            )),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2D2D4D) : AppColors.primarySurface,
                  borderRadius: AppRadius.md,
                ),
                child: Row(children: [
                  const Icon(Icons.security_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Enter your current password to verify, then set a new one. Must be 8+ chars with uppercase & number.',
                      style: TextStyle(
                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 28),

              // Current Password
              TextFormField(
                controller: _currentPassCtrl,
                obscureText: _obscureCurrent,
                style: TextStyle(color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: const Icon(Icons.lock_open_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrent ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
                validator: (v) => (v?.isEmpty ?? true) ? 'Enter your current password' : null,
              ),
              const SizedBox(height: 16),

              // New Password
              TextFormField(
                controller: _newPassCtrl,
                obscureText: _obscureNew,
                style: TextStyle(color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                validator: (v) {
                  if ((v?.length ?? 0) < 8) return 'Minimum 8 characters';
                  if (!RegExp(r'[A-Z]').hasMatch(v!)) return 'Include at least 1 uppercase letter';
                  if (!RegExp(r'[0-9]').hasMatch(v)) return 'Include at least 1 number';
                  if (v == _currentPassCtrl.text) return 'New password must differ from current';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Confirm New Password
              TextFormField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                style: TextStyle(color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: const Icon(Icons.lock_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) => v != _newPassCtrl.text ? 'Passwords do not match' : null,
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.08),
                    borderRadius: AppRadius.sm,
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13))),
                  ]),
                ),
              ],

              const SizedBox(height: 32),
              PrimaryButton(
                label: 'Update Password',
                icon: Icons.lock_reset_rounded,
                onPressed: _save,
                isLoading: _loading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
