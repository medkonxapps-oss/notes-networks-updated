import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/providers/providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _institutionCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  String? _board;
  String? _classLevel;
  bool _loading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _institutionCtrl.dispose();
    _phoneCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  void _init(dynamic user) {
    if (_initialized) return;
    _nameCtrl.text = user.fullName;
    _usernameCtrl.text = user.username;
    _institutionCtrl.text = user.institutionName ?? '';
    _phoneCtrl.text = user.phone ?? '';
    _bioCtrl.text = user.bio ?? '';
    _cityCtrl.text = user.city ?? '';
    _board = user.board;
    _classLevel = user.classLevel;
    _initialized = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final uid = ref.read(supabaseClientProvider).auth.currentUser!.id;
      await ref.read(authServiceProvider).updateProfile(uid, {
        'full_name': _nameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim().toLowerCase(),
        'institution_name': _institutionCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'board': _board,
        'class_level': _classLevel,
      });
      ref.invalidate(profileProvider(uid));
      ref.invalidate(currentUserProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile updated!'),
          backgroundColor: AppColors.success,
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;

    // Crop the image
    final cropped = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppColors.primary,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Crop Photo',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
    if (cropped == null) return;

    final bytes = await cropped.readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Image size must be less than 2MB'),
          backgroundColor: AppColors.danger,
        ));
      }
      return;
    }

    setState(() => _loading = true);
    try {
      final uid = ref.read(supabaseClientProvider).auth.currentUser!.id;
      final newUrl = await ref.read(authServiceProvider).uploadAvatar(uid, bytes);
      // Evict the old cached image so the new one shows immediately
      if (newUrl != null) {
        await CachedNetworkImage.evictFromCache(AppAvatar.cacheKeyFor(newUrl));
      }
      ref.invalidate(profileProvider(uid));
      ref.invalidate(currentUserProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile picture updated!'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to update profile picture. Please try again.'),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeAvatar(String currentUrl) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
          title: Text('Remove Photo',
              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary)),
          content: Text('Are you sure you want to remove your profile picture?',
              style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      final uid = ref.read(supabaseClientProvider).auth.currentUser!.id;
      
      // 1. Clear avatar_url in DB using a more direct update to ensure it's set to null
      await ref.read(supabaseClientProvider)
          .from('users')
          .update({'avatar_url': null, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', uid);

      // 2. Try to remove the file from storage as well to keep things clean
      try {
        await ref.read(supabaseClientProvider).storage.from('avatars').remove(['$uid/avatar.jpg']);
      } catch (_) {
        // Non-critical: failure to delete from storage shouldn't stop the process
      }

      // 3. Evict from image cache
      await CachedNetworkImage.evictFromCache(AppAvatar.cacheKeyFor(currentUrl));
      
      // 4. Force refresh the profile
      ref.invalidate(currentUserProfileProvider);
      ref.invalidate(profileProvider(uid));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile picture removed.'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Shows a bottom sheet with View / Change / Remove options when a photo
  /// already exists, or goes straight to the picker when there is none.
  void _showAvatarOptions(String? currentUrl) {
    if (currentUrl == null || currentUrl.isEmpty) {
      _pickAvatar();
      return;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.borderDark : AppColors.border,
                borderRadius: AppRadius.full,
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.visibility_rounded, color: AppColors.primary, size: 20),
              ),
              title: Text('View Photo',
                  style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(ctx);
                AppAvatar.openFullScreenStatic(context, currentUrl,
                    ref.read(currentUserProfileProvider).value?.fullName ?? '');
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary, size: 20),
              ),
              title: Text('Change Photo',
                  style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAvatar();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
              ),
              title: const Text('Remove Photo',
                  style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(ctx);
                _removeAvatar(currentUrl);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return profileAsync.when(
      loading: () => Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary))),
      error: (e, _) => Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(child: Text(e.toString(), style: TextStyle(color: isDark ? Colors.white : Colors.black)))),
      data: (user) {
        if (user == null) {
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: const Center(child: Text('Not logged in')));
        }
        _init(user);
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: theme.appBarTheme.backgroundColor,
            title: Text('Edit Profile',
                style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.textPrimary)),
            actions: [
              TextButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                    : const Text('Save', style: TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _loading ? null : () => _showAvatarOptions(user.avatarUrl),
                          child: Stack(
                            children: [
                              AppAvatar(
                                imageUrl: user.avatarUrl,
                                name: user.fullName,
                                size: 88,
                                isVerified: user.isVerifiedCreator,
                              ),
                              Positioned(
                                bottom: 0, right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary, shape: BoxShape.circle),
                                  child: Icon(
                                    user.avatarUrl != null ? Icons.edit_rounded : Icons.add_a_photo_rounded,
                                    color: Colors.white, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _loading ? null : () => _showAvatarOptions(user.avatarUrl),
                          icon: Icon(
                            user.avatarUrl != null ? Icons.camera_alt_rounded : Icons.add_a_photo_rounded,
                            size: 16),
                          label: Text(user.avatarUrl != null ? 'Change Photo' : 'Add Photo'),
                          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _field('Full Name', _nameCtrl, Icons.badge_rounded, theme,
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                  const SizedBox(height: 14),
                  _field('School/College Name', _institutionCtrl, Icons.school_outlined, theme,
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                  const SizedBox(height: 14),
                  _field('Phone Number', _phoneCtrl, Icons.phone_android_rounded, theme,
                      keyboardType: TextInputType.phone,
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                  const SizedBox(height: 14),
                  _field('Username', _usernameCtrl, Icons.alternate_email_rounded, theme,
                      validator: (v) => (v?.length ?? 0) < 3 ? 'Min 3 characters' : null),
                  const SizedBox(height: 14),
                  _field('Bio', _bioCtrl, Icons.info_outline_rounded, theme, maxLines: 3),
                  const SizedBox(height: 14),
                  _field('City', _cityCtrl, Icons.location_on_rounded, theme),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _board,
                    dropdownColor: theme.cardTheme.color,
                    style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
                    decoration: const InputDecoration(
                        labelText: 'Board', prefixIcon: Icon(Icons.school_rounded)),
                    items: AppConstants.boards
                        .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    onChanged: (v) => setState(() => _board = v),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _classLevel,
                    dropdownColor: theme.cardTheme.color,
                    style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
                    decoration: const InputDecoration(
                        labelText: 'Class Level', prefixIcon: Icon(Icons.class_)),
                    items: AppConstants.classLevels
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _classLevel = v),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon, ThemeData theme,
      {int maxLines = 1, TextInputType keyboardType = TextInputType.text, String? Function(String?)? validator}) {
    final isDark = theme.brightness == Brightness.dark;
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white70 : AppColors.textMuted),
        prefixIcon: Icon(icon),
      ),
      validator: validator,
    );
  }
}
