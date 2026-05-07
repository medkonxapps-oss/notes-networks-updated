import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:design_system/design_system.dart';
import 'package:shared/shared.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/async_value_widget.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _periods = ['weekly', 'monthly', 'all_time'];
  final _periodLabels = ['This Week', 'This Month', 'All Time'];
  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Leaderboard', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: _periodLabels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: _periods.map((p) => _LeaderboardTab(period: p)).toList(),
      ),
    );
  }
}

class _LeaderboardTab extends ConsumerWidget {
  final String period;
  const _LeaderboardTab({required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leaderboardProvider(period));
    final me = ref.read(supabaseClientProvider).auth.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AsyncValueWidget(
      value: async,
      loading: () => ListView.builder(padding: const EdgeInsets.all(16), itemCount: 10, itemBuilder: (_, __) => const SkeletonCard(height: 72)),
      onRetry: () => ref.invalidate(leaderboardProvider(period)),
      data: (entries) {
        if (entries.isEmpty) return const EmptyState(icon: Icons.leaderboard_rounded, title: 'No data yet', subtitle: 'Be the first to upload notes!');
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(leaderboardProvider(period)),
          color: AppColors.primary,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                children: [
                  if (entries.length >= 3) _Podium(entries: entries.take(3).toList()),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: entries.length,
                      itemBuilder: (ctx, i) {
                      final e = entries[i];
                      final isMe = e.userId == me?.id;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isMe ? (isDark ? AppColors.primary.withValues(alpha: 0.15) : AppColors.primarySurface) : (isDark ? AppColors.surfaceDark : Colors.white),
                          borderRadius: AppRadius.md,
                          border: Border.all(color: isMe ? AppColors.primary : (isDark ? AppColors.borderDark : AppColors.border)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          leading: SizedBox(width: 36, child: Center(child: _RankBadge(rank: e.rank))),
                          title: Row(children: [
                            AppAvatar(imageUrl: e.avatarUrl, name: e.fullName, size: 32, isVerified: e.isVerified),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(e.fullName, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('@${e.username}', style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMuted)),
                            ])),
                          ]),
                          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('${e.points}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.accent)),
                            Text('pts', style: TextStyle(fontSize: 11, color: isDark ? AppColors.textMutedDark : AppColors.textMuted)),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
    );
  }
}

class _Podium extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  const _Podium({required this.entries});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.surfaceDark : AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (entries.length > 1) Expanded(child: _PodiumItem(entry: entries[1], height: 90, color: AppColors.badgeSilver)),
          Expanded(child: _PodiumItem(entry: entries[0], height: 120, color: AppColors.badgeGold)),
          if (entries.length > 2) Expanded(child: _PodiumItem(entry: entries[2], height: 70, color: AppColors.badgeBronze)),
        ],
      ),
    );
  }
}

class _PodiumItem extends StatelessWidget {
  final LeaderboardEntry entry;
  final double height;
  final Color color;
  const _PodiumItem({required this.entry, required this.height, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AppAvatar(imageUrl: entry.avatarUrl, name: entry.fullName, size: 48, isVerified: entry.isVerified),
      const SizedBox(height: 6),
      Text(entry.fullName.split(' ').first, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
      Text('${entry.points}pts', style: const TextStyle(color: Colors.white70, fontSize: 11)),
      const SizedBox(height: 4),
      Container(
        height: height, width: double.infinity,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.9), borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
        child: Center(child: Text('${entry.rank}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white))),
      ),
    ]);
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});
  @override
  Widget build(BuildContext context) {
    if (rank <= 3) {
      final colors = [AppColors.badgeGold, AppColors.badgeSilver, AppColors.badgeBronze];
      return Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: colors[rank - 1]), child: Center(child: Text('$rank', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))));
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text('$rank', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimary));
  }
}
