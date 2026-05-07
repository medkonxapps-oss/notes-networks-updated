import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:design_system/design_system.dart';
import 'notes_provider.dart';

class AdminNotesScreen extends ConsumerStatefulWidget {
  const AdminNotesScreen({super.key});

  @override
  ConsumerState<AdminNotesScreen> createState() => _AdminNotesScreenState();
}

class _AdminNotesScreenState extends ConsumerState<AdminNotesScreen> {
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(adminNotesListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Notes'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(adminNotesListProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by title...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: isDark ? AppColors.surfaceDark : Colors.white,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  ),
                ),
                const SizedBox(width: 12),
                _FilterChip(
                  label: 'Status',
                  value: _statusFilter,
                  options: const {
                    'all': 'All',
                    'active': 'Active',
                    'pending_review': 'Pending',
                    'removed': 'Removed',
                  },
                  onChanged: (v) => setState(() => _statusFilter = v),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: notesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (notes) {
                final filtered = notes.where((n) {
                  final title = (n['title'] as String? ?? '').toLowerCase();
                  final status = n['status'] as String? ?? '';
                  final matchSearch = _searchQuery.isEmpty || title.contains(_searchQuery);
                  final matchStatus = _statusFilter == 'all' || status == _statusFilter;
                  return matchSearch && matchStatus;
                }).toList();

                if (filtered.isEmpty) {
                  return const EmptyState(icon: Icons.article_outlined, title: 'No notes found', subtitle: '');
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _AdminNoteTile(note: filtered[i]),
                );
              },
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$label: ${options[value]}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          const Icon(Icons.expand_more_rounded, size: 18),
        ]),
      ),
    );
  }
}

class _AdminNoteTile extends ConsumerWidget {
  final Map<String, dynamic> note;
  const _AdminNoteTile({required this.note});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = note['users'] as Map<String, dynamic>?;
    final status = note['status'] as String? ?? 'unknown';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border),
      ),
      child: ListTile(
        title: Text(note['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('@${user?['username'] ?? 'unknown'} · ${note['subject']} · ${note['file_type']}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusBadge(status: status),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'delete') {
                  ref.read(adminNotesActionsProvider).deleteNote(note['id']);
                } else {
                  ref.read(adminNotesActionsProvider).updateStatus(note['id'], v);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'active', child: Text('Mark Active')),
                const PopupMenuItem(value: 'pending_review', child: Text('Mark Pending')),
                const PopupMenuItem(value: 'delete', child: Text('Remove Note', style: TextStyle(color: Colors.red))),
              ],
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    Color color = Colors.grey;
    switch (status) {
      case 'active': color = Colors.green; break;
      case 'pending_review': color = Colors.orange; break;
      case 'removed': color = Colors.red; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
