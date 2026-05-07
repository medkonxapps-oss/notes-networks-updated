import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:design_system/design_system.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/providers/providers.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});
  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _institutionCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _linkedinCtrl = TextEditingController();
  final _specializationCtrl = TextEditingController();
  File? _idCardFile;
  String _role = 'student';

  bool _loading = false;
  String? _error;
  bool _obscure = true;
  bool _obscureConfirm = true;
  String _board = 'CBSE';
  String _classLevel = 'Class 10';

  @override
  void dispose() {
    _nameCtrl.dispose(); _institutionCtrl.dispose(); _phoneCtrl.dispose(); 
    _usernameCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose(); _confirmPassCtrl.dispose();
    _linkedinCtrl.dispose(); _specializationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickIdCard() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _idCardFile = File(image.path));
    }
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_role == 'teacher' && _idCardFile == null) {
      setState(() => _error = 'Please upload your ID Card');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      String? idCardUrl;
      if (_role == 'teacher' && _idCardFile != null) {
        final bytes = await _idCardFile!.readAsBytes();
        final ext = _idCardFile!.path.split('.').last;
        idCardUrl = await ref.read(authServiceProvider).uploadIdCard(bytes, ext);
      }

      await ref.read(authServiceProvider).signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        username: _usernameCtrl.text.trim().toLowerCase(),
        fullName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        institutionName: _institutionCtrl.text.trim(),
        board: _board,
        classLevel: _classLevel,
        role: _role,
        linkedinUrl: _role == 'teacher' ? _linkedinCtrl.text.trim() : null,
        idCardUrl: idCardUrl,
        subjects: _role == 'teacher' 
          ? _specializationCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          : null,
      );
      
      if (mounted) {
        if (_role == 'teacher') {
          // Show popup for teachers
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.success),
                  SizedBox(width: 12),
                  Text('Registration Sent'),
                ],
              ),
              content: const Text(
                'Your teacher account has been created and is now under review by our admin team.\n\n'
                'Please verify your email to complete the process. You will be notified once your account is approved.',
              ),
              actions: [
                PrimaryButton(
                  label: 'Verify Email',
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/auth/verify?email=${_emailCtrl.text.trim()}');
                  },
                ),
              ],
            ),
          );
        } else {
          context.go('/auth/verify?email=${_emailCtrl.text.trim()}');
        }
      }
    } on AuthException catch (e) {
      setState(() => _error = _friendlyAuthError(e));
    } catch (e) {
      setState(() => _error = _friendlyGenericError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyAuthError(dynamic e) {
    if (e is AuthException) {
      final code = e.code ?? '';
      final msg = e.message.toLowerCase();
      if (code == 'user_already_exists' || msg.contains('already registered') || msg.contains('already exists')) {
        return 'An account with this email already exists. Try logging in instead.';
      }
      if (code == 'weak_password' || msg.contains('password')) {
        return 'Password is too weak. Use at least 6 characters.';
      }
      if (code == 'invalid_email' || msg.contains('invalid email')) {
        return 'Please enter a valid email address.';
      }
      if (msg.contains('rate limit') || msg.contains('too many')) {
        return 'Too many attempts. Please wait a moment and try again.';
      }
      if (msg.contains('network') || msg.contains('connection')) {
        return 'No internet connection. Please check your network.';
      }
    }
    return 'Something went wrong. Please try again.';
  }

  String _friendlyGenericError(dynamic e) {
    final str = e.toString().toLowerCase();
    if (str.contains('duplicate') || str.contains('unique') || str.contains('23505')) {
      if (str.contains('username')) return 'This username is already taken. Please choose another.';
      if (str.contains('email')) return 'An account with this email already exists.';
      if (str.contains('phone')) return 'This phone number is already registered.';
      return 'Some of your details are already in use. Please check and try again.';
    }
    if (str.contains('database error saving new user') || str.contains('unexpected_failure')) {
      return 'Could not create your account. This username or email may already be taken.';
    }
    if (str.contains('socketexception') || str.contains('network') || str.contains('connection')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (str.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    return 'Something went wrong. Please try again.';
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
                  const SizedBox(height: 12),
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: AppRadius.xl,
                    ),
                    child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 14),
                  const Text('Join NotesNet', style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.white, 
                      borderRadius: AppRadius.xxl,
                      boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 32)]),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Role Switcher
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: AppRadius.md,
                            ),
                            child: Row(
                              children: [
                                Expanded(child: _roleButton('student', 'Student', Icons.school_rounded)),
                                Expanded(child: _roleButton('teacher', 'Teacher', Icons.assignment_ind_rounded)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _field('Full Name', _nameCtrl, Icons.badge_rounded, theme, validator: (v) => v!.isEmpty ? 'Required' : null),
                          const SizedBox(height: 12),
                          _field(_role == 'student' ? 'School/College Name' : 'Institution', _institutionCtrl, Icons.school_outlined, theme, validator: (v) => v!.isEmpty ? 'Required' : null),
                          const SizedBox(height: 12),
                          if (_role == 'teacher') ...[
                            _field('Specialization (Subjects)', _specializationCtrl, Icons.stars_rounded, theme, 
                              validator: (v) => v!.isEmpty ? 'Required' : null),
                            const SizedBox(height: 12),
                            _field('LinkedIn Profile URL', _linkedinCtrl, Icons.link_rounded, theme, 
                              validator: (v) => v!.isEmpty ? 'Required for verification' : null),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: _pickIdCard,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
                                  borderRadius: AppRadius.md,
                                ),
                                child: Column(
                                  children: [
                                    if (_idCardFile != null) ...[
                                      ClipRRect(
                                        borderRadius: AppRadius.sm,
                                        child: Image.file(_idCardFile!, height: 120, width: double.infinity, fit: BoxFit.cover),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    Row(
                                      children: [
                                        Icon(Icons.upload_file_rounded, color: isDark ? Colors.white70 : AppColors.textMuted),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _idCardFile == null ? 'Upload ID Card (Image)' : 'Change ID Card',
                                            style: TextStyle(color: _idCardFile == null ? (isDark ? Colors.white70 : AppColors.textMuted) : AppColors.primary),
                                          ),
                                        ),
                                        if (_idCardFile != null) const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          _field('Phone Number', _phoneCtrl, Icons.phone_android_rounded, theme, 
                            keyboardType: TextInputType.phone,
                            validator: (v) => v!.isEmpty ? 'Required' : null),
                          const SizedBox(height: 12),
                          _field('Username', _usernameCtrl, Icons.alternate_email_rounded, theme,
                            validator: (v) => (v?.length ?? 0) < 3 ? 'Min 3 characters' : null),
                          const SizedBox(height: 12),
                          _field('Email', _emailCtrl, Icons.email_outlined, theme,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => v?.contains('@') == false ? 'Invalid email' : null),
                          const SizedBox(height: 12),
                          _field('Password', _passCtrl, Icons.lock_outline_rounded, theme,
                            obscure: _obscure,
                            toggleObscure: () => setState(() => _obscure = !_obscure),
                            validator: (v) {
                              if ((v?.length ?? 0) < 8) return 'Min 8 characters';
                              if (!RegExp(r'[A-Z]').hasMatch(v!)) return 'Add at least 1 uppercase letter';
                              if (!RegExp(r'[0-9]').hasMatch(v)) return 'Add at least 1 number';
                              return null;
                            }),
                          const SizedBox(height: 12),
                          _field('Confirm Password', _confirmPassCtrl, Icons.lock_rounded, theme,
                            obscure: _obscureConfirm,
                            toggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            validator: (v) => v != _passCtrl.text ? 'Passwords do not match' : null),
                          if (_role == 'student') ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _board,
                              dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
                              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
                              decoration: const InputDecoration(labelText: 'Board',
                                prefixIcon: Icon(Icons.school_rounded)),
                              items: AppConstants.boards.map((b) =>
                                DropdownMenuItem(value: b, child: Text(b))).toList(),
                              onChanged: (v) => setState(() => _board = v!),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _classLevel,
                              dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
                              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
                              decoration: const InputDecoration(labelText: 'Class',
                                prefixIcon: Icon(Icons.class_)),
                              items: AppConstants.classLevels.map((c) =>
                                DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (v) => setState(() => _classLevel = v!),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.08),
                                borderRadius: AppRadius.sm,
                              ),
                              child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                            ),
                          ],
                          const SizedBox(height: 20),
                          PrimaryButton(label: 'Create Account', onPressed: _signup, isLoading: _loading),
                          const SizedBox(height: 16),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('Already have an account? ', 
                              style: AppText.bodyMedium.copyWith(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
                            GestureDetector(
                              onTap: () => context.go('/auth/login'),
                              child: const Text('Login', style: TextStyle(
                                color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleButton(String value, String label, IconData icon) {
    final isSelected = _role == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _role = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? AppColors.primary : Colors.white) : Colors.transparent,
          borderRadius: AppRadius.md,
          boxShadow: isSelected && !isDark ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? (isDark ? Colors.white : AppColors.primary) : (isDark ? Colors.white54 : Colors.black54)),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: isSelected ? (isDark ? Colors.white : AppColors.primary) : (isDark ? Colors.white54 : Colors.black54)
            )),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon, ThemeData theme, {
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false, VoidCallback? toggleObscure,
    String? Function(String?)? validator,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return TextFormField(
      controller: ctrl, keyboardType: keyboardType, obscureText: obscure,
      style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white70 : AppColors.textMuted),
        prefixIcon: Icon(icon),
        suffixIcon: toggleObscure != null
          ? IconButton(icon: Icon(obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
              onPressed: toggleObscure)
          : null,
      ),
      validator: validator,
    );
  }
}

