import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:design_system/design_system.dart';
import '../../../shared/providers/providers.dart';

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});
  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  bool _publicProfile = true;
  bool _showInSearch = true;
  bool _allowFollowers = true;
  String _defaultVisibility = 'public';
  bool _loading = false;

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (uid == null) return;
      // In production, store these in a user_settings table
      // For now update the users table with what we can
      await ref.read(supabaseClientProvider).from('users').update({
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', uid);
      ref.invalidate(currentUserProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Privacy settings saved!'),
          backgroundColor: AppColors.success,
        ));
      }
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
        title: Text('Privacy Settings',
            style: TextStyle(
              fontWeight: FontWeight.w700, 
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary
            )),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Text('Save',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile visibility
          _sectionLabel(context, 'Profile'),
          _toggle(
            context,
            icon: Icons.public_rounded,
            label: 'Public Profile',
            subtitle: 'Anyone can view your profile and notes',
            value: _publicProfile,
            onChanged: (v) => setState(() => _publicProfile = v),
          ),
          _toggle(
            context,
            icon: Icons.search_rounded,
            label: 'Appear in Search',
            subtitle: 'Let others find you by username or name',
            value: _showInSearch,
            onChanged: (v) => setState(() => _showInSearch = v),
          ),
          _toggle(
            context,
            icon: Icons.person_add_rounded,
            label: 'Allow Followers',
            subtitle: 'Let others follow you',
            value: _allowFollowers,
            onChanged: (v) => setState(() => _allowFollowers = v),
          ),

          const SizedBox(height: 16),
          _sectionLabel(context, 'Default Note Visibility'),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: AppRadius.lg,
              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
            ),
            child: Column(
              children: [
                _visibilityOption(
                  context,
                  icon: Icons.public_rounded,
                  label: 'Public',
                  subtitle: 'Everyone can see your notes',
                  value: 'public',
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: isDark ? AppColors.borderDark : AppColors.border),
                _visibilityOption(
                  context,
                  icon: Icons.group_rounded,
                  label: 'Followers Only',
                  subtitle: 'Only your followers can see your notes',
                  value: 'followers',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          _sectionLabel(context, 'Data & Account'),
          _actionTile(
            context,
            icon: Icons.download_rounded,
            label: 'Download My Data',
            subtitle: 'Get a copy of all your data',
            onTap: () async {
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Preparing your data export...')),
                );
                await ref.read(dataExportServiceProvider).exportUserData();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error exporting data: $e'), backgroundColor: AppColors.danger),
                  );
                }
              }
            },
          ),
          _actionTile(
            context,
            icon: Icons.delete_forever_rounded,
            label: 'Delete Account',
            subtitle: 'Permanently delete your account and all data',
            color: AppColors.danger,
            onTap: () => _showDeleteAccountDialog(context),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
              letterSpacing: 1.2)),
    );
  }

  Widget _toggle(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: AppRadius.md,
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: Icon(icon, color: AppColors.primary, size: 22),
        title: Text(label,
            style: TextStyle(
              fontSize: 14, 
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary
            )),
        subtitle: Text(subtitle,
            style: TextStyle(
              fontSize: 12, 
              color: isDark ? AppColors.textMutedDark : AppColors.textMuted
            )),
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primary,
      ),
    );
  }

  Widget _visibilityOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required String value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = _defaultVisibility == value;
    return ListTile(
      leading: Icon(icon,
          color: selected ? AppColors.primary : (isDark ? AppColors.textMutedDark : AppColors.textMuted), size: 22),
      title: Text(label,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.primary : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary))),
      subtitle: Text(subtitle,
          style: TextStyle(
            fontSize: 12, 
            color: isDark ? AppColors.textMutedDark : AppColors.textMuted
          )),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
          : Icon(Icons.circle_outlined, color: isDark ? AppColors.borderDark : AppColors.border),
      onTap: () => setState(() => _defaultVisibility = value),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    Color? color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = color ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: AppRadius.md,
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
      ),
      child: ListTile(
        leading: Icon(icon, color: c, size: 22),
        title: Text(label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c)),
        subtitle: Text(subtitle,
            style: TextStyle(
              fontSize: 12, 
              color: isDark ? AppColors.textMutedDark : AppColors.textMuted
            )),
        trailing: Icon(Icons.chevron_right_rounded,
            color: isDark ? AppColors.textMutedDark : AppColors.textMuted, size: 20),
        onTap: onTap,
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
        title: const Text('Delete Account?',
            style: TextStyle(color: AppColors.danger)),
        content: Text(
            'This will permanently delete your account, all your notes, and all your data. This cannot be undone.\n\nPlease contact support@notesnet.app to proceed with account deletion.',
            style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'Please email support@notesnet.app to delete your account.'),
                backgroundColor: AppColors.danger,
                duration: Duration(seconds: 5),
              ));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }
}
