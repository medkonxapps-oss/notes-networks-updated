import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:design_system/design_system.dart';
import 'package:intl/intl.dart';

final _redemptionHistoryProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return [];
  final res = await Supabase.instance.client
      .from('redemptions')
      .select('*, rewards_catalog!reward_id(name, reward_type, image_url, description)')
      .eq('user_id', uid)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(res as List);
});

class RedemptionHistoryScreen extends ConsumerWidget {
  const RedemptionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_redemptionHistoryProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Redemption History',
            style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.textPrimary)),
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_redemptionHistoryProvider),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text('Error loading history', style: AppText.bodyMedium.copyWith(color: AppColors.danger)),
            const SizedBox(height: 8),
            TextButton(onPressed: () => ref.invalidate(_redemptionHistoryProvider), child: const Text('Retry')),
          ]),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(color: AppColors.primarySurface, shape: BoxShape.circle),
                  child: const Icon(Icons.redeem_rounded, size: 40, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                Text('No redemptions yet', style: AppText.headlineMedium.copyWith(color: isDark ? Colors.white : AppColors.textPrimary)),
                const SizedBox(height: 8),
                Text('Earn points by uploading notes and redeem them for rewards!',
                    style: AppText.bodyMedium.copyWith(color: AppColors.textMuted), textAlign: TextAlign.center),
              ]),
            );
          }

          // Summary banner
          final totalSpent = items.fold<int>(0, (s, r) => s + (r['points_spent'] as int? ?? 0));
          final pendingCount = items.where((r) => r['status'] == 'pending').length;
          final deliveredCount = items.where((r) => r['status'] == 'delivered').length;

          return Column(children: [
            // Summary strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: isDark ? AppColors.surfaceDark : AppColors.primarySurface,
              child: Row(children: [
                _SumStat(label: 'Total Spent', value: '$totalSpent pts', color: AppColors.accent),
                _Divider(),
                _SumStat(label: 'Pending', value: '$pendingCount', color: AppColors.warning),
                _Divider(),
                _SumStat(label: 'Delivered', value: '$deliveredCount', color: AppColors.success),
              ]),
            ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(_redemptionHistoryProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) => _RedemptionCard(item: items[i], isDark: isDark),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _RedemptionCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isDark;
  const _RedemptionCard({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final reward = item['rewards_catalog'] as Map<String, dynamic>? ?? {};
    final status = item['status'] as String? ?? 'pending';
    final dt = DateTime.tryParse(item['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now();
    final points = item['points_spent'] as int? ?? 0;
    final statusColor = _statusColor(status);
    final statusIcon = _statusIcon(status);
    final rewardType = reward['reward_type'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: AppRadius.lg,
        border: Border.all(
          color: status == 'delivered'
              ? AppColors.success.withValues(alpha: 0.3)
              : status == 'cancelled'
                  ? AppColors.danger.withValues(alpha: 0.3)
                  : (isDark ? AppColors.borderDark : AppColors.border),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Reward icon
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: AppRadius.md,
            ),
            child: Icon(_rewardIcon(rewardType), color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),

          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              reward['name'] as String? ?? 'Reward',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: isDark ? Colors.white : AppColors.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('d MMM yyyy, HH:mm').format(dt),
              style: AppText.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11),
            ),
          ])),

          // Status chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: AppRadius.full,
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(statusIcon, size: 12, color: statusColor),
              const SizedBox(width: 4),
              Text(
                status[0].toUpperCase() + status.substring(1),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor),
              ),
            ]),
          ),
        ]),

        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),

        Row(children: [
          // Points spent
          Row(children: [
            const Icon(Icons.stars_rounded, size: 15, color: AppColors.accent),
            const SizedBox(width: 4),
            Text('$points pts spent', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent)),
          ]),
          const Spacer(),
          // Status timeline
          _StatusTimeline(status: status),
        ]),

        // Status-specific message
        if (status == 'pending') ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.07),
              borderRadius: AppRadius.sm,
            ),
            child: Row(children: [
              const Icon(Icons.schedule_rounded, size: 14, color: AppColors.warning),
              const SizedBox(width: 6),
              const Expanded(child: Text(
                'Our team will contact you within 24–48 hours.',
                style: TextStyle(fontSize: 12, color: AppColors.warning),
              )),
            ]),
          ),
        ] else if (status == 'dispatched') ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.07), borderRadius: AppRadius.sm),
            child: Row(children: [
              const Icon(Icons.local_shipping_rounded, size: 14, color: Colors.blue),
              const SizedBox(width: 6),
              const Expanded(child: Text('Your reward is on its way!', style: TextStyle(fontSize: 12, color: Colors.blue))),
            ]),
          ),
        ] else if (status == 'delivered') ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.07), borderRadius: AppRadius.sm),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
              const SizedBox(width: 6),
              const Expanded(child: Text('Delivered! Enjoy your reward 🎉', style: TextStyle(fontSize: 12, color: AppColors.success))),
            ]),
          ),
        ] else if (status == 'cancelled') ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.07), borderRadius: AppRadius.sm),
            child: Row(children: [
              const Icon(Icons.cancel_rounded, size: 14, color: AppColors.danger),
              const SizedBox(width: 6),
              const Expanded(child: Text('This redemption was cancelled. Points have been refunded.', style: TextStyle(fontSize: 12, color: AppColors.danger))),
            ]),
          ),
        ],
      ]),
    );
  }

  Color _statusColor(String s) => switch (s) {
    'pending'    => AppColors.warning,
    'dispatched' => Colors.blue,
    'delivered'  => AppColors.success,
    'cancelled'  => AppColors.danger,
    _            => AppColors.textMuted,
  };

  IconData _statusIcon(String s) => switch (s) {
    'pending'    => Icons.schedule_rounded,
    'dispatched' => Icons.local_shipping_rounded,
    'delivered'  => Icons.check_circle_rounded,
    'cancelled'  => Icons.cancel_rounded,
    _            => Icons.help_outline_rounded,
  };

  IconData _rewardIcon(String t) => switch (t) {
    'premium_badge' => Icons.verified_rounded,
    'gift_card'     => Icons.card_giftcard_rounded,
    'merch'         => Icons.shopping_bag_rounded,
    'digital'       => Icons.download_rounded,
    _               => Icons.redeem_rounded,
  };
}

class _StatusTimeline extends StatelessWidget {
  final String status;
  const _StatusTimeline({required this.status});

  @override
  Widget build(BuildContext context) {
    final steps = ['pending', 'dispatched', 'delivered'];
    final cancelled = status == 'cancelled';
    final currentIdx = cancelled ? -1 : steps.indexOf(status);

    if (cancelled) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cancel_rounded, size: 14, color: AppColors.danger),
        const SizedBox(width: 4),
        const Text('Cancelled', style: TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w700)),
      ]);
    }

    return Row(mainAxisSize: MainAxisSize.min, children: steps.asMap().entries.expand((e) {
      final active = e.key <= currentIdx;
      final color = active ? AppColors.success : AppColors.border;
      return [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        if (e.key < steps.length - 1)
          Container(width: 20, height: 2, color: e.key < currentIdx ? AppColors.success : AppColors.border),
      ];
    }).toList());
  }
}

class _SumStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SumStat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
    Text(label, style: AppText.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11)),
  ]));
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 32, color: AppColors.border);
}
