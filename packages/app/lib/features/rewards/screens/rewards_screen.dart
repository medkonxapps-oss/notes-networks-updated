import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:design_system/design_system.dart';
import '../../../shared/providers/providers.dart';
import 'redemption_history_screen.dart';
import 'package:shared/services/rewards_service.dart';

// ── Providers ────────────────────────────────────────────────────────────────
final _streakInfoProvider = FutureProvider.autoDispose<StreakInfo>((ref) {
  ref.watch(currentUserProfileProvider); // rebuild when profile changes
  return ref.read(rewardsServiceProvider).getStreakInfo();
});

final _badgesProvider = FutureProvider.autoDispose<List<UserBadge>>((ref) {
  return ref.read(rewardsServiceProvider).getMyBadges();
});

final _pointsHistoryProvider = FutureProvider.autoDispose<List<PointsEvent>>((ref) {
  ref.watch(currentUserProfileProvider);
  return ref.read(rewardsServiceProvider).getPointsHistory();
});

// ── Main Screen ───────────────────────────────────────────────────────────────
class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});
  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  void _refresh() {
    ref.invalidate(currentUserProfileProvider);
    ref.invalidate(rewardsCatalogProvider);
    ref.invalidate(_streakInfoProvider);
    ref.invalidate(_badgesProvider);
    ref.invalidate(_pointsHistoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final streakAsync = ref.watch(_streakInfoProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Rewards Center', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.history_rounded), tooltip: 'Redemption History',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RedemptionHistoryScreen()))),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _refresh),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: '🔥 Streak'),
            Tab(text: '🎁 Redeem'),
            Tab(text: '📊 History'),
          ],
        ),
      ),
      body: Column(children: [
        // Points banner — always visible
        streakAsync.when(
          loading: () => const SizedBox(height: 4, child: LinearProgressIndicator(color: AppColors.accent)),
          error: (_, __) => const SizedBox.shrink(),
          data: (info) => _PointsBanner(info: info, isDark: isDark),
        ),
        Expanded(child: TabBarView(controller: _tabs, children: [
          _StreakTab(isDark: isDark),
          _RedeemTab(isDark: isDark, onRedeemed: _refresh),
          _HistoryTab(isDark: isDark),
        ])),
      ]),
    );
  }
}

// ── Points Banner ─────────────────────────────────────────────────────────────
class _PointsBanner extends StatelessWidget {
  final StreakInfo info;
  final bool isDark;
  const _PointsBanner({required this.info, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(children: [
        const Icon(Icons.stars_rounded, color: AppColors.accent, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Row(children: [
          Text('${info.totalPoints}', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
          const Text(' pts', style: TextStyle(color: Colors.white70, fontSize: 16)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: AppRadius.full),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('🔥', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Text('${info.currentStreak}d streak',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
      ]),
    );
  }
}

// ── Tab 1: Streak ─────────────────────────────────────────────────────────────
class _StreakTab extends ConsumerWidget {
  final bool isDark;
  const _StreakTab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(_streakInfoProvider);
    final badgesAsync = ref.watch(_badgesProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_streakInfoProvider);
        ref.invalidate(_badgesProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Streak card
          streakAsync.when(
            loading: () => _ShimmerCard(),
            error: (e, _) => _ErrorCard(message: e.toString()),
            data: (info) => _StreakCard(info: info, isDark: isDark),
          ),
          const SizedBox(height: 20),

          // How to earn
          _sectionTitle('How to Earn Points', isDark),
          const SizedBox(height: 10),
          _EarnTable(isDark: isDark),
          const SizedBox(height: 20),

          // Badges
          _sectionTitle('Your Badges', isDark),
          const SizedBox(height: 10),
          badgesAsync.when(
            loading: () => _ShimmerCard(),
            error: (_, __) => const SizedBox.shrink(),
            data: (badges) => badges.isEmpty
                ? _EmptyCard(icon: Icons.military_tech_rounded, text: 'No badges yet. Keep uploading to earn them!')
                : _BadgesGrid(badges: badges, isDark: isDark),
          ),
          const SizedBox(height: 20),

          // Milestone goals
          _sectionTitle('Streak Milestones', isDark),
          const SizedBox(height: 10),
          streakAsync.when(
            loading: () => _ShimmerCard(),
            error: (_, __) => const SizedBox.shrink(),
            data: (info) => _MilestoneList(current: info.currentStreak, isDark: isDark),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final StreakInfo info;
  final bool isDark;
  const _StreakCard({required this.info, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final uploadedToday = info.uploadedToday;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: uploadedToday
              ? [const Color(0xFF1D7A3A), const Color(0xFF0F4D24)]
              : [const Color(0xFFB45309), const Color(0xFF92400E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.xl,
        boxShadow: [BoxShadow(color: (uploadedToday ? AppColors.success : AppColors.warning).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(uploadedToday ? '✅' : '⚠️', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(
            uploadedToday ? 'Streak safe today!' : 'Upload to protect your streak!',
            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ]),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${info.currentStreak}', style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w900, height: 1)),
          const Padding(padding: EdgeInsets.only(bottom: 10, left: 6), child: Text('days', style: TextStyle(color: Colors.white70, fontSize: 20))),
          const Spacer(),
          const Text('🔥', style: TextStyle(fontSize: 56)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _StreakStat('Longest', '${info.longestStreak}d', Icons.emoji_events_rounded),
          const SizedBox(width: 24),
          _StreakStat('Notes', '${info.notesCount}', Icons.article_rounded),
          const SizedBox(width: 24),
          _StreakStat('Points', '${info.totalPoints}', Icons.stars_rounded),
        ]),
      ]),
    );
  }
}

class _StreakStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _StreakStat(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
    Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
  ]);
}

class _MilestoneList extends StatelessWidget {
  final int current;
  final bool isDark;
  const _MilestoneList({required this.current, required this.isDark});

  static const _milestones = [
    (days: 3,   label: 'First Streak',   bonus: 0,    emoji: '🌱'),
    (days: 7,   label: 'Week Warrior',   bonus: 100,  emoji: '🏅'),
    (days: 14,  label: '2-Week Hero',    bonus: 200,  emoji: '⚔️'),
    (days: 30,  label: 'Month Master',   bonus: 500,  emoji: '🥇'),
    (days: 60,  label: '2-Month Legend', bonus: 1000, emoji: '🔱'),
    (days: 100, label: 'Century Champ',  bonus: 2000, emoji: '🏆'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: _milestones.map((m) {
      final reached = current >= m.days;
      final isNext = !reached && _milestones.firstWhere((x) => x.days > current, orElse: () => _milestones.last).days == m.days;
      final progress = reached ? 1.0 : (current / m.days).clamp(0.0, 1.0);

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: reached ? AppColors.success.withValues(alpha: 0.08) : (isDark ? AppColors.surfaceDark : Colors.white),
          borderRadius: AppRadius.md,
          border: Border.all(
            color: reached ? AppColors.success.withValues(alpha: 0.4) : isNext ? AppColors.warning.withValues(alpha: 0.5) : (isDark ? AppColors.borderDark : AppColors.border),
            width: isNext ? 1.5 : 1,
          ),
        ),
        child: Column(children: [
          Row(children: [
            Text(m.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(m.label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? Colors.white : AppColors.textPrimary)),
                if (reached) ...[const SizedBox(width: 6), const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success)],
                if (isNext) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15), borderRadius: AppRadius.full), child: const Text('Next', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.warning)))],
              ]),
              Text('${m.days}-day streak${m.bonus > 0 ? ' · +${m.bonus} bonus pts' : ''}',
                  style: AppText.bodySmall.copyWith(color: AppColors.textMuted)),
            ])),
            Text('$current/${m.days}d', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: reached ? AppColors.success : AppColors.textMuted)),
          ]),
          if (!reached) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress, minHeight: 5, color: isNext ? AppColors.warning : AppColors.primary, backgroundColor: (isNext ? AppColors.warning : AppColors.primary).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          ],
        ]),
      );
    }).toList());
  }
}

class _BadgesGrid extends StatelessWidget {
  final List<UserBadge> badges;
  final bool isDark;
  const _BadgesGrid({required this.badges, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.9),
      itemCount: badges.length,
      itemBuilder: (_, i) {
        final b = badges[i];
        final icon = _badgeIcon(b.badgeType);
        final color = _badgeColor(b.badgeType);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: AppRadius.lg,
            border: Border.all(color: color.withValues(alpha: 0.3)),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 8)],
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
            const SizedBox(height: 8),
            Text(b.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.textPrimary), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
            Text(_badgeLabel(b), style: AppText.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 10), textAlign: TextAlign.center),
          ]),
        );
      },
    );
  }

  IconData _badgeIcon(String t) => switch (t) {
    'streak'       => Icons.local_fire_department_rounded,
    'upload_count' => Icons.upload_rounded,
    'total_likes'  => Icons.favorite_rounded,
    'verified'     => Icons.verified_rounded,
    'manual'       => Icons.military_tech_rounded,
    _              => Icons.star_rounded,
  };

  Color _badgeColor(String t) => switch (t) {
    'streak'       => AppColors.warning,
    'upload_count' => AppColors.primary,
    'total_likes'  => AppColors.like,
    'verified'     => AppColors.verified,
    'manual'       => AppColors.accent,
    _              => AppColors.success,
  };

  String _badgeLabel(UserBadge b) {
    if (b.milestoneValue != null) return '${b.milestoneValue} ${b.badgeType == "streak" ? "days" : "notes"}';
    return b.description;
  }
}

class _EarnTable extends StatelessWidget {
  final bool isDark;
  const _EarnTable({required this.isDark});

  static const _items = [
    ('Upload a note',       '+50 pts',  Icons.upload_rounded,          AppColors.primary),
    ('First upload ever',   '+100 pts', Icons.celebration_rounded,     AppColors.accent),
    ('Receive a like',      '+5 pts',   Icons.favorite_rounded,        AppColors.like),
    ('Receive a save',      '+10 pts',  Icons.bookmark_rounded,        AppColors.save),
    ('Note downloaded',     '+10 pts',  Icons.download_rounded,        Colors.blue),
    ('Daily streak bonus',  '+25 pts',  Icons.local_fire_department_rounded, AppColors.warning),
    ('7-day milestone',     '+100 pts', Icons.emoji_events_rounded,    AppColors.badgeGold),
    ('30-day milestone',    '+500 pts', Icons.military_tech_rounded,   AppColors.badgeGold),
    ('Get verified',        '+200 pts', Icons.verified_rounded,        AppColors.verified),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, borderRadius: AppRadius.lg, border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border)),
      child: Column(children: _items.asMap().entries.map((e) {
        final (label, pts, icon, color) = e.value;
        return Column(children: [
          if (e.key > 0) Divider(height: 1, color: isDark ? AppColors.borderDark : AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: AppRadius.sm), child: Icon(icon, color: color, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimary))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: isDark ? const Color(0xFF3D2D0B) : AppColors.accentBg, borderRadius: AppRadius.full), child: Text(pts, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800, fontSize: 12))),
            ]),
          ),
        ]);
      }).toList()),
    );
  }
}

// ── Tab 2: Redeem ─────────────────────────────────────────────────────────────
class _RedeemTab extends ConsumerWidget {
  final bool isDark;
  final VoidCallback onRedeemed;
  const _RedeemTab({required this.isDark, required this.onRedeemed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewardsAsync = ref.watch(rewardsCatalogProvider);
    final streakAsync = ref.watch(_streakInfoProvider);
    final points = streakAsync.value?.totalPoints ?? 0;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(rewardsCatalogProvider);
        ref.invalidate(_streakInfoProvider);
      },
      child: rewardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => _ErrorCard(message: e.toString()),
        data: (rewards) => rewards.isEmpty
            ? _EmptyCard(icon: Icons.redeem_rounded, text: 'No rewards available yet')
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.78),
                itemCount: rewards.length,
                itemBuilder: (ctx, i) {
                  final r = rewards[i];
                  final isUnlocked = points >= r.pointsCost;
                  final outOfStock = r.stock <= 0;

                  return Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      borderRadius: AppRadius.lg,
                      border: Border.all(color: isUnlocked && !outOfStock ? AppColors.primary.withValues(alpha: 0.3) : (isDark ? AppColors.borderDark : AppColors.border)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Image area
                      Expanded(child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF2D2D4D) : AppColors.primarySurface, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
                        child: Stack(alignment: Alignment.center, children: [
                          Icon(_rewardIcon(r.rewardType), color: AppColors.primary, size: 44),
                          if (outOfStock) Container(decoration: BoxDecoration(color: Colors.black45, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))), child: const Center(child: Text('Out of Stock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)))),
                          if (!isUnlocked && !outOfStock) Positioned(top: 8, right: 8, child: const Icon(Icons.lock_rounded, color: Colors.white70, size: 18)),
                        ]),
                      )),

                      Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isDark ? Colors.white : AppColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        if (r.stock < 50) Text('${r.stock} left', style: const TextStyle(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('${r.pointsCost} pts', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isUnlocked ? AppColors.accent : AppColors.textMuted)),
                          GestureDetector(
                            onTap: (isUnlocked && !outOfStock) ? () => _showRedeemDialog(ctx, ref, r.id, r.name, r.pointsCost, points) : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: outOfStock ? Colors.grey.withValues(alpha: 0.2) : isUnlocked ? AppColors.primary : (isDark ? const Color(0xFF334155) : AppColors.border),
                                borderRadius: AppRadius.full,
                              ),
                              child: Text(
                                outOfStock ? 'Sold Out' : isUnlocked ? 'Redeem' : 'Locked',
                                style: TextStyle(color: outOfStock ? AppColors.textMuted : isUnlocked ? Colors.white : (isDark ? AppColors.textMutedDark : AppColors.textMuted), fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ]),
                      ])),
                    ]),
                  );
                },
              ),
      ),
    );
  }

  IconData _rewardIcon(String t) => switch (t) {
    'premium_badge'   => Icons.verified_rounded,
    'gift_card'       => Icons.card_giftcard_rounded,
    'merch'           => Icons.shopping_bag_rounded,
    'digital'         => Icons.download_rounded,
    _                 => Icons.redeem_rounded,
  };

  void _showRedeemDialog(BuildContext context, WidgetRef ref, String rewardId, String name, int cost, int points) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
        title: Text('Redeem "$name"', style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('This will cost $cost points.', style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: AppRadius.md), child: Row(children: [
            const Icon(Icons.stars_rounded, color: AppColors.accent, size: 18),
            const SizedBox(width: 8),
            Text('Your balance: $points pts  →  ${points - cost} pts', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary)),
          ])),
          const SizedBox(height: 8),
          Text('Our team will contact you within 24–48 hours after redemption.', style: AppText.bodySmall.copyWith(color: AppColors.textMuted)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final nav = Navigator.of(context);
              try {
                final remaining = await ref.read(rewardsServiceProvider).redeem(rewardId);
                nav.pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('🎉 Redeemed! Remaining balance: $remaining pts'),
                    backgroundColor: AppColors.success,
                    duration: const Duration(seconds: 4),
                  ));
                  onRedeemed();
                }
              } catch (e) {
                nav.pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: AppColors.danger));
                }
              }
            },
            child: const Text('Confirm Redeem'),
          ),
        ],
      ),
    );
  }
}

// ── Tab 3: History ────────────────────────────────────────────────────────────
class _HistoryTab extends ConsumerWidget {
  final bool isDark;
  const _HistoryTab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_pointsHistoryProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(_pointsHistoryProvider),
      child: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => _ErrorCard(message: e.toString()),
        data: (events) => events.isEmpty
            ? _EmptyCard(icon: Icons.bar_chart_rounded, text: 'No points history yet')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: events.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? AppColors.borderDark : AppColors.border),
                itemBuilder: (_, i) {
                  final e = events[i];
                  final color = e.isPositive ? AppColors.success : AppColors.danger;
                  return Container(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(children: [
                      Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Center(child: Text(e.label.split(' ')[0], style: const TextStyle(fontSize: 18)))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.label.substring(e.label.indexOf(' ') + 1), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimary)),
                        Text(_timeAgo(e.createdAt), style: AppText.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11)),
                      ])),
                      Text('${e.isPositive ? '+' : ''}${e.points}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
                    ]),
                  );
                },
              ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

// ── Shared Helpers ────────────────────────────────────────────────────────────
Widget _sectionTitle(String title, bool isDark) => Text(title,
    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.textPrimary));

class _ShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 120, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: AppRadius.lg),
    child: const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)));
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyCard({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.05), borderRadius: AppRadius.lg, border: Border.all(color: AppColors.border)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 40, color: AppColors.textMuted),
      const SizedBox(height: 10),
      Text(text, style: AppText.bodyMedium.copyWith(color: AppColors.textMuted), textAlign: TextAlign.center),
    ]));
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.05), borderRadius: AppRadius.md),
    child: Text('Error: $message', style: const TextStyle(color: AppColors.danger, fontSize: 12)));
}
