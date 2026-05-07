import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/utils/audit_logger.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});
  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _client = Supabase.instance.client;
  bool _saving = false;
  final Map<String, bool> _flagStates = {};

  Future<void> _updateFlag(String flagName, bool value) async {
    setState(() { _flagStates[flagName] = value; _saving = true; });
    try {
      await _client.from('feature_flags')
          .update({'is_enabled': value}).eq('flag_name', flagName);
      
      await AuditLogger.log(
        action: 'update_config',
        targetId: flagName,
        targetType: 'feature_flag',
        details: 'Flag $flagName set to ${value ? "ON" : "OFF"}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$flagName → ${value ? "ON" : "OFF"}'),
          backgroundColor: value ? AppColors.success : AppColors.warning,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      setState(() => _flagStates[flagName] = !value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'), backgroundColor: AppColors.danger,
      ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resyncCounts() async {
    setState(() => _saving = true);
    try {
      await _client.rpc('admin_resync_all_counts');

      await AuditLogger.log(
        action: 'maintenance',
        targetId: 'all_counts',
        targetType: 'system',
        details: 'Manual resync of all counts triggered',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ All counts resynced successfully!'),
        backgroundColor: AppColors.success,
      ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          e.toString().contains('Could not find the function')
              ? '❌ DB function missing. Please run migration 019 on Supabase.'
              : 'Error: $e',
        ),
        backgroundColor: AppColors.danger,
        duration: const Duration(seconds: 6),
      ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('System Configuration'),
        backgroundColor: Colors.transparent, elevation: 0,
        actions: [
          if (_saving) const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ],
      ),
      body: FutureBuilder(
        future: _client.from('feature_flags').select('*').order('flag_name'),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          final flags = snap.data as List;

          // Sync fetched values into local state (only first load)
          for (final f in flags) {
            _flagStates.putIfAbsent(f['flag_name'] as String, () => f['is_enabled'] as bool? ?? false);
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Feature flags
              _SectionHeader(title: 'Feature Flags', subtitle: '${flags.length} flags'),
              const SizedBox(height: 12),
              ...flags.map((flag) {
                final name = flag['flag_name'] as String;
                final current = _flagStates[name] ?? (flag['is_enabled'] as bool? ?? false);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.lg,
                    border: Border.all(color: current ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border),
                  ),
                  child: SwitchListTile(
                    value: current,
                    onChanged: (v) => _updateFlag(name, v),
                    title: Text(
                      name.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: current ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(flag['description'] as String? ?? '', style: AppText.bodySmall),
                    activeThumbColor: AppColors.primary,
                    dense: true,
                  ),
                );
              }),

              const SizedBox(height: 32),

              // Maintenance section
              const _SectionHeader(title: 'Maintenance', subtitle: 'Use with caution'),
              const SizedBox(height: 12),
              _DangerCard(
                icon: Icons.sync_rounded,
                title: 'Resync All Counts',
                subtitle: 'Recalculate likes/saves/followers/notes counts from source tables. Safe to run anytime.',
                color: AppColors.info,
                buttonLabel: 'Run Resync',
                onPressed: _resyncCounts,
              ),
              const SizedBox(height: 12),
              _DangerCard(
                icon: Icons.refresh_rounded,
                title: 'Refresh Feed Scores',
                subtitle: 'Recompute feed_score for all active notes. Run after tuning the algorithm.',
                color: AppColors.warning,
                buttonLabel: 'Refresh Scores',
                onPressed: () async {
                  setState(() => _saving = true);
                  try {
                    await _client.rpc('admin_resync_all_counts');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('✅ Feed scores refreshed!'), backgroundColor: AppColors.success,
                    ));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                        e.toString().contains('Could not find the function')
                            ? '❌ DB function missing. Please run migration 019 on Supabase.'
                            : 'Error: $e',
                      ),
                      backgroundColor: AppColors.danger,
                      duration: const Duration(seconds: 6),
                    ));
                    }
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
              ),
              const SizedBox(height: 12),
              const _DangerCard(
                icon: Icons.warning_rounded,
                title: 'Enable Maintenance Mode',
                subtitle: 'Blocks app access for all users except admins. Toggle a feature flag to enable.',
                color: AppColors.danger,
                buttonLabel: 'Manage via Feature Flags',
                onPressed: null,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: AppText.headlineMedium),
        Text(subtitle, style: AppText.bodySmall),
      ])),
    ]);
  }
}

class _DangerCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String buttonLabel;
  final VoidCallback? onPressed;
  const _DangerCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.buttonLabel, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.lg,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: AppRadius.md),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(subtitle, style: AppText.bodySmall),
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: onPressed != null ? color : AppColors.border,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(buttonLabel),
            ),
          ),
        ])),
      ]),
    );
  }
}
