import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:design_system/design_system.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'moderation_provider.dart';

class ModerationScreen extends ConsumerStatefulWidget {
  const ModerationScreen({super.key});
  @override
  ConsumerState<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends ConsumerState<ModerationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingReviewProvider);
    final historyAsync = ref.watch(moderationHistoryProvider);
    final selected = ref.watch(selectedNoteIdsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Moderation'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(moderationListProvider);
              ref.invalidate(pendingReviewProvider);
              ref.invalidate(moderationHistoryProvider);
              ref.read(selectedNoteIdsProvider.notifier).state = {};
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.pending_actions_rounded, size: 16),
                const SizedBox(width: 6),
                Text('Pending (${pendingAsync.value?.length ?? 0})'),
              ]),
            ),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.history_rounded, size: 16),
                const SizedBox(width: 6),
                Text('History (${historyAsync.value?.length ?? 0})'),
              ]),
            ),
            const Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.report_rounded, size: 16),
                SizedBox(width: 6),
                Text('Reports'),
              ]),
            ),
          ],
        ),
      ),
      bottomNavigationBar: selected.isNotEmpty
          ? _BulkActionBar(selectedCount: selected.length)
          : null,
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _PendingReviewTab(),
          _HistoryTab(),
          _ReportsTab(),
        ],
      ),
    );
  }
}

class _BulkActionBar extends ConsumerWidget {
  final int selectedCount;
  const _BulkActionBar({required this.selectedCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primarySurface, borderRadius: BorderRadius.circular(20)),
            child: Text('$selectedCount selected',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => ref.read(selectedNoteIdsProvider.notifier).state = {},
            child: const Text('Clear', style: TextStyle(color: AppColors.textMuted)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _bulkApprove(context, ref),
            icon: const Icon(Icons.check_rounded, size: 16),
            label: Text('Approve All ($selectedCount)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _bulkApprove(BuildContext context, WidgetRef ref) async {
    final notes = ref.read(pendingReviewProvider).value ?? [];
    final selected = ref.read(selectedNoteIdsProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Approve ${selected.length} Notes?'),
        content: Text('This will publish ${selected.length} notes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve All'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final count = await ref.read(moderationActionsProvider).bulkApprove(selected);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$count notes approved!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Bulk approval failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }
}

class _PendingReviewTab extends ConsumerWidget {
  const _PendingReviewTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingReviewProvider);
    final selected = ref.watch(selectedNoteIdsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return pendingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (notes) {
        if (notes.isEmpty) return const Center(child: EmptyState(icon: Icons.check_circle_outline_rounded, title: 'No Pending Notes', subtitle: 'All reviewed.'));
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              color: isDark ? AppColors.surfaceDark : Colors.white,
              child: Row(children: [
                Checkbox(
                  value: selected.length == notes.length && notes.isNotEmpty,
                  tristate: selected.isNotEmpty && selected.length < notes.length,
                  onChanged: (v) {
                    if (v == true) {
                      ref.read(selectedNoteIdsProvider.notifier).state = notes.map((n) => n['id'] as String).toSet();
                    } else {
                      ref.read(selectedNoteIdsProvider.notifier).state = {};
                    }
                  },
                  activeColor: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(selected.isEmpty ? 'Select all (${notes.length})' : '${selected.length} of ${notes.length} selected', style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: notes.length, itemBuilder: (ctx, i) => _NoteReviewCard(note: notes[i]))),
          ],
        );
      },
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(moderationHistoryProvider);
    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (notes) {
        if (notes.isEmpty) return const Center(child: EmptyState(icon: Icons.history_rounded, title: 'No History', subtitle: 'None processed.'));
        return ListView.builder(padding: const EdgeInsets.all(16), itemCount: notes.length, itemBuilder: (ctx, i) => _NoteReviewCard(note: notes[i], isHistory: true));
      },
    );
  }
}

class _NoteReviewCard extends ConsumerWidget {
  final Map<String, dynamic> note;
  final bool isHistory;
  const _NoteReviewCard({required this.note, this.isHistory = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedNoteIdsProvider);
    final isSelected = selected.contains(note['id']);
    final user = note['users'] as Map<String, dynamic>?;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.2), width: isSelected ? 2 : 1)),
      child: InkWell(
        onTap: isHistory ? null : () { ref.read(selectedNoteIdsProvider.notifier).update((s) { final next = {...s}; if (isSelected) { next.remove(note['id']); } else { next.add(note['id'] as String); } return next; }); },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (!isHistory) Checkbox(value: isSelected, onChanged: (v) { ref.read(selectedNoteIdsProvider.notifier).update((s) { final next = {...s}; if (v == true) { next.add(note['id'] as String); } else { next.remove(note['id']); } return next; }); }, activeColor: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(note['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('by ${user?['username'] ?? 'Unknown'}', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ])),
                  _StatusBadge(status: note['status']),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showPreview(context, ref), 
                    icon: const Icon(Icons.visibility_outlined, size: 18), 
                    label: const Text('Preview')
                  ),
                  const SizedBox(width: 8),
                  if (!isHistory) ...[
                    OutlinedButton(
                      onPressed: () => _rejectNote(context, ref), 
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Reject')
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _approveNote(context, ref), 
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), 
                      child: const Text('Approve')
                    ),
                  ] else if (note['status'] == 'removed') ...[
                    ElevatedButton.icon(
                      onPressed: () => _restoreNote(context, ref),
                      icon: const Icon(Icons.settings_backup_restore_rounded, size: 18),
                      label: const Text('Restore'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _restoreNote(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Note?'),
        content: const Text('This will make the note active again for all users.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(moderationActionsProvider).restoreNote(note['id'] as String);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Note restored and active!'),
            backgroundColor: Colors.green,
          ));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to restore: $e'),
            backgroundColor: Colors.red,
          ));
        }
      }
    }
  }

  void _showPreview(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final noteId = note['id']    as String? ?? '';
    final title  = note['title'] as String? ?? 'Untitled';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 860,
          height: 680,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                child: Row(children: [
                  const Icon(Icons.visibility_outlined, size: 20, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ]),
              ),
              const Divider(height: 16),

              // Always fetch fresh from DB to get correct file_keys + file_type
              Expanded(
                child: _PreviewEmpty(noteId: noteId, fileType: 'pdf', ref: ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _approveNote(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(moderationActionsProvider).approveNote(note['id'] as String, note['user_id'] as String);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Approved!'), backgroundColor: Colors.green));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _rejectNote(BuildContext context, WidgetRef ref) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Note'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(labelText: 'Reason for rejection', hintText: 'e.g. Inappropriate content, low quality...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonCtrl.text.isNotEmpty) {
      try {
        await ref.read(moderationActionsProvider).rejectNote(note['id'] as String, note['user_id'] as String, reasonCtrl.text);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rejected'), backgroundColor: Colors.orange));
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String? status;
  const _StatusBadge({this.status});
  @override
  Widget build(BuildContext context) {
    Color color = Colors.grey;
    switch (status) {
      case 'pending_review': color = Colors.orange; break;
      case 'active': color = Colors.green; break;
      case 'removed': color = Colors.red; break;
    }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.5))), child: Text(status?.toUpperCase() ?? 'UNKNOWN', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)));
  }
}

class _ReportsTab extends ConsumerWidget {
  const _ReportsTab();
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(moderationListProvider);

    return reportsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (reports) {
        if (reports.isEmpty) {
          return const Center(child: Text('No reports found.'));
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(moderationListProvider.future),
          color: AppColors.primary,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, index) {
              final report = reports[index];
              final note = report['note'] as Map<String, dynamic>?;
              final targetUser = report['target_user'] as Map<String, dynamic>?;
              final reporter = report['reporter'] as Map<String, dynamic>?;
              final isPending = report['status'] == 'pending';
              final targetType = report['target_type'] ?? 'note';

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isPending ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _buildStatusChip(report['status']),
                                    const SizedBox(width: 8),
                                    _buildReasonChip(report['reason']),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.textMuted.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(targetType.toString().toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  targetType == 'user' 
                                    ? (targetUser?['full_name'] ?? targetUser?['username'] ?? 'Unknown User')
                                    : (note?['title'] ?? 'Unknown Note'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Reported by: ${reporter?['username'] ?? 'Unknown'}',
                                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              IconButton.filledTonal(
                                icon: Icon(targetType == 'user' ? Icons.person_rounded : Icons.visibility_rounded, size: 18),
                                tooltip: targetType == 'user' ? 'View Profile' : 'Preview Note',
                                onPressed: targetType == 'user'
                                  ? () {
                                      final uid = report['target_id'];
                                      if (uid != null) {
                                        // Navigate to users tab and pre-filter by ID
                                        context.push('/users?search=$uid');
                                      }
                                    }
                                  : (note != null ? () => _showPreview(ctx, ref, note['id']) : null),
                              ),
                              const SizedBox(height: 8),
                              IconButton.filled(
                                icon: const Icon(Icons.gavel_rounded, size: 18),
                                tooltip: 'Take Action',
                                onPressed: () => _showActionDialog(ctx, ref, report),
                                style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (report['details'] != null && report['details'].toString().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('REPORT DETAILS:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                              const SizedBox(height: 4),
                              Text(report['details'], style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                      if (report['admin_note'] != null && report['admin_note'].toString().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.notes_rounded, size: 14, color: Colors.blue),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Admin: ${report['admin_note']}',
                                style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String? status) {
    Color color = Colors.grey;
    switch (status) {
      case 'pending': color = Colors.orange; break;
      case 'resolved': color = Colors.green; break;
      case 'dismissed': color = Colors.blueGrey; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status?.toUpperCase() ?? 'UNKNOWN',
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildReasonChip(String? reason) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Text(
        reason?.toUpperCase() ?? 'REASON',
        style: const TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showPreview(BuildContext context, WidgetRef ref, String noteId) {
    // note map already has file_type and file_keys from the join
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 800,
          height: 600,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Note Preview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(height: 32),
              Expanded(
                child: _PreviewEmpty(
                  noteId: noteId,
                  fileType: 'pdf', // _PreviewEmpty re-fetches file_type from DB
                  ref: ref,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActionDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> report) {
    final adminNoteCtrl = TextEditingController(text: report['admin_note'] ?? '');
    String status = 'resolved';
    String action = 'none';
    int penaltyPoints = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Resolve Report'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Set Status:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: const [
                    DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                    DropdownMenuItem(value: 'dismissed', child: Text('Dismissed')),
                  ],
                  onChanged: (v) => setState(() => status = v!),
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                ),
                const SizedBox(height: 16),
                const Text('Take Action:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: action,
                  items: [
                    const DropdownMenuItem(value: 'none', child: Text('No further action')),
                    if (report['target_type'] == 'note')
                      const DropdownMenuItem(value: 'delete', child: Text('❌ DELETE POST')),
                    if (report['target_type'] == 'user') ...[
                      const DropdownMenuItem(value: 'deactivate', child: Text('🚫 DEACTIVATE ACCOUNT')),
                      const DropdownMenuItem(value: 'suspend', child: Text('⏳ SUSPEND (7 DAYS)')),
                      const DropdownMenuItem(value: 'delete_user', child: Text('🗑️ PERMANENT DELETE (SOFT)')),
                    ],
                    const DropdownMenuItem(value: 'notify_edit', child: Text('✏️ NOTIFY USER TO EDIT')),
                    const DropdownMenuItem(value: 'warn', child: Text('⚠️ SEND OFFICIAL WARNING')),
                  ],
                  onChanged: (v) => setState(() => action = v!),
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                ),
                const SizedBox(height: 16),
                const Text('Deduct Points (Penalty):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [0, 10, 50, 100].map((pts) => ChoiceChip(
                    label: Text('$pts'),
                    selected: penaltyPoints == pts,
                    onSelected: (selected) {
                      if (selected) setState(() => penaltyPoints = pts);
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: penaltyPoints == pts ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Admin Notes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                TextField(
                  controller: adminNoteCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Add a message to the user or for internal logs...',
                    hintStyle: TextStyle(fontSize: 13),
                  ),
                ),
                if (action != 'none' || penaltyPoints > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Author will be notified about the action and/or penalty.',
                            style: TextStyle(fontSize: 11, color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final actions = ref.read(moderationActionsProvider);
                await actions.resolveReport(
                  report['id'],
                  status,
                  adminNote: adminNoteCtrl.text.trim(),
                  action: action,
                  penaltyPoints: penaltyPoints,
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Report processed successfully.')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Preview Widgets ───────────────────────────────────────────────────────────

/// Shown when file_keys is empty — tries to fetch from DB by noteId
class _PreviewEmpty extends StatelessWidget {
  final String noteId;
  final String fileType;
  final WidgetRef ref;
  const _PreviewEmpty({required this.noteId, required this.fileType, required this.ref});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchByNoteId(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        final data = snap.data;
        if (snap.hasError || data == null) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hourglass_empty_rounded, size: 56, color: AppColors.textMuted),
                SizedBox(height: 16),
                Text(
                  'No files attached yet.',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                ),
                SizedBox(height: 8),
                Text(
                  'The note may still be processing.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ],
            ),
          );
        }
        final keys = data['keys'] as List<String>;
        final type = data['fileType'] as String;
        if (keys.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hourglass_empty_rounded, size: 56, color: AppColors.textMuted),
                SizedBox(height: 16),
                Text(
                  'No files attached yet.',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                ),
                SizedBox(height: 8),
                Text(
                  'The note may still be processing.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ],
            ),
          );
        }
        return _PreviewContent(fileKeys: keys, fileType: type, ref: ref);
      },
    );
  }

  Future<Map<String, dynamic>?> _fetchByNoteId() async {
    if (noteId.isEmpty) return null;
    final data = await Supabase.instance.client
        .from('notes')
        .select('file_keys, file_type')
        .eq('id', noteId)
        .maybeSingle();
    if (data == null) return null;
    final keys = (data['file_keys'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .where((k) => k.isNotEmpty)
        .toList() ?? [];
    final type = (data['file_type'] as String?) ?? fileType;
    return {'keys': keys, 'fileType': type};
  }
}

/// Shown when file_keys is available — fetches signed URLs and renders content
class _PreviewContent extends StatelessWidget {
  final List<String> fileKeys;
  final String fileType;
  final WidgetRef ref;
  const _PreviewContent({required this.fileKeys, required this.fileType, required this.ref});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: ref.read(moderationActionsProvider).getPreviewUrls(fileKeys),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Failed to load preview:\n${snap.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          );
        }

        final urls = snap.data ?? [];
        if (urls.isEmpty) {
          return const Center(
            child: Text('Could not generate preview URLs.', style: TextStyle(color: AppColors.textMuted)),
          );
        }

        // PDF — show open button + URL
        if (fileType == 'pdf') {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, size: 72, color: Colors.red),
                ),
                const SizedBox(height: 24),
                Text(
                  '${urls.length} PDF file${urls.length > 1 ? 's' : ''} attached',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'PDF rendering is not supported in the admin panel.\nOpen in a new tab to review.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 24),
                ...urls.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ElevatedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(entry.value),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: Text(urls.length > 1 ? 'Open PDF ${entry.key + 1}' : 'Open PDF in New Tab'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                )),
              ],
            ),
          );
        }

        // Images — scrollable grid
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${urls.length} page${urls.length > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: urls.length == 1 ? 1 : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: urls.length,
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          urls[i],
                          fit: BoxFit.cover,
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: AppColors.border,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                      : null,
                                  color: AppColors.primary,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.border,
                            child: const Center(
                              child: Icon(Icons.broken_image_rounded, color: AppColors.textMuted, size: 40),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 6, right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Page ${i + 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
