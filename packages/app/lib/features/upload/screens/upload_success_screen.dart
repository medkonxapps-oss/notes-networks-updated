import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:design_system/design_system.dart';
import '../../../shared/providers/providers.dart';

class UploadSuccessScreen extends ConsumerStatefulWidget {
  final String noteId;
  const UploadSuccessScreen({super.key, required this.noteId});
  @override
  ConsumerState<UploadSuccessScreen> createState() => _UploadSuccessScreenState();
}

class _UploadSuccessScreenState extends ConsumerState<UploadSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  String _status = 'processing';

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack);
    _animCtrl.forward();
    _checkAndWatchStatus();
  }

  Future<void> _checkAndWatchStatus() async {
    final note = await ref.read(notesServiceProvider).getNoteById(widget.noteId);
    if (note != null && mounted) {
      setState(() => _status = note.status);
      // pending_review and active are both terminal — no need to watch
      if (note.status == 'active' || note.status == 'pending_review') return;
    }

    // Watch for realtime status changes
    ref.read(notesServiceProvider).watchNoteStatus(widget.noteId).listen((s) {
      if (mounted) setState(() => _status = s);
    });

    // Timeout fallback for processing state
    await Future.delayed(const Duration(seconds: 15));
    if (mounted && _status == 'processing') {
      setState(() => _status = 'active');
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPending = _status == 'pending_review';
    final isActive = _status == 'active';
    final isProcessing = !isPending && !isActive;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.success.withValues(alpha: 0.15)
                        : isPending
                            ? AppColors.warning.withValues(alpha: 0.15)
                            : (isDark ? const Color(0xFF2D2D4D) : AppColors.primarySurface),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isActive
                        ? Icons.check_circle_rounded
                        : isPending
                            ? Icons.admin_panel_settings_rounded
                            : Icons.hourglass_top_rounded,
                    size: 64,
                    color: isActive
                        ? AppColors.success
                        : isPending
                            ? AppColors.warning
                            : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              Text(
                isActive
                    ? '🎉 Notes Published!'
                    : isPending
                        ? '📋 Submitted for Review'
                        : 'Upload Successful!',
                style: theme.textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isActive
                    ? 'Your notes are now live. You earned +50 points!'
                    : isPending
                        ? 'Your notes have been submitted to our admin team for review. '
                          'You\'ll be notified once approved.'
                        : 'We\'re processing your notes. This takes about a minute.',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),

              // Processing indicator
              if (isProcessing) ...[
                const SizedBox(height: 20),
                LinearProgressIndicator(
                    color: AppColors.primary, 
                    backgroundColor: isDark ? AppColors.borderDark : AppColors.border
                ),
                const SizedBox(height: 8),
                Text('Converting pages...', style: theme.textTheme.bodySmall),
              ],

              // Active — points earned + live streak
              if (isActive) ...[
                const SizedBox(height: 16),
                _UploadRewardSummary(),
              ],

              // Pending review — what happens next
              if (isPending) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: AppRadius.md,
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.info_outline_rounded,
                            color: AppColors.warning, size: 20),
                        const SizedBox(width: 8),
                        const Text('What happens next?',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.warning)),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        '• Admin reviews your note for quality\n'
                        '• You can view and edit it in your Profile\n'
                        '• You\'ll receive a notification when approved\n'
                        '• Points are awarded after approval\n'
                        '• Usually takes 24–48 hours',
                        style: TextStyle(
                          fontSize: 13, 
                          height: 1.6,
                          color: isDark ? AppColors.textPrimaryDark.withValues(alpha: 0.8) : AppColors.textPrimary.withValues(alpha: 0.8)
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 40),

              // View note button — only if active
              if (isActive)
                PrimaryButton(
                  label: 'View Note',
                  icon: Icons.article_rounded,
                  onPressed: () => context.go('/notes/${widget.noteId}'),
                ),
              if (isActive) const SizedBox(height: 12),

              // Share button
              if (isActive)
                OutlinedButton.icon(
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(
                      text:
                          'Check out my notes on NotesNet!\nhttps://notesnet.app/notes/${widget.noteId}',
                    ),
                  ),
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    minimumSize: const Size(double.infinity, 50),
                    shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.md),
                  ),
                ),
              if (isActive) const SizedBox(height: 12),

              TextButton(
                onPressed: () => context.go('/home'),
                child: Text(
                  isPending ? 'Back to Home' : 'Go to Home',
                  style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Upload Reward Summary Widget ──────────────────────────────────────────────
// Shows real streak + points earned after a successful upload.
class _UploadRewardSummary extends ConsumerWidget {
  const _UploadRewardSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileAsync = ref.watch(currentUserProfileProvider);

    final streak = profileAsync.value?.currentStreak ?? 0;
    final isStreakDay = streak > 0;

    // Calculate what was just earned
    final int basePoints = 50;
    final int streakBonus = isStreakDay ? 25 : 0;
    final int totalJustEarned = basePoints + streakBonus;

    return Column(children: [
      // Points earned card
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.accentBg.withValues(alpha: isDark ? 0.1 : 1.0),
          borderRadius: AppRadius.md,
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.stars_rounded, color: AppColors.accent, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('+$totalJustEarned Points Earned!',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.accent)),
            if (streakBonus > 0)
              Text('Includes +$streakBonus streak bonus 🔥',
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMuted)),
            if (streakBonus == 0)
              Text('Upload tomorrow to start your streak and earn +25 bonus!',
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMuted)),
          ])),
        ]),
      ),

      // Streak card (if active)
      if (isStreakDay) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.07),
            borderRadius: AppRadius.md,
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            const Text('🔥', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$streak-Day Streak!',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.warning)),
              Text(_streakMotivation(streak),
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMuted)),
            ])),
            // Next milestone indicator
            if (_nextMilestone(streak) != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15), borderRadius: AppRadius.full),
                child: Text(
                  '${_nextMilestone(streak)! - streak}d to 🏅',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.warning),
                ),
              ),
          ]),
        ),
      ],
    ]);
  }

  String _streakMotivation(int streak) {
    if (streak >= 30) return 'Incredible! You\'re a Month Master! 🥇';
    if (streak >= 14) return 'Amazing dedication! Keep it up!';
    if (streak >= 7) return 'Week Warrior! You\'re on fire! 🏅';
    if (streak >= 3) return 'Great consistency! Keep going!';
    return 'Nice start! Upload daily for bonus points.';
  }

  int? _nextMilestone(int streak) {
    for (final m in [7, 14, 30, 60, 100]) {
      if (streak < m) return m;
    }
    return null;
  }
}
