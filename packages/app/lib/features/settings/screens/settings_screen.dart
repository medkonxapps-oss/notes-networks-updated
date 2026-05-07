import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';
import '../../../shared/providers/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProfileProvider).value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        title: Text('Settings',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textPrimary
            )),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null)
            GestureDetector(
              onTap: () => context.push('/profile/me'),
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: AppRadius.lg,
                  border: Border.all(color: isDark ? Colors.grey.withValues(alpha: 0.2) : AppColors.border),
                ),
                child: Row(children: [
                  AppAvatar(imageUrl: user.avatarUrl, name: user.fullName, size: 52, isVerified: user.isVerifiedCreator),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.fullName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimary)),
                        Text('@${user.username}', style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMuted)),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.stars_rounded, size: 14, color: AppColors.accent),
                          Text(' ${user.totalPoints} pts', style: const TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w700)),
                        ]),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),     
                ]),
              ),
            ),

          _sectionLabel('Account', isDark),
          _tile(icon: Icons.person_rounded, label: 'Edit Profile', onTap: () => context.push('/profile/edit')),
          _tile(icon: Icons.lock_rounded, label: 'Change Password', onTap: () => context.push('/settings/password')),
          _tile(icon: Icons.notifications_rounded, label: 'Notification Preferences', onTap: () => context.push('/settings/notifications')),
          _tile(icon: Icons.privacy_tip_rounded, label: 'Privacy Settings', onTap: () => context.push('/settings/privacy')),

          const SizedBox(height: 16),
          _sectionLabel('Appearance', isDark),
          Consumer(builder: (context, ref, _) {
            final themeMode = ref.watch(themeProvider);
            final viewMode = ref.watch(feedViewModeProvider);
            return Column(
              children: [
                _tile(
                  icon: themeMode == ThemeMode.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  label: 'Dark Mode',
                  trailing: Switch.adaptive(
                    value: themeMode == ThemeMode.dark,
                    onChanged: (v) { ref.read(themeProvider.notifier).setTheme(v ? ThemeMode.dark : ThemeMode.light); },
                    activeTrackColor: AppColors.primary,
                  ),
                  onTap: () { ref.read(themeProvider.notifier).setTheme(themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark); },
                ),
                _tile(
                  icon: Icons.grid_view_rounded,
                  label: 'Grid View (Feed)',
                  subtitle: 'Show notes in a grid instead of a list',
                  trailing: Switch.adaptive(
                    value: viewMode == FeedViewMode.grid,
                    onChanged: (v) { ref.read(feedViewModeProvider.notifier).setViewMode(v ? FeedViewMode.grid : FeedViewMode.list); },
                    activeTrackColor: AppColors.primary,
                  ),
                  onTap: () { ref.read(feedViewModeProvider.notifier).setViewMode(viewMode == FeedViewMode.grid ? FeedViewMode.list : FeedViewMode.grid); },
                ),
              ],
            );
          }),

          const SizedBox(height: 16),
          _sectionLabel('Content', isDark),
          _tile(icon: Icons.folder_rounded, label: 'Manage Folders', subtitle: 'Create and organise your note folders', onTap: () => context.push('/profile/me')),
          _tile(icon: Icons.bookmark_rounded, label: 'Saved Notes', subtitle: 'Notes you\'ve bookmarked', onTap: () => context.push('/library?tab=saved')),
          _tile(icon: Icons.favorite_rounded, label: 'Liked Notes', subtitle: 'Notes you\'ve liked', onTap: () => context.push('/library?tab=liked')),
          _tile(icon: Icons.download_rounded, label: 'Downloaded Notes', onTap: () => context.push('/settings/downloads')),
          _tile(icon: Icons.settings_suggest_rounded, label: 'Download Settings', onTap: () => _showDownloadSettings(context)),

          const SizedBox(height: 16),
          _sectionLabel('Rewards', isDark),
          _tile(icon: Icons.stars_rounded, label: 'My Points & Badges', onTap: () => context.push('/rewards')),
          _tile(icon: Icons.leaderboard_rounded, label: 'Leaderboard', onTap: () => context.push('/leaderboard')),

          const SizedBox(height: 16),
          _sectionLabel('Support', isDark),
          _tile(icon: Icons.help_rounded, label: 'Help & FAQ', onTap: () => context.push('/settings/help')),
          _tile(icon: Icons.report_rounded, label: 'Report a Problem', onTap: () => context.push('/settings/report')),
          _tile(icon: Icons.info_rounded, label: 'About NotesNet', onTap: () => context.push('/settings/about')),

          const SizedBox(height: 16),
          _sectionLabel('Account Action', isDark),
          _tile(icon: Icons.logout_rounded, label: 'Sign Out', color: AppColors.danger, onTap: () => _signOut(context)),

          const SizedBox(height: 32),
          Center(child: Text('NotesNet v1.0.0', style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMuted))),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showDownloadSettings(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Download Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.textPrimary)),
            const SizedBox(height: 16),
            _settingsToggle(
              context,
              label: 'Notify on my notes downloaded',
              subtitle: 'Get notified when someone downloads your note for offline',
              value: true, // Mock value, in real app bind to actual user settings
              onChanged: (v) {},
            ),
            _settingsToggle(
              context,
              label: 'Notify on my notes saved',
              subtitle: 'Get notified when someone bookmarks your note',
              value: true,
              onChanged: (v) {},
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _settingsToggle(BuildContext context, {required String label, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimary)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMuted)),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged, activeTrackColor: AppColors.primary),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
        title: Text('Sign Out?', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
        content: Text('Are you sure you want to sign out?', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(dialogCtx).pop(true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger), child: const Text('Sign Out')),
        ],
      ),
    );
    if (confirmed == true) { 
      await ref.read(authServiceProvider).signOut(); 
      
      // Invalidate key providers to clear cache
      ref.invalidate(currentUserProfileProvider);
      ref.invalidate(feedProvider);
      ref.invalidate(interactionProvider);
      ref.invalidate(followProvider);
      ref.invalidate(unreadNotifCountProvider);
      ref.invalidate(unreadChatCountProvider);
      ref.invalidate(chatRoomsProvider);
      ref.invalidate(savedNotesProvider);
      ref.invalidate(likedNotesProvider);
      
      if (!context.mounted) return; 
      GoRouter.of(context).go('/auth/login'); 
    }
  }

  Widget _sectionLabel(String label, bool isDark) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(label.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? AppColors.textMutedDark : AppColors.textMuted, letterSpacing: 1.2)),
      );

  Widget _tile({required IconData icon, required String label, String? subtitle, Color? color, Widget? trailing, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = color ?? (isDark ? Colors.white : AppColors.textPrimary);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: theme.cardTheme.color, borderRadius: AppRadius.md, border: Border.all(color: isDark ? Colors.grey.withValues(alpha: 0.2) : AppColors.border)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Icon(icon, color: c, size: 22),
        title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c)),
        subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMuted)) : null,
        trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: isDark ? AppColors.textMutedDark : AppColors.textMuted, size: 20),
        onTap: onTap,
      ),
    );
  }
}
