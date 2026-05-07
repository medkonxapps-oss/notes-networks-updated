import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/providers/providers.dart';

class EducationSetupScreen extends ConsumerStatefulWidget {
  const EducationSetupScreen({super.key});
  @override
  ConsumerState<EducationSetupScreen> createState() => _EducationSetupScreenState();
}

class _EducationSetupScreenState extends ConsumerState<EducationSetupScreen> {
  String _board = 'CBSE';
  String _classLevel = 'Class 10';
  final Set<String> _subjects = {};
  bool _loading = false;

  Future<void> _next() async {
    if (_subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Select at least one subject'), backgroundColor: AppColors.danger));
      return;
    }
    setState(() => _loading = true);
    try {
      final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (uid != null) {
        await ref.read(authServiceProvider).updateProfile(uid, {
          'board': _board, 'class_level': _classLevel,
          'subjects': _subjects.toList(),
        });
      }
      if (mounted) context.go('/onboarding/photo');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Education'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: 0.66, backgroundColor: AppColors.border, color: AppColors.primary),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your Education', style: AppText.headlineLarge),
                  const SizedBox(height: 6),
                  const Text('We\'ll show you relevant notes', style: AppText.bodyMedium),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    initialValue: _board,
                    decoration: const InputDecoration(labelText: 'Board'),
                    items: AppConstants.boards.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                    onChanged: (v) => setState(() => _board = v!),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _classLevel,
                    decoration: const InputDecoration(labelText: 'Class / Year'),
                    items: AppConstants.classLevels.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _classLevel = v!),
                  ),
                  const SizedBox(height: 24),
                  const Text('Your Subjects', style: AppText.titleLarge),
                  const SizedBox(height: 6),
                  const Text('Select all that apply', style: AppText.bodyMedium),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: AppConstants.subjects.map((s) => TagChip(
                      label: s,
                      isSelected: _subjects.contains(s),
                      onTap: () => setState(() {
                        _subjects.contains(s) ? _subjects.remove(s) : _subjects.add(s);
                      }),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: PrimaryButton(label: 'Continue', onPressed: _next, isLoading: _loading),
          ),
        ],
      ),
    );
  }
}
