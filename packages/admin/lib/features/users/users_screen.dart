import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:design_system/design_system.dart';
import '../../shared/utils/audit_logger.dart';
import 'users_provider.dart';

// ── Advanced User Management Screen ─────────────────────────────────────────
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});
  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _searchQuery = '';
  String _roleFilter = 'all';
  String _sortBy = 'created_at';
  bool _sortAsc = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(usersListProvider),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'All Users'),
            Tab(text: 'Pending Verify'),
            Tab(text: 'Suspended'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search + Filters
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name, username or email...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true, fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                ),
              ),
              const SizedBox(width: 12),
              _FilterChip(
                label: 'Role',
                value: _roleFilter,
                options: const {'all': 'All', 'student': 'Student', 'teacher': 'Teacher', 'creator': 'Creator', 'moderator': 'Mod', 'admin': 'Admin'},
                onChanged: (v) => setState(() => _roleFilter = v),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Sort',
                value: _sortBy,
                options: const {'created_at': 'Newest', 'total_points': 'Points', 'notes_count': 'Notes', 'followers_count': 'Followers'},
                onChanged: (v) => setState(() => _sortBy = v),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(_sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded),
                onPressed: () => setState(() => _sortAsc = !_sortAsc),
                tooltip: _sortAsc ? 'Ascending' : 'Descending',
              ),
            ]),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // All users
                _UserListView(
                  usersAsync: usersAsync,
                  filter: (u) {
                    final name = ((u['full_name'] as String?) ?? '').toLowerCase();
                    final uname = ((u['username'] as String?) ?? '').toLowerCase();
                    final email = ((u['email'] as String?) ?? '').toLowerCase();
                    final role = (u['role'] as String?) ?? '';
                    final matchSearch = _searchQuery.isEmpty || name.contains(_searchQuery) || uname.contains(_searchQuery) || email.contains(_searchQuery);
                    final matchRole = _roleFilter == 'all' || role == _roleFilter;
                    return matchSearch && matchRole && (u['deleted_at'] == null);
                  },
                  sortBy: _sortBy,
                  sortAsc: _sortAsc,
                ),
                // Pending verification
                _UserListView(
                  usersAsync: usersAsync,
                  filter: (u) {
                    final isTeacherPending = u['role'] == 'teacher' && u['teacher_status'] == 'pending';
                    final isCreatorPending = u['is_verified_creator'] == false && (u['notes_count'] as int? ?? 0) >= 3;
                    return (isTeacherPending || isCreatorPending) && u['is_active'] == true;
                  },
                  sortBy: 'created_at',
                  sortAsc: false,
                ),
                // Suspended
                _UserListView(
                  usersAsync: usersAsync,
                  filter: (u) {
                    final suspension = u['suspension_until'] as String?;
                    if (suspension == null) return false;
                    return DateTime.parse(suspension).isAfter(DateTime.now());
                  },
                  sortBy: 'suspension_until',
                  sortAsc: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final Map<String, String> options;
  final void Function(String) onChanged;
  const _FilterChip({required this.label, required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => options.entries.map((e) => PopupMenuItem(value: e.key, child: Text(e.value))).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$label: ${options[value] ?? value}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          const Icon(Icons.expand_more_rounded, size: 16, color: AppColors.textMuted),
        ]),
      ),
    );
  }
}

class _UserListView extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> usersAsync;
  final bool Function(Map<String, dynamic>) filter;
  final String sortBy;
  final bool sortAsc;
  const _UserListView({required this.usersAsync, required this.filter, required this.sortBy, required this.sortAsc});

  @override
  Widget build(BuildContext context) {
    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.danger))),
      data: (users) {
        var filtered = users.where(filter).toList();
        filtered.sort((a, b) {
          final av = a[sortBy];
          final bv = b[sortBy];
          if (av == null || bv == null) return 0;
          final cmp = av.toString().compareTo(bv.toString());
          return sortAsc ? cmp : -cmp;
        });

        if (filtered.isEmpty) {
          return const EmptyState(icon: Icons.person_off_rounded, title: 'No users found', subtitle: 'Try adjusting your filters');
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          itemCount: filtered.length,
          itemBuilder: (_, i) => _UserListTile(user: filtered[i]),
        );
      },
    );
  }
}

class _UserListTile extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;
  const _UserListTile({required this.user});
  @override
  ConsumerState<_UserListTile> createState() => _UserListTileState();
}

class _UserListTileState extends ConsumerState<_UserListTile> {
  bool _loading = false;

  Future<void> _toggleVerified() async {
    setState(() => _loading = true);
    try {
      final current = widget.user['is_verified_creator'] as bool? ?? false;
      await Supabase.instance.client
          .from('users')
          .update({'is_verified_creator': !current})
          .eq('id', widget.user['id'] as String);

      await AuditLogger.log(
        action: 'verify_creator',
        targetId: widget.user['id'] as String,
        targetType: 'user',
        details: '${!current ? "Verified" : "Unverified"} user @${widget.user['username']}',
      );

      ref.invalidate(usersListProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive() async {
    setState(() => _loading = true);
    try {
      final current = widget.user['is_active'] as bool? ?? true;
      await Supabase.instance.client
          .from('users')
          .update({'is_active': !current})
          .eq('id', widget.user['id'] as String);

      await AuditLogger.log(
        action: !current ? 'activate_user' : 'deactivate_user',
        targetId: widget.user['id'] as String,
        targetType: 'user',
        details: '${!current ? "Activated" : "Deactivated"} user @${widget.user['username']}',
      );

      ref.invalidate(usersListProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeRole(String newRole) async {
    setState(() => _loading = true);
    try {
      final oldRole = widget.user['role'] as String? ?? 'student';
      await Supabase.instance.client
          .from('users')
          .update({'role': newRole})
          .eq('id', widget.user['id'] as String);

      await AuditLogger.log(
        action: 'change_role',
        targetId: widget.user['id'] as String,
        targetType: 'user',
        details: 'Changed role of @${widget.user['username']} from $oldRole to $newRole',
      );

      ref.invalidate(usersListProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _suspendUser(int days) async {
    setState(() => _loading = true);
    try {
      final until = DateTime.now().add(Duration(days: days)).toIso8601String();
      await Supabase.instance.client
          .from('users')
          .update({'suspension_until': until})
          .eq('id', widget.user['id'] as String);

      await AuditLogger.log(
        action: 'suspend_user',
        targetId: widget.user['id'] as String,
        targetType: 'user',
        details: 'Suspended @${widget.user['username']} for $days days',
      );

      ref.invalidate(usersListProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User suspended for $days days'), backgroundColor: AppColors.warning));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unsuspend() async {
    setState(() => _loading = true);
    try {
      await Supabase.instance.client
          .from('users')
          .update({'suspension_until': null})
          .eq('id', widget.user['id'] as String);

      await AuditLogger.log(
        action: 'unsuspend_user',
        targetId: widget.user['id'] as String,
        targetType: 'user',
        details: 'Unsuspended @${widget.user['username']}',
      );

      ref.invalidate(usersListProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _grantPoints(int points) async {
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.rpc('increment_user_points', params: {
        'target_user_id': widget.user['id'],
        'amount': points,
      });
      // Also log in ledger
      await Supabase.instance.client.from('points_ledger').insert({
        'user_id': widget.user['id'],
        'event_type': 'admin_grant',
        'points': points,
      });

      await AuditLogger.log(
        action: 'grant_points',
        targetId: widget.user['id'] as String,
        targetType: 'user',
        details: 'Granted $points points to @${widget.user['username']}',
      );

      ref.invalidate(usersListProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('+$points points granted!'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateTeacherStatus(String status) async {
    setState(() => _loading = true);
    try {
      // Use security definer RPC to bypass RLS issues with admin updates
      await Supabase.instance.client.rpc('admin_approve_teacher', params: {
        'target_user_id': widget.user['id'] as String,
        'new_status': status,
      });

      await AuditLogger.log(
        action: 'update_teacher_status',
        targetId: widget.user['id'] as String,
        targetType: 'user',
        details: 'Teacher status for @${widget.user['username']} set to $status',
      );

      ref.invalidate(usersListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == 'approved'
              ? '✅ Teacher approved successfully!'
              : '❌ Teacher rejected.'),
          backgroundColor: status == 'approved' ? AppColors.success : AppColors.danger,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final isVerified = u['is_verified_creator'] as bool? ?? false;
    final isActive = u['is_active'] as bool? ?? true;
    final role = u['role'] as String? ?? 'student';
    final teacherStatus = u['teacher_status'] as String?;
    final linkedinUrl = u['linkedin_url'] as String?;
    final idCardUrl = u['id_card_url'] as String?;
    final suspUntil = u['suspension_until'] as String?;
    final isSuspended = suspUntil != null && DateTime.parse(suspUntil).isAfter(DateTime.now());
    
    final roleColor = switch (role) {
      'admin' => AppColors.danger,
      'moderator' => AppColors.warning,
      'creator' => AppColors.primary,
      'teacher' => Colors.purple,
      _ => AppColors.textMuted,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.lg,
        border: Border.all(color: isSuspended ? AppColors.danger.withValues(alpha: 0.3) : AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Stack(children: [
          AppAvatar(
            imageUrl: u['avatar_url'] as String?,
            name: (u['full_name'] as String?) ?? '',
            size: 40,
            isVerified: u['is_verified_creator'] as bool? ?? false,
          ),
          if (!isActive)
            Positioned(right: 0, bottom: 0, child: Container(
              width: 12, height: 12,
              decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
            )),
        ]),
        title: Row(children: [
          Text(u['full_name'] as String? ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(width: 6),
          if (isVerified) const Icon(Icons.verified_rounded, size: 14, color: AppColors.verified),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.1), borderRadius: AppRadius.full),
            child: Text(role, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: roleColor)),
          ),
          if ((role == 'teacher' || teacherStatus != null) && teacherStatus != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (teacherStatus == 'approved' ? AppColors.success : (teacherStatus == 'pending' ? AppColors.warning : AppColors.danger)).withValues(alpha: 0.1),
                borderRadius: AppRadius.full,
              ),
              child: Text(teacherStatus.toUpperCase(), style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w800, 
                color: teacherStatus == 'approved' ? AppColors.success : (teacherStatus == 'pending' ? AppColors.warning : AppColors.danger)
              )),
            ),
          ],
        ]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('@${u['username'] ?? ''} · ${u['email'] ?? ''}', style: AppText.bodySmall),
          if (isSuspended) Text('⚠️ Suspended until ${suspUntil.substring(0, 10)}', style: const TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w600)),
        ]),
        trailing: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)) : null,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Teacher Info Section
              if (teacherStatus != null) ...[
                const Text('Teacher Verification Info', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(children: [
                  if (linkedinUrl != null)
                    Expanded(
                      child: _ActionChip(
                        label: 'LinkedIn Profile',
                        icon: Icons.link_rounded,
                        color: Colors.blue,
                        onTap: () => launchUrl(Uri.parse(linkedinUrl)),
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (idCardUrl != null)
                    Expanded(
                      child: _ActionChip(
                        label: 'View ID Card',
                        icon: Icons.badge_rounded,
                        color: Colors.purple,
                        onTap: () async {
                          try {
                            String finalUrl = idCardUrl;
                            if (!idCardUrl.startsWith('http')) {
                              finalUrl = await Supabase.instance.client.storage
                                  .from('id-cards')
                                  .createSignedUrl(idCardUrl, 3600);
                            }
                            launchUrl(Uri.parse(finalUrl));
                          } catch (e) {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error opening ID card: $e')));
                          }
                        },
                      ),
                    ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: teacherStatus == 'approved' ? null : () => _updateTeacherStatus('approved'),
                      icon: Icon(teacherStatus == 'approved' ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded, size: 18),
                      label: Text(teacherStatus == 'approved' ? 'Approved' : 'Approve Teacher'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: teacherStatus == 'approved' ? Colors.grey[200] : AppColors.success, 
                        foregroundColor: teacherStatus == 'approved' ? AppColors.success : Colors.white,
                        disabledBackgroundColor: Colors.green.withValues(alpha: 0.1),
                        disabledForegroundColor: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: teacherStatus == 'rejected' ? null : () => _updateTeacherStatus('rejected'),
                      icon: Icon(teacherStatus == 'rejected' ? Icons.cancel_rounded : Icons.cancel_outlined, size: 18),
                      label: Text(teacherStatus == 'rejected' ? 'Rejected' : 'Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: teacherStatus == 'rejected' ? Colors.grey[200] : AppColors.danger, 
                        foregroundColor: teacherStatus == 'rejected' ? AppColors.danger : Colors.white,
                        disabledBackgroundColor: Colors.red.withValues(alpha: 0.1),
                        disabledForegroundColor: Colors.red,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
              ],
              // Stats row
              Row(children: [
                _stat('Points', '${u['total_points'] ?? 0}', AppColors.accent),
                const SizedBox(width: 24),
                _stat('Notes', '${u['notes_count'] ?? 0}', AppColors.success),
                const SizedBox(width: 24),
                _stat('Followers', '${u['followers_count'] ?? 0}', AppColors.primary),
                const SizedBox(width: 24),
                _stat('Streak', '${u['current_streak'] ?? 0}d', AppColors.danger),
              ]),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              // Action buttons
              Wrap(spacing: 8, runSpacing: 8, children: [
                // Verify toggle
                _ActionChip(
                  label: isVerified ? 'Remove Verify' : 'Verify Creator',
                  icon: isVerified ? Icons.unpublished_rounded : Icons.verified_rounded,
                  color: AppColors.verified,
                  onTap: _toggleVerified,
                ),
                // Active toggle
                _ActionChip(
                  label: isActive ? 'Deactivate' : 'Activate',
                  icon: isActive ? Icons.person_off_rounded : Icons.person_rounded,
                  color: isActive ? AppColors.danger : AppColors.success,
                  onTap: _toggleActive,
                ),
                // Role change
                PopupMenuButton<String>(
                  onSelected: _changeRole,
                  itemBuilder: (_) => ['student', 'teacher', 'creator', 'moderator', 'admin']
                      .map((r) => PopupMenuItem(value: r, child: Text(r)))
                      .toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: AppRadius.full, border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.admin_panel_settings_rounded, size: 14, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text('Change Role', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                      SizedBox(width: 4),
                      Icon(Icons.expand_more, size: 14, color: AppColors.primary),
                    ]),
                  ),
                ),
                // Suspend
                if (!isSuspended)
                  PopupMenuButton<int>(
                    onSelected: _suspendUser,
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 1, child: Text('Suspend 1 day')),
                      PopupMenuItem(value: 7, child: Text('Suspend 7 days')),
                      PopupMenuItem(value: 30, child: Text('Suspend 30 days')),
                      PopupMenuItem(value: 365, child: Text('Suspend 1 year')),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.08), borderRadius: AppRadius.full, border: Border.all(color: AppColors.danger.withValues(alpha: 0.3))),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.block_rounded, size: 14, color: AppColors.danger),
                        SizedBox(width: 6),
                        Text('Suspend', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.danger)),
                        SizedBox(width: 4),
                        Icon(Icons.expand_more, size: 14, color: AppColors.danger),
                      ]),
                    ),
                  )
                else
                  _ActionChip(label: 'Unsuspend', icon: Icons.check_circle_rounded, color: AppColors.success, onTap: _unsuspend),
                // Grant points
                PopupMenuButton<int>(
                  onSelected: _grantPoints,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 50, child: Text('+50 Points')),
                    PopupMenuItem(value: 100, child: Text('+100 Points')),
                    PopupMenuItem(value: 500, child: Text('+500 Points')),
                    PopupMenuItem(value: 1000, child: Text('+1000 Points')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.08), borderRadius: AppRadius.full, border: Border.all(color: AppColors.accent.withValues(alpha: 0.3))),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.stars_rounded, size: 14, color: AppColors.accent),
                      SizedBox(width: 6),
                      Text('Grant Points', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent)),
                      SizedBox(width: 4),
                      Icon(Icons.expand_more, size: 14, color: AppColors.accent),
                    ]),
                  ),
                ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
      Text(label, style: AppText.bodySmall),
    ],
  );
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: AppRadius.full,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}
