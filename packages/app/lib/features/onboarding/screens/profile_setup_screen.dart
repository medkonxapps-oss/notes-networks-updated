import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';
import '../../../shared/providers/providers.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose(); _usernameCtrl.dispose();
    _bioCtrl.dispose(); _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (uid != null) {
        await ref.read(authServiceProvider).updateProfile(uid, {
          'full_name': _nameCtrl.text.trim(),
          'username': _usernameCtrl.text.trim().toLowerCase(),
          'bio': _bioCtrl.text.trim(),
          'city': _cityCtrl.text.trim(),
        });
      }
      if (mounted) context.go('/onboarding/education');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Setup Profile'),
        leading: const SizedBox(),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: 0.33,
            backgroundColor: AppColors.border,
            color: AppColors.primary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tell us about yourself', style: AppText.headlineLarge),
              const SizedBox(height: 6),
              const Text('This will be shown on your public profile', style: AppText.bodyMedium),
              const SizedBox(height: 28),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.badge_rounded)),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(labelText: 'Username *', prefixIcon: Icon(Icons.alternate_email_rounded),
                  helperText: 'Letters, numbers, and underscores only'),
                validator: (v) {
                  if (v!.isEmpty) return 'Required';
                  if (v.length < 3) return 'Min 3 characters';
                  if (!RegExp(r'^[a-z0-9_]+$').hasMatch(v)) return 'Only lowercase, numbers, underscore';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _bioCtrl,
                maxLines: 3, maxLength: 300,
                decoration: const InputDecoration(labelText: 'Bio (optional)', prefixIcon: Icon(Icons.description_rounded)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _cityCtrl,
                decoration: const InputDecoration(labelText: 'City (optional)', prefixIcon: Icon(Icons.location_on_rounded)),
              ),
              const SizedBox(height: 32),
              PrimaryButton(label: 'Continue', onPressed: _next, isLoading: _loading),
            ],
          ),
        ),
      ),
    );
  }
}
