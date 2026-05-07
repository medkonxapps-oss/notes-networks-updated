import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _faqs = const [
    _FAQ(
      q: 'How do I upload notes?',
      a: 'Tap the + button at the bottom of the screen. Select your PDF or images, fill in the details, and tap "Upload Notes".',
    ),
    _FAQ(
      q: 'What file types are supported?',
      a: 'We support PDF files and image sets (JPG, PNG). Maximum file size is 50MB.',
    ),
    _FAQ(
      q: 'How do I earn points?',
      a: 'Upload notes (+50 pts), receive likes (+5 pts), receive saves (+10 pts), maintain daily upload streaks (+25 pts), first upload ever (+100 pts), get verified (+200 pts).',
    ),
    _FAQ(
      q: 'How do I redeem rewards?',
      a: 'Go to Rewards Center from the home screen. Once you have enough points, tap "Redeem" on any reward.',
    ),
    _FAQ(
      q: 'How do I create folders?',
      a: 'Go to your Profile, switch to the Folders tab, and tap the "New Folder" button.',
    ),
    _FAQ(
      q: 'Can I make my notes private?',
      a: 'Yes! When uploading, set Visibility to "Followers Only" so only your followers can see your notes.',
    ),
    _FAQ(
      q: 'How do I get verified?',
      a: 'Upload quality notes consistently. Our team reviews creators and grants verification badges manually.',
    ),
    _FAQ(
      q: 'How do I report inappropriate content?',
      a: 'Tap the Info button on any note, then tap "Report". Select a reason and submit.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        title: Text('Help & FAQ',
            style: TextStyle(
              fontWeight: FontWeight.w700, 
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary
            )),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D2D4D) : AppColors.primarySurface,
              borderRadius: AppRadius.lg,
            ),
            child: Row(children: [
              const Icon(Icons.help_outline_rounded, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Find answers to common questions below.',
                  style: TextStyle(
                    color: isDark ? AppColors.primaryLight : AppColors.primary, 
                    fontWeight: FontWeight.w500
                  ),
                ),
              ),
            ]),
          ),
          ..._faqs.map((faq) => _FAQTile(faq: faq)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: AppRadius.lg,
              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
            ),
            child: Column(
              children: [
                Text('Still need help?', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Contact our support team',
                    style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.mail_rounded),
                  label: const Text('support@notesnet.app'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _FAQ {
  final String q;
  final String a;
  const _FAQ({required this.q, required this.a});
}

class _FAQTile extends StatefulWidget {
  final _FAQ faq;
  const _FAQTile({required this.faq});
  @override
  State<_FAQTile> createState() => _FAQTileState();
}

class _FAQTileState extends State<_FAQTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: AppRadius.md,
        border: Border.all(
          color: _expanded ? AppColors.primary.withValues(alpha: 0.4) : (isDark ? AppColors.borderDark : AppColors.border),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(widget.faq.q,
              style: TextStyle(
                fontSize: 14, 
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary
              )),
          iconColor: AppColors.primary,
          collapsedIconColor: isDark ? AppColors.textMutedDark : AppColors.textMuted,
          onExpansionChanged: (v) => setState(() => _expanded = v),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(widget.faq.a, style: theme.textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}
