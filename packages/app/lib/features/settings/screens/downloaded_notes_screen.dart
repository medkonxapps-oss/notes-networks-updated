import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:design_system/design_system.dart';
import '../../../shared/providers/providers.dart';
import '../../../core/services/local_db_service.dart';

class DownloadedNotesScreen extends ConsumerWidget {
  const DownloadedNotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsAsync = ref.watch(downloadedNotesProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Downloaded Notes', style: theme.textTheme.titleLarge),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: downloadsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: 'Error', subtitle: e.toString()),
        data: (notes) {
          if (notes.isEmpty) {
            return const EmptyState(
              icon: Icons.download_for_offline_rounded,
              title: 'No downloads yet',
              subtitle: 'Download notes to read them offline',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notes.length,
            itemBuilder: (ctx, i) {
              final n = notes[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.md,
                  side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border),
                ),
                color: isDark ? AppColors.surfaceDark : Colors.white,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2D2D4D) : AppColors.primarySurface, 
                      borderRadius: AppRadius.sm
                    ),
                    child: Icon(
                      n.fileType == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.photo_library_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(n.title, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${n.authorName} • ${DateFormat.yMMMd().format(n.downloadedAt)}', 
                    style: theme.textTheme.bodySmall),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                    onPressed: () => _confirmDelete(context, ref, n),
                  ),
                  onTap: () => context.push('/notes/offline', extra: n),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, LocalNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Download?'),
        content: const Text('This will remove the note from your offline storage.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(localDbServiceProvider).deleteNote(note.id);
      ref.invalidate(downloadedNotesProvider);
      ref.invalidate(isNoteDownloadedProvider(note.id));
    }
  }
}
