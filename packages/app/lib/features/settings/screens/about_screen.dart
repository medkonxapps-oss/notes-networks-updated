import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        title: Text('About NotesNet',
            style: TextStyle(
              fontWeight: FontWeight.w700, 
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary
            )),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Logo
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: AppRadius.xl,
              ),
              child: const Icon(Icons.sticky_note_2_rounded, color: Colors.white, size: 52),
            ),
            const SizedBox(height: 16),
            Text('NotesNet', style: theme.textTheme.displayMedium),
            const SizedBox(height: 4),
            Text('Version 1.0.0', style: theme.textTheme.bodySmall),
            const SizedBox(height: 32),

            _infoCard(
              context,
              icon: Icons.info_outline_rounded,
              title: 'About',
              body:
                  'NotesNet is a platform for students to share, discover, and collaborate on study notes. Upload your notes, earn points, and help others learn.',
            ),
            const SizedBox(height: 16),
            _infoCard(
              context,
              icon: Icons.stars_rounded,
              title: 'Earn Points',
              body:
                  'Upload notes (+50 pts), receive likes (+5 pts), receive saves (+10 pts), maintain daily streaks (+25 pts), and get verified (+200 pts).',
            ),
            const SizedBox(height: 16),
            _linkTile(
              context,
              icon: Icons.privacy_tip_rounded,
              label: 'Privacy Policy',
              url: 'https://notesnet.app/privacy',
            ),
            _linkTile(
              context,
              icon: Icons.description_rounded,
              label: 'Terms of Service',
              url: 'https://notesnet.app/terms',
            ),
            _linkTile(
              context,
              icon: Icons.mail_rounded,
              label: 'Contact Us',
              url: 'mailto:support@notesnet.app',
            ),
            const SizedBox(height: 32),
            Text('Made with ❤️ for students', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Text('© 2025 NotesNet', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(BuildContext context, {required IconData icon, required String title, required String body}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: AppRadius.lg,
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(title, style: theme.textTheme.titleMedium),
          ]),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _linkTile(BuildContext context, {required IconData icon, required String label, required String url}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: AppRadius.md,
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary, size: 22),
        title: Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.open_in_new_rounded, color: isDark ? AppColors.textMutedDark : AppColors.textMuted, size: 18),
        onTap: () async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) await launchUrl(uri);
        },
      ),
    );
  }
}
