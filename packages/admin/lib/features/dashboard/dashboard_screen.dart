import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:design_system/design_system.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _client = Supabase.instance.client;
  RealtimeChannel? _channel;

  late Future<Map<String, dynamic>> _statsFuture;
  late Future<List<Map<String, dynamic>>> _recentNotesFuture;
  late Future<List<Map<String, dynamic>>> _topCreatorsFuture;
  late Future<List<Map<String, dynamic>>> _activityFuture;

  // Live counters updated by realtime
  int _liveUsers = 0;
  int _liveNotes = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  void _load() {
    _statsFuture = _fetchStats();
    _recentNotesFuture = _fetchRecentNotes();
    _topCreatorsFuture = _fetchTopCreators();
    _activityFuture = _fetchRecentActivity();
  }

  void _refresh() => setState(() => _load());

  void _subscribeRealtime() {
    _channel = _client.channel('admin_dashboard_live')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'users',
        callback: (_) => setState(() => _liveUsers++),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'notes',
        callback: (_) => setState(() => _liveNotes++),
      )
      .subscribe();
  }

  Future<Map<String, dynamic>> _fetchStats() async {
    Map<String, dynamic> current = {};
    
    // 1. Fetch all 8 KPIs directly from source tables for maximum accuracy
    try {
      final results = await Future.wait<dynamic>([
        // Total Users
        _client.from('users').select('id').count(CountOption.exact),
        // Active Notes
        _client.from('notes').select('id').eq('status', 'active').count(CountOption.exact),
        // All Notes (for total views/likes sum)
        _client.from('notes').select('views_count, likes_count'),
        // Pending Notes
        _client.from('notes').select('id').eq('status', 'pending_review').count(CountOption.exact),
        // Open Reports
        _client.from('reports').select('id').eq('status', 'pending').count(CountOption.exact),
        // Pending Redemptions
        _client.from('redemptions').select('id').eq('status', 'pending').count(CountOption.exact),
        // Pending Teacher Verify
        _client.from('users').select('id').eq('role', 'teacher').eq('teacher_status', 'pending').count(CountOption.exact),
      ]);

      final allNotes = results[2] as List;
      final totalViews = allNotes.fold(0, (s, n) => s + (n['views_count'] as num? ?? 0).toInt());
      final totalLikes = allNotes.fold(0, (s, n) => s + (n['likes_count'] as num? ?? 0).toInt());

      current = {
        'total_users': (results[0] as PostgrestResponse).count,
        'active_notes': (results[1] as PostgrestResponse).count,
        'total_views': totalViews,
        'total_likes': totalLikes,
        'pending_notes': (results[3] as PostgrestResponse).count,
        'pending_reports': (results[4] as PostgrestResponse).count,
        'pending_redemptions': (results[5] as PostgrestResponse).count,
        'pending_teachers': (results[6] as PostgrestResponse).count,
      };
      debugPrint('Dashboard direct stats: $current');
    } catch (e) {
      debugPrint('Error fetching direct counts: $e');
      
      // Fallback to summary table if direct fetch fails
      try {
        final summary = await _client.from('admin_kpi_stats').select().maybeSingle();
        if (summary != null) {
          current = Map<String, dynamic>.from(summary);
          debugPrint('Dashboard fell back to summary: $current');
        }
      } catch (e2) {
        debugPrint('Summary fallback also failed: $e2');
      }
    }
    
    // 2. Daily stats for growth calculation (last 2 days)
    Map<String, dynamic> today = {};
    Map<String, dynamic> yesterday = {};
    try {
      final daily = await _client
          .from('admin_daily_stats')
          .select()
          .order('date', ascending: false)
          .limit(2);
      if (daily.isNotEmpty) today = daily[0];
      if (daily.length >= 2) yesterday = daily[1];
    } catch (_) {}

    return {'current': current, 'today': today, 'yesterday': yesterday};
  }

  Future<List<Map<String, dynamic>>> _fetchRecentNotes() async {
    final data = await _client
        .from('notes')
        .select('id, title, subject, status, created_at, views_count, likes_count, users!user_id(full_name, username)')
        .order('created_at', ascending: false)
        .limit(8);
    return data;
  }

  Future<List<Map<String, dynamic>>> _fetchTopCreators() async {
    final data = await _client
        .from('users')
        .select('id, full_name, username, avatar_url, total_points, notes_count, followers_count, is_verified_creator, role')
        .eq('is_active', true)
        .order('total_points', ascending: false)
        .limit(6);
    return data;
  }

  Future<List<Map<String, dynamic>>> _fetchRecentActivity() async {
    final data = await _client
        .from('notifications')
        .select('type, title, message, created_at')
        .order('created_at', ascending: false)
        .limit(12);
    return data;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateFormat('EEEE, d MMMM y').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Dashboard',
                        style: AppText.displayMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(now,
                        style: AppText.bodyMedium.copyWith(
                            color: AppColors.textMuted)),
                  ]),
                  Row(children: [
                    if (_liveUsers > 0 || _liveNotes > 0)
                      _LiveBadge(users: _liveUsers, notes: _liveNotes),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Refresh'),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    ),
                  ]),
                ],
              ),
              const SizedBox(height: 28),

              // ── KPI Grid ──
              FutureBuilder<Map<String, dynamic>>(
                future: _statsFuture,
                builder: (ctx, snap) {
                  final isLoading = snap.connectionState == ConnectionState.waiting;
                  final curr = snap.data?['current'] as Map<String, dynamic>? ?? {};
                  final today = snap.data?['today'] as Map<String, dynamic>? ?? {};
                  final yest = snap.data?['yesterday'] as Map<String, dynamic>? ?? {};

                  // Helper for daily growth %
                  double? getGrowth(String key) {
                    final t = (today[key] as num? ?? 0).toDouble();
                    final y = (yest[key] as num? ?? 0).toDouble();
                    if (y <= 0) return t > 0 ? 100.0 : null;
                    return ((t - y) / y) * 100;
                  }

                  return GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.7,
                    children: [
                      _KpiCard(label: 'Total Users', icon: Icons.people_rounded, color: AppColors.primary,
                          value: isLoading ? null : (curr['total_users'] as int? ?? 0) + _liveUsers,
                          growth: getGrowth('new_users'),
                          hasError: snap.hasError),
                      _KpiCard(label: 'Active Notes', icon: Icons.article_rounded, color: AppColors.success,
                          value: isLoading ? null : (curr['active_notes'] as int? ?? 0) + _liveNotes,
                          growth: getGrowth('new_notes'),
                          hasError: snap.hasError),
                      _KpiCard(label: 'Total Views', icon: Icons.remove_red_eye_rounded, color: Colors.blue,
                          value: isLoading ? null : curr['total_views'] as int?,
                          growth: getGrowth('total_views'),
                          hasError: snap.hasError),
                      _KpiCard(label: 'Total Likes', icon: Icons.favorite_rounded, color: AppColors.like,
                          value: isLoading ? null : curr['total_likes'] as int?,
                          growth: getGrowth('total_likes'),
                          hasError: snap.hasError),
                      _KpiCard(label: 'Pending Notes', icon: Icons.pending_actions_rounded, color: AppColors.warning,
                          value: isLoading ? null : curr['pending_notes'] as int?,
                          hasError: snap.hasError,
                          onTap: () => context.go('/admin/moderation')),
                      _KpiCard(label: 'Open Reports', icon: Icons.report_rounded, color: AppColors.danger,
                          value: isLoading ? null : curr['pending_reports'] as int?,
                          hasError: snap.hasError,
                          onTap: () => context.go('/admin/moderation')),
                      _KpiCard(label: 'Redemptions', icon: Icons.card_giftcard_rounded, color: AppColors.accent,
                          value: isLoading ? null : curr['pending_redemptions'] as int?,
                          hasError: snap.hasError,
                          onTap: () => context.go('/admin/rewards')),
                      _KpiCard(label: 'Pending Verify', icon: Icons.verified_user_rounded, color: Colors.teal,
                          value: isLoading ? null : curr['pending_teachers'] as int?,
                          hasError: snap.hasError,
                          onTap: () => context.go('/admin/users')),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),

              // ── Main Row: Recent Notes + Quick Actions + Activity Feed ──
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 5, child: _RecentNotesPanel(future: _recentNotesFuture)),
                const SizedBox(width: 16),
                Expanded(flex: 3, child: Column(children: [
                  _QuickActionsPanel(onRefresh: _refresh),
                  const SizedBox(height: 16),
                  _ActivityFeedPanel(future: _activityFuture),
                ])),
              ]),
              const SizedBox(height: 28),

              // ── Top Creators ──
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Top Creators by Points', style: AppText.headlineMedium.copyWith(
                    color: AppColors.textPrimary)),
                TextButton.icon(
                  onPressed: () => context.go('/admin/users'),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                  label: const Text('View All'),
                ),
              ]),
              const SizedBox(height: 12),
              _TopCreatorsPanel(future: _topCreatorsFuture),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Live Badge ────────────────────────────────────────────────────────────────
class _LiveBadge extends StatefulWidget {
  final int users;
  final int notes;
  const _LiveBadge({required this.users, required this.notes});
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge> with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }
  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1 + _pulse.value * 0.05),
          borderRadius: AppRadius.full,
          border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            'Live: +${widget.users} users · +${widget.notes} notes',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success),
          ),
        ]),
      ),
    );
  }
}

// ── KPI Card ──────────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final int? value;
  final double? growth;
  final bool hasError;
  final VoidCallback? onTap;

  const _KpiCard({
    required this.label, required this.icon, required this.color,
    required this.value, required this.hasError, this.growth, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.lg,
          border: Border.all(
            color: onTap != null ? color.withValues(alpha: 0.3) : AppColors.border,
            width: onTap != null ? 1.5 : 1,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Flexible(child: Text(label, style: AppText.bodySmall.copyWith(
                  color: AppColors.textMuted), overflow: TextOverflow.ellipsis)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: AppRadius.sm),
                child: Icon(icon, color: color, size: 16),
              ),
            ]),
            Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              hasError
                  ? const Text('—', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textMuted))
                  : value == null
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: color))
                      : Text(_fmt(value!), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color)),
              if (growth != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: growth! >= 0 ? AppColors.success.withValues(alpha: 0.1) : AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: AppRadius.full,
                  ),
                  child: Text(
                    '${growth! >= 0 ? '+' : ''}${growth!.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: growth! >= 0 ? AppColors.success : AppColors.danger),
                  ),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return NumberFormat.compact().format(n);
  }
}

// ── Recent Notes Panel ────────────────────────────────────────────────────────
class _RecentNotesPanel extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> future;
  const _RecentNotesPanel({required this.future});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Recent Notes',
      trailing: TextButton(
        onPressed: () => context.go('/admin/notes'),
        child: const Text('View All'),
      ),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const _LoadingShimmer(lines: 5);
          if (snap.hasError) return _ErrorBox(error: snap.error.toString());
          final notes = snap.data ?? [];
          if (notes.isEmpty) return const _EmptyBox(label: 'No notes uploaded yet');
          return Column(children: [
            // Header row
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(flex: 4, child: Text('Title', style: _hdr)),
                Expanded(flex: 2, child: Text('Author', style: _hdr)),
                Expanded(flex: 2, child: Text('Subject', style: _hdr)),
                Expanded(flex: 1, child: Text('Views', style: _hdr, textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text('Status', style: _hdr, textAlign: TextAlign.end)),
              ]),
            ),
            const Divider(height: 1),
            ...notes.map((n) => _NoteRow(note: n)),
          ]);
        },
      ),
    );
  }

  TextStyle get _hdr => AppText.bodySmall.copyWith(fontWeight: FontWeight.w700, color: AppColors.textMuted);
}

class _NoteRow extends StatelessWidget {
  final Map<String, dynamic> note;
  const _NoteRow({required this.note});

  @override
  Widget build(BuildContext context) {
    final status = note['status'] as String? ?? 'unknown';
    final statusColor = _statusColor(status);
    final user = note['users'] as Map<String, dynamic>?;

    return InkWell(
      onTap: () {
        // Copy note ID
        Clipboard.setData(ClipboardData(text: note['id'] as String));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Note ID copied to clipboard'), duration: Duration(seconds: 1)));
      },
      borderRadius: AppRadius.sm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Expanded(flex: 4, child: Text(
            note['title'] as String? ?? '—',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            overflow: TextOverflow.ellipsis,
          )),
          Expanded(flex: 2, child: Text(
            '@${user?['username'] ?? '?'}',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          )),
          Expanded(flex: 2, child: Text(
            note['subject'] as String? ?? '—',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          )),
          Expanded(flex: 1, child: Text(
            '${note['views_count'] ?? 0}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue),
            textAlign: TextAlign.center,
          )),
          Expanded(flex: 1, child: Align(
            alignment: Alignment.centerRight,
            child: _StatusChip(status: status, color: statusColor),
          )),
        ]),
      ),
    );
  }

  Color _statusColor(String s) => switch (s) {
    'active' => AppColors.success,
    'pending_review' => AppColors.warning,
    'processing' => Colors.blue,
    'removed' => AppColors.danger,
    _ => AppColors.textMuted,
  };
}

// ── Quick Actions ─────────────────────────────────────────────────────────────
class _QuickActionsPanel extends StatelessWidget {
  final VoidCallback onRefresh;
  const _QuickActionsPanel({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Quick Actions',
      child: Column(children: [
        _Action(icon: Icons.pending_actions_rounded, label: 'Review Pending Notes', color: AppColors.warning, onTap: () => context.go('/admin/moderation')),
        _Action(icon: Icons.report_rounded, label: 'Handle Reports', color: AppColors.danger, onTap: () => context.go('/admin/moderation')),
        _Action(icon: Icons.verified_rounded, label: 'Verify Creators', color: AppColors.primary, onTap: () => context.go('/admin/users')),
        _Action(icon: Icons.campaign_rounded, label: 'Broadcast Push', color: AppColors.follow, onTap: () => context.go('/admin/notifications')),
        _Action(icon: Icons.bar_chart_rounded, label: 'View Analytics', color: Colors.blue, onTap: () => context.go('/admin/analytics')),
        _Action(icon: Icons.sync_rounded, label: 'Refresh Data', color: AppColors.success, onTap: onRefresh),
      ]),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.md,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: AppRadius.md,
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color))),
            Icon(Icons.chevron_right_rounded, size: 15, color: color.withValues(alpha: 0.5)),
          ]),
        ),
      ),
    );
  }
}

// ── Activity Feed ─────────────────────────────────────────────────────────────
class _ActivityFeedPanel extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> future;
  const _ActivityFeedPanel({required this.future});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Activity Feed',
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const _LoadingShimmer(lines: 4);
          final items = snap.data ?? [];
          if (items.isEmpty) return const _EmptyBox(label: 'No recent activity');
          return Column(
            children: items.take(8).map((item) {
              final type = item['type'] as String? ?? 'system';
              final icon = _icon(type);
              final color = _color(type);
              final dt = DateTime.tryParse(item['created_at'] as String? ?? '') ?? DateTime.now();
              final ago = _timeAgo(dt);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Container(width: 30, height: 30, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(icon, size: 14, color: color)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item['title'] as String? ?? type, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                    Text(ago, style: AppText.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 10)),
                  ])),
                ]),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  IconData _icon(String t) => switch (t) {
    'like' => Icons.favorite_rounded,
    'save' => Icons.bookmark_rounded,
    'follow' => Icons.person_add_rounded,
    'reward' => Icons.card_giftcard_rounded,
    'forum' => Icons.forum_rounded,
    _ => Icons.notifications_rounded,
  };

  Color _color(String t) => switch (t) {
    'like' => AppColors.like,
    'save' => AppColors.save,
    'follow' => AppColors.primary,
    'reward' => AppColors.accent,
    _ => AppColors.info,
  };

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

// ── Top Creators ──────────────────────────────────────────────────────────────
class _TopCreatorsPanel extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> future;
  const _TopCreatorsPanel({required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const _LoadingShimmer(lines: 4);
        if (snap.hasError) return _ErrorBox(error: snap.error.toString());
        final users = snap.data ?? [];
        if (users.isEmpty) return const _EmptyBox(label: 'No creators yet');

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, childAspectRatio: 3.2, crossAxisSpacing: 12, mainAxisSpacing: 12,
          ),
          itemCount: users.length,
          itemBuilder: (_, i) {
            final u = users[i];
            final rankColor = i == 0 ? AppColors.badgeGold : i == 1 ? AppColors.badgeSilver : i == 2 ? AppColors.badgeBronze : AppColors.textMuted;
            final avatar = u['avatar_url'] as String?;
            final name = u['full_name'] as String? ?? '?';

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.lg,
                border: Border.all(color: i < 3 ? rankColor.withValues(alpha: 0.4) : AppColors.border),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
              ),
              child: Row(children: [
                Text('#${i + 1}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: rankColor)),
                const SizedBox(width: 10),
                CircleAvatar(radius: 20, backgroundColor: AppColors.primarySurface,
                  backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                  child: avatar == null ? Text(name[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)) : null),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Row(children: [
                    Flexible(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                    if (u['is_verified_creator'] == true) ...[const SizedBox(width: 3), const Icon(Icons.verified_rounded, size: 12, color: AppColors.verified)],
                  ]),
                  Text('${u['total_points'] ?? 0} pts · ${u['notes_count'] ?? 0} notes', style: AppText.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11)),
                ])),
              ]),
            );
          },
        );
      },
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _Card({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title, style: AppText.headlineMedium.copyWith(color: AppColors.textPrimary)),
          if (trailing != null) trailing!,
        ]),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusChip({required this.status, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: AppRadius.full),
    child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
  );
}


class _LoadingShimmer extends StatelessWidget {
  final int lines;
  const _LoadingShimmer({required this.lines});

  @override
  Widget build(BuildContext context) {
    return Column(children: List.generate(lines, (i) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(height: 14, width: double.infinity * (0.4 + (i % 3) * 0.2),
        decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.12), borderRadius: AppRadius.sm)),
    )));
  }
}

class _ErrorBox extends StatelessWidget {
  final String error;
  const _ErrorBox({required this.error});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.05), borderRadius: AppRadius.sm),
    child: Text('Error: $error', style: const TextStyle(color: AppColors.danger, fontSize: 12)),
  );
}

class _EmptyBox extends StatelessWidget {
  final String label;
  const _EmptyBox({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Center(child: Text(label, style: AppText.bodyMedium.copyWith(color: AppColors.textMuted))),
  );
}
