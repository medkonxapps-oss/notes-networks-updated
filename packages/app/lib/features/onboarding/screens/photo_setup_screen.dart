import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:design_system/design_system.dart';
import '../../../shared/providers/providers.dart';

class PhotoSetupScreen extends ConsumerStatefulWidget {
  const PhotoSetupScreen({super.key});
  @override
  ConsumerState<PhotoSetupScreen> createState() => _PhotoSetupScreenState();
}

class _PhotoSetupScreenState extends ConsumerState<PhotoSetupScreen> {
  Uint8List? _imageBytes;
  bool _loading = false;
  final _picker = ImagePicker();

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;

    // Crop to square
    final cropped = await ImageCropper().cropImage(
      sourcePath: file.path,
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
    setState(() => _imageBytes = bytes);
  }

  Future<void> _finish() async {
    if (_imageBytes == null) {
      context.go('/home');
      return;
    }

    setState(() => _loading = true);
    try {
      final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (uid != null) {
        await ref.read(profileServiceProvider).uploadAvatar(uid, _imageBytes!);
      }
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload photo. You can update it later from your profile.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Profile Photo'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: 1.0,
            backgroundColor: AppColors.border,
            color: AppColors.primary,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Spacer(),
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  children: [
                    Container(
                      width: 160, height: 160,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2D2D4D) : AppColors.primarySurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                      ),
                      child: _imageBytes != null
                          ? ClipOval(child: Image.memory(_imageBytes!, fit: BoxFit.cover))
                          : Icon(Icons.person_rounded, size: 72, color: AppColors.primary.withValues(alpha: 0.5)),
                    ),
                    Positioned(
                      bottom: 4, right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _imageBytes != null ? Icons.edit_rounded : Icons.add_a_photo_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _imageBytes != null
                  ? 'Looking good! Tap to change.'
                  : 'Add a profile picture so people can recognize you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            PrimaryButton(label: 'Finish', onPressed: _finish, isLoading: _loading),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go('/home'),
              child: const Text('Skip for now'),
            ),
          ],
        ),
      ),
    );
  }
}
