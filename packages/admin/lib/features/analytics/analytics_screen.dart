import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:design_system/design_system.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  late TabController _tabs;
  String _period = '30'; // days

  late Future<List<Map<String, dynamic>>> _dailyFuture;
  late Future<List<Map<String, dynamic>>> _subjectFuture;
  late Future<Map<String, dynamic>> _retentionFuture;
  late Future<List<Map<String, dynamic>>> _userGrowthFuture;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  void _load() {
    final now = DateTime.now();
    final since = now.subtract(Duration(days: int.parse(_period))).toIso8601String();
    
    _userGrowthFuture = _fetchGrowthData(since);
    _dailyFuture = _userGrowthFuture; // Reuse growth data fetch for daily stats
    _subjectFuture = _fetchSubjectData();
    _retentionFuture = _fetchRetentionData();
  }

  Future<List<Map<String, dynamic>>> _fetchSubjectData() async {
    try {
      final data = await _client.from('admin_subject_analytics').select();
      if (data.isNotEmpty) return data;

      // Fallback: Group by subject from notes table
      final notes = await _client.from('notes').select('subject, views_count, likes_count');
      final Map<String, Map<String, dynamic>> grouped = {};
      
      for (final n in notes) {
        final sub = n['subject'] as String? ?? 'Other';
        final views = (n['views_count'] as num? ?? 0).toInt();
        final likes = (n['likes_count'] as num? ?? 0).toInt();
        
        if (!grouped.containsKey(sub)) {
          grouped[sub] = {'subject': sub, 'notes_count': 0, 'total_views': 0, 'total_likes': 0};
        }
        grouped[sub]!['notes_count'] = (grouped[sub]!['notes_count'] as int) + 1;
        grouped[sub]!['total_views'] = (grouped[sub]!['total_views'] as int) + views;
        grouped[sub]!['total_likes'] = (grouped[sub]!['total_likes'] as int) + likes;
      }
      
      final result = grouped.values.toList();
      // Sort by popularity
      result.sort((a, b) => (b['notes_count'] as int).compareTo(a['notes_count'] as int));
      return result;
    } catch (e) {
      debugPrint('Subject data fallback error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> _fetchRetentionData() async {
    try {
      final stats = await _client.from('admin_kpi_stats').select().single();
      if ((stats['total_users'] as int? ?? 0) > 0) return stats;
    } catch (_) {}

    // Fallback: Direct counts
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
      final responses = await Future.wait<dynamic>([
        _client.from('users').select('id').count(CountOption.exact),
        _client.from('notes').select('id').eq('status', 'active').count(CountOption.exact),
        _client.from('notes').select('views_count'),
        _client.from('users').select('id').gte('updated_at', sevenDaysAgo).count(CountOption.exact),
      ]);

      final totalViews = (responses[2] as List).fold(0, (s, r) => s + (r['views_count'] as num? ?? 0).toInt());

      return {
        'total_users': (responses[0] as PostgrestResponse).count,
        'active_notes': (responses[1] as PostgrestResponse).count,
        'total_views': totalViews,
        'active_users_7d': (responses[3] as PostgrestResponse).count,
        'avg_streak': 0.0, // Hard to calculate directly without RPC
      };
    } catch (e) {
      debugPrint('Retention fallback error: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> _fetchGrowthData(String since) async {
    try {
      final data = await _client.from('admin_daily_stats')
          .select('date, new_users, new_notes, total_views, total_likes')
          .gte('date', since)
          .order('date');
      
      if (data.isNotEmpty) return data;

      // Fallback: Generate daily trend from direct queries
      final List<Map<String, dynamic>> fallbackData = [];
      final today = DateTime.now();
      
      // Determine how many days to fetch (based on _period, but at least 7)
      final daysToFetch = max(7, int.tryParse(_period) ?? 7);
      
      for (int i = daysToFetch - 1; i >= 0; i--) {
        final date = today.subtract(Duration(days: i));
        final start = DateTime(date.year, date.month, date.day).toIso8601String();
        final end = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();

        try {
          final results = await Future.wait<dynamic>([
            _client.from('users').select('id').gte('created_at', start).lte('created_at', end).count(CountOption.exact),
            _client.from('notes').select('id, views_count, likes_count').gte('created_at', start).lte('created_at', end),
          ]);

          final usersRes = results[0] as PostgrestResponse;
          final notes = results[1] as List;
          final dailyViews = notes.fold(0, (s, n) => s + (n['views_count'] as num? ?? 0).toInt());
          final dailyLikes = notes.fold(0, (s, n) => s + (n['likes_count'] as num? ?? 0).toInt());

          fallbackData.add({
            'date': start,
            'new_users': usersRes.count,
            'new_notes': notes.length,
            'total_views': dailyViews,
            'total_likes': dailyLikes,
          });
        } catch (e) {
          debugPrint('Error for day $start: $e');
        }
      }
      return fallbackData;
    } catch (e) {
      debugPrint('Growth data fetch error: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Analytics', style: AppText.displayMedium.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.w900)),
            Row(children: [
              // Period selector
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: '7', label: Text('7D')),
                  ButtonSegment(value: '30', label: Text('30D')),
                  ButtonSegment(value: '90', label: Text('90D')),
                ],
                selected: {_period},
                onSelectionChanged: (v) => setState(() { _period = v.first; _load(); }),
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: AppColors.primary,
                  selectedForegroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              IconButton.outlined(icon: const Icon(Icons.refresh_rounded), onPressed: () => setState(() => _load())),
            ]),
          ]),
        ),

        // Tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: '📈  Growth'),
                Tab(text: '📚  Content'),
                Tab(text: '🧑‍🎓  Subjects'),
                Tab(text: '🔄  Retention'),
              ],
            ),
          ),
        ),

        Expanded(
          child: TabBarView(controller: _tabs, children: [
            _GrowthTab(dailyFuture: _dailyFuture, userGrowthFuture: _userGrowthFuture),
            _ContentTab(dailyFuture: _dailyFuture),
            _SubjectTab(future: _subjectFuture),
            _RetentionTab(future: _retentionFuture),
          ]),
        ),
      ]),
    );
  }
}

// ── Growth Tab ────────────────────────────────────────────────────────────────
class _GrowthTab extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> dailyFuture;
  final Future<List<Map<String, dynamic>>> userGrowthFuture;
  const _GrowthTab({required this.dailyFuture, required this.userGrowthFuture});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: userGrowthFuture,
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          final data = snap.data!;
          if (data.isEmpty) return const Center(child: Text('No data for this period'));

          // Summary cards
          final totalUsers = data.fold(0, (s, r) => s + (r['new_users'] as num? ?? 0).toInt());
          final totalNotes = data.fold(0, (s, r) => s + (r['new_notes'] as num? ?? 0).toInt());
          final avgDailyUsers = data.isEmpty ? 0 : (totalUsers / data.length).round();
          final avgDailyNotes = data.isEmpty ? 0 : (totalNotes / data.length).round();

          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Summary row
            Row(children: [
              _SummaryCard(label: 'New Users', value: totalUsers, icon: Icons.person_add_rounded, color: AppColors.primary, sub: 'avg $avgDailyUsers/day'),
              const SizedBox(width: 16),
              _SummaryCard(label: 'New Notes', value: totalNotes, icon: Icons.note_add_rounded, color: AppColors.success, sub: 'avg $avgDailyNotes/day'),
              const SizedBox(width: 16),
              _SummaryCard(label: 'Peak Day Users', value: data.map((r) => (r['new_users'] as num? ?? 0).toInt()).reduce(max), icon: Icons.trending_up_rounded, color: AppColors.accent, sub: ''),
            ]),
            const SizedBox(height: 28),

            // User + Note growth chart
            Text('User & Note Growth', style: AppText.headlineMedium.copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            _ChartCard(child: SizedBox(
              height: 260,
              child: LineChart(LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.withValues(alpha: 1), strokeWidth: 1)),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: max(1, (data.length / 6).roundToDouble()),
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= data.length) return const SizedBox.shrink();
                      final dt = DateTime.tryParse(data[i]['date'] as String? ?? '');
                      return Text(dt != null ? DateFormat('d/M').format(dt) : '', style: const TextStyle(fontSize: 9, color: AppColors.textMuted));
                    })),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['new_users'] as num? ?? 0).toDouble())).toList(),
                    isCurved: true, color: AppColors.primary, barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.08)),
                  ),
                  LineChartBarData(
                    spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['new_notes'] as num? ?? 0).toDouble())).toList(),
                    isCurved: true, color: AppColors.success, barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: AppColors.success.withValues(alpha: 0.06)),
                  ),
                ],
              )),
            )),
            const SizedBox(height: 12),
            const Row(children: [
              _Legend(color: AppColors.primary, label: 'New Users'),
              SizedBox(width: 20),
              _Legend(color: AppColors.success, label: 'New Notes'),
            ]),
          ]);
        },
      ),
    );
  }
}

// ── Content Tab ───────────────────────────────────────────────────────────────
class _ContentTab extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> dailyFuture;
  const _ContentTab({required this.dailyFuture});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: dailyFuture,
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          final data = snap.data!;
          if (data.isEmpty) return const Center(child: Text('No data for this period'));

          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Views & Engagement', style: AppText.headlineMedium.copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            _ChartCard(child: SizedBox(
              height: 260,
              child: BarChart(BarChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.withValues(alpha: 1), strokeWidth: 1)),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40,
                    getTitlesWidget: (v, _) => Text(_fmt(v.toInt()), style: const TextStyle(fontSize: 9, color: AppColors.textMuted)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: max(1, (data.length / 6).roundToDouble()),
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= data.length) return const SizedBox.shrink();
                      final dt = DateTime.tryParse(data[i]['date'] as String? ?? '');
                      return Text(dt != null ? DateFormat('d/M').format(dt) : '', style: const TextStyle(fontSize: 9, color: AppColors.textMuted));
                    })),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: data.asMap().entries.map((e) => BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(toY: (e.value['total_views'] as num? ?? 0).toDouble(), color: Colors.blue.withValues(alpha: 0.7), width: 8, borderRadius: BorderRadius.circular(3)),
                    BarChartRodData(toY: (e.value['total_likes'] as num? ?? 0).toDouble(), color: AppColors.like.withValues(alpha: 0.7), width: 8, borderRadius: BorderRadius.circular(3)),
                  ],
                )).toList(),
              )),
            )),
            const SizedBox(height: 12),
            const Row(children: [
              _Legend(color: Colors.blue, label: 'Views'),
              SizedBox(width: 20),
              _Legend(color: AppColors.like, label: 'Likes'),
            ]),
          ]);
        },
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}k';
    return n.toString();
  }
}

// ── Subject Tab ───────────────────────────────────────────────────────────────
class _SubjectTab extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> future;
  const _SubjectTab({required this.future});

  static const _palette = [
    AppColors.primary, AppColors.success, AppColors.accent, Colors.blue,
    AppColors.like, AppColors.warning, Colors.teal, Colors.purple,
    Colors.orange, Colors.cyan,
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          final data = snap.data!.take(10).toList();
          if (data.isEmpty) return const Center(child: Text('No subject data available'));

          final total = data.fold(0, (s, r) => s + (r['notes_count'] as int? ?? 0));

          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Pie Chart
            Expanded(flex: 2, child: _ChartCard(child: Column(children: [
              Text('Subject Distribution', style: AppText.headlineMedium.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              SizedBox(height: 220, child: PieChart(PieChartData(
                sections: data.asMap().entries.map((e) {
                  final pct = total > 0 ? (e.value['notes_count'] as int? ?? 0) / total * 100 : 0.0;
                  return PieChartSectionData(
                    value: pct,
                    color: _palette[e.key % _palette.length],
                    title: pct > 5 ? '${pct.toStringAsFixed(0)}%' : '',
                    radius: 90,
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ))),
            ]))),
            const SizedBox(width: 24),

            // Ranked list
            Expanded(flex: 3, child: _ChartCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Top Subjects', style: AppText.headlineMedium.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              ...data.asMap().entries.map((e) {
                final color = _palette[e.key % _palette.length];
                final count = e.value['notes_count'] as int? ?? 0;
                final views = e.value['total_views'] as int? ?? 0;
                final pct = total > 0 ? count / total : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Row(children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(e.value['subject'] as String? ?? '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                      Text('$count notes · ${_fmtViews(views)} views', style: AppText.bodySmall.copyWith(color: AppColors.textMuted)),
                    ]),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: pct, minHeight: 6,
                      backgroundColor: color.withValues(alpha: 1),
                      valueColor: AlwaysStoppedAnimation(color),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ]),
                );
              }),
            ]))),
          ]);
        },
      ),
    );
  }

  String _fmtViews(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}

// ── Retention Tab ─────────────────────────────────────────────────────────────
class _RetentionTab extends StatelessWidget {
  final Future<Map<String, dynamic>> future;
  const _RetentionTab({required this.future});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          final d = snap.data!;
          final activeUsers = d['active_users_7d'] as int? ?? 0;
          final totalUsers = d['total_users'] as int? ?? 1;
          final retentionRate = totalUsers > 0 ? activeUsers / totalUsers : 0.0;
          final avgStreak = (d['avg_streak'] as num? ?? 0).toDouble();
          final totalNotes = d['active_notes'] as int? ?? 0;
          final totalViews = d['total_views'] as int? ?? 0;

          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Platform Health', style: AppText.headlineMedium.copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _MetricCard(
                label: '7-Day Active Users',
                value: activeUsers.toString(),
                sub: '${(retentionRate * 100).toStringAsFixed(1)}% of total users',
                color: AppColors.primary, icon: Icons.people_rounded,
                progress: retentionRate,
              )),
              const SizedBox(width: 16),
              Expanded(child: _MetricCard(
                label: 'Avg Streak',
                value: '${avgStreak.toStringAsFixed(1)} days',
                sub: 'Per active user',
                color: AppColors.accent, icon: Icons.local_fire_department_rounded,
                progress: (avgStreak / 30).clamp(0, 1),
              )),
              const SizedBox(width: 16),
              Expanded(child: _MetricCard(
                label: 'Views per Note',
                value: totalNotes > 0 ? (totalViews / totalNotes).toStringAsFixed(1) : '—',
                sub: '$totalViews total views',
                color: Colors.blue, icon: Icons.remove_red_eye_rounded,
                progress: null,
              )),
            ]),
            const SizedBox(height: 28),

            // Engagement breakdown
            _ChartCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Engagement Breakdown', style: AppText.headlineMedium.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: 20),
              _EngagementBar(label: 'Active Users (7d)', value: activeUsers, max: totalUsers, color: AppColors.primary),
              _EngagementBar(label: 'Notes with Views', value: d['notes_with_views'] as int? ?? 0, max: totalNotes, color: Colors.blue),
              _EngagementBar(label: 'Verified Creators', value: d['verified_creators'] as int? ?? 0, max: totalUsers, color: AppColors.success),
              _EngagementBar(label: 'Pending Reports', value: d['pending_reports'] as int? ?? 0, max: max(1, d['pending_reports'] as int? ?? 0), color: AppColors.danger),
            ])),
          ]);
        },
      ),
    );
  }
}

class _EngagementBar extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final Color color;
  const _EngagementBar({required this.label, required this.value, required this.max, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text('$value / $max', style: AppText.bodySmall.copyWith(color: AppColors.textMuted)),
        ]),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: pct, minHeight: 8, color: color, backgroundColor: color.withValues(alpha: 1), borderRadius: BorderRadius.circular(10)),
      ]),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String label, sub;
  final int value;
  final IconData icon;
  final Color color;
  const _SummaryCard({required this.label, required this.value, required this.icon, required this.color, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 1), borderRadius: AppRadius.md),
          child: Icon(icon, color: color, size: 22)),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(NumberFormat.compact().format(value), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          if (sub.isNotEmpty) Text(sub, style: AppText.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 10)),
        ]),
      ]),
    ));
  }
}

class _MetricCard extends StatelessWidget {
  final String label, value, sub;
  final Color color;
  final IconData icon;
  final double? progress;
  const _MetricCard({required this.label, required this.value, required this.sub, required this.color, required this.icon, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: AppText.bodySmall.copyWith(color: AppColors.textMuted), overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
        Text(sub, style: AppText.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11)),
        if (progress != null) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(value: progress, minHeight: 6, color: color, backgroundColor: color.withValues(alpha: 1), borderRadius: BorderRadius.circular(10)),
        ],
      ]),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final Widget child;
  const _ChartCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: AppRadius.lg,
      border: Border.all(color: AppColors.border),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
    ),
    child: child,
  );
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
  ]);
}
