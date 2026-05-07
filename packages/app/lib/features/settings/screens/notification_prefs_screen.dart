import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:design_system/design_system.dart';
import '../../../shared/providers/providers.dart';

// Simple local prefs stored in Supabase users table (fcm_token / notification flags)
// For now we store preferences as a JSON in the users table via a simple update
class NotificationPrefsScreen extends ConsumerStatefulWidget {
  const NotificationPrefsScreen({super.key});
  @override
  ConsumerState<NotificationPrefsScreen> createState() =>
      _NotificationPrefsScreenState();
}

class _NotificationPrefsScreenState
    extends ConsumerState<NotificationPrefsScreen> {
  bool _likes = true;
  bool _saves = true;
  bool _follows = true;
  bool _rewards = true;
  bool _streaks = true;
  bool _system = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (uid == null) return;
      final data = await ref.read(supabaseClientProvider)
          .from('users')
          .select('notification_preferences')
          .eq('id', uid)
          .maybeSingle();
      final prefs = data?['notification_preferences'] as Map<String, dynamic>?;
      if (prefs != null && mounted) {
        setState(() {
          _likes = prefs['likes'] as bool? ?? true;
          _saves = prefs['saves'] as bool? ?? true;
          _follows = prefs['follows'] as bool? ?? true;
          _rewards = prefs['rewards'] as bool? ?? true;
          _streaks = prefs['streaks'] as bool? ?? true;
          _system = prefs['system'] as bool? ?? true;
        });
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (uid == null) return;
      await ref.read(supabaseClientProvider).from('users').update({
        'notification_preferences': {
          'likes': _likes,
          'saves': _saves,
          'follows': _follows,
          'rewards': _rewards,
          'streaks': _streaks,
          'system': _system,
        },
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Preferences saved!'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: AppColors.danger,
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
        title: Text('Notification Preferences',
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
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D2D4D) : AppColors.primarySurface, 
              borderRadius: AppRadius.md
            ),
            child: Row(children: [
              const Icon(Icons.notifications_active_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Choose which notifications you want to receive.',
                  style: TextStyle(
                    color: isDark ? AppColors.primaryLight : AppColors.primary, 
                    fontSize: 13
                  ),
                ),
              ),
            ]),
          ),
          _sectionLabel(context, 'Activity'),
          _toggle(
            context,
            icon: Icons.favorite_rounded,
            color: AppColors.like,
            label: 'Likes',
            subtitle: 'When someone likes your note',
            value: _likes,
            onChanged: (v) => setState(() => _likes = v),
          ),
          _toggle(
            context,
            icon: Icons.bookmark_rounded,
            color: AppColors.save,
            label: 'Saves',
            subtitle: 'When someone saves your note',
            value: _saves,
            onChanged: (v) => setState(() => _saves = v),
          ),
          _toggle(
            context,
            icon: Icons.person_add_rounded,
            color: AppColors.primary,
            label: 'New Followers',
            subtitle: 'When someone follows you',
            value: _follows,
            onChanged: (v) => setState(() => _follows = v),
          ),
          const SizedBox(height: 16),
          _sectionLabel(context, 'Rewards & Streaks'),
          _toggle(
            context,
            icon: Icons.card_giftcard_rounded,
            color: AppColors.accent,
            label: 'Rewards',
            subtitle: 'Points earned and redemption updates',
            value: _rewards,
            onChanged: (v) => setState(() => _rewards = v),
          ),
          _toggle(
            context,
            icon: Icons.local_fire_department_rounded,
            color: AppColors.danger,
            label: 'Streak Reminders',
            subtitle: 'Daily reminders to maintain your streak',
            value: _streaks,
            onChanged: (v) => setState(() => _streaks = v),
          ),
          const SizedBox(height: 16),
          _sectionLabel(context, 'System'),
          _toggle(
            context,
            icon: Icons.notifications_rounded,
            color: AppColors.textSecondary,
            label: 'System Notifications',
            subtitle: 'App updates and announcements',
            value: _system,
            onChanged: (v) => setState(() => _system = v),
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
    required Color color,
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
        secondary: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
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
}
