import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:design_system/design_system.dart';
import 'package:shared/shared.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/shared/utils/error_utils.dart';
import '../../../shared/providers/providers.dart';

class CollectionViewScreen extends ConsumerWidget {
  final String collectionId;
  const CollectionViewScreen({super.key, required this.collectionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionAsync = ref.watch(_collectionDetailsProvider(collectionId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return collectionAsync.when(
      loading: () => Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(backgroundColor: theme.appBarTheme.backgroundColor),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(backgroundColor: theme.appBarTheme.backgroundColor),
        body: EmptyState(icon: Icons.error_outline_rounded, title: 'Error', subtitle: getFriendlyErrorMessage(e)),
      ),
      data: (data) {
        final collection = data['collection'] as Map<String, dynamic>;
        final notes = data['notes'] as List<Note>;
        final isMe = Supabase.instance.client.auth.currentUser?.id == collection['user_id'];

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(_collectionDetailsProvider(collectionId));
              await ref.read(_collectionDetailsProvider(collectionId).future);
            },
            color: AppColors.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: theme.appBarTheme.backgroundColor,
                  pinned: true,
                  expandedHeight: 200,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(collection['title'], style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 16)),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        collection['thumbnail_url'] != null
                            ? CachedNetworkImage(imageUrl: collection['thumbnail_url'], fit: BoxFit.cover)
                            : Container(color: AppColors.primarySurface, child: const Icon(Icons.auto_awesome_motion_rounded, color: AppColors.primary, size: 64)),
                        if (isMe)
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: CircleAvatar(
                              backgroundColor: Colors.black.withValues(alpha: 0.5),
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                                onPressed: () => _pickAndUploadCover(context, ref, collectionId),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  actions: [
                    if (isMe)
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        onPressed: () => _showAddNotesDialog(context, ref, collectionId),
                        tooltip: 'Add Notes',
                      ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: AppRadius.sm),
                              child: Text('${notes.length} NOTES', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary)),
                            ),
                            const SizedBox(width: 12),
                            Text('by ${collection['users']?['username'] ?? 'Unknown'}', style: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                        if (collection['description'] != null) ...[
                          const SizedBox(height: 12),
                          Text(collection['description'], style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
                        ],
                      ],
                    ),
                  ),
                ),
                if (notes.isEmpty)
                  const SliverFillRemaining(
                    child: EmptyState(
                      icon: Icons.article_outlined,
                      title: 'No notes yet',
                      subtitle: 'Add some notes to this bundle!',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(12),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final n = notes[i];
                          final interaction = ref.watch(interactionProvider)[n.id];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.surfaceDark : Colors.white,
                              borderRadius: AppRadius.lg,
                              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                            Text(n.subject, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      if (isMe)
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.danger),
                                          onPressed: () => _showRemoveDialog(context, ref, n.id, n.title),
                                        ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => context.push('/notes/${n.id}'),
                                  child: Container(
                                    height: 300,
                                    margin: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: AppRadius.md,
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: n.thumbnailUrl != null
                                        ? (n.fileType == 'pdf'
                                            ? IgnorePointer(child: SfPdfViewer.network(n.thumbnailUrl!, canShowScrollHead: false, canShowPaginationDialog: false))
                                            : CachedNetworkImage(imageUrl: n.thumbnailUrl!, fit: BoxFit.cover))
                                        : const Center(child: Icon(Icons.article_outlined, size: 48, color: AppColors.textMuted)),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _Stat(icon: Icons.favorite_rounded, value: interaction?.likesCount ?? n.likesCount, color: (interaction?.isLiked ?? n.isLiked) ? AppColors.like : AppColors.textMuted),
                                      _Stat(icon: Icons.bookmark_rounded, value: interaction?.savesCount ?? n.savesCount, color: (interaction?.isSaved ?? n.isSaved) ? AppColors.save : AppColors.textMuted),
                                      _Stat(icon: Icons.description_rounded, value: n.pageCount, color: AppColors.textMuted),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: notes.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadCover(BuildContext context, WidgetRef ref, String colId) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
    if (image == null) return;

    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploading cover image...')));
      }
      
      await ref.read(collectionsServiceProvider).uploadCollectionCover(colId, File(image.path));
      
      ref.invalidate(_collectionDetailsProvider(colId));
      ref.invalidate(userCollectionsProvider(Supabase.instance.client.auth.currentUser!.id));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cover image updated!'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e)), backgroundColor: AppColors.danger));
      }
    }
  }

  void _showRemoveDialog(BuildContext context, WidgetRef ref, String noteId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from Bundle?'),
        content: Text('Do you want to remove "$title" from this bundle? (Note will not be deleted)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client
            .from('note_collection_items')
            .delete()
            .eq('collection_id', collectionId)
            .eq('note_id', noteId);
        ref.invalidate(_collectionDetailsProvider(collectionId));
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e))));
        }
      }
    }
  }

  void _showAddNotesDialog(BuildContext context, WidgetRef ref, String colId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _AddNotesToCollectionSheet(collectionId: colId),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final dynamic value;
  final Color color;
  const _Stat({required this.icon, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text('$value', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _AddNotesToCollectionSheet extends ConsumerStatefulWidget {
  final String collectionId;
  const _AddNotesToCollectionSheet({required this.collectionId});

  @override
  ConsumerState<_AddNotesToCollectionSheet> createState() => _AddNotesToCollectionSheetState();
}

class _AddNotesToCollectionSheetState extends ConsumerState<_AddNotesToCollectionSheet> {
  final Set<String> _processingIds = {};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final myNotesAsync = ref.watch(userNotesProvider(Supabase.instance.client.auth.currentUser!.id));
    final collectionDetailsAsync = ref.watch(_collectionDetailsProvider(widget.collectionId));

    // Get IDs of notes already in the collection
    final existingNoteIds = collectionDetailsAsync.maybeWhen(
      data: (data) => (data['notes'] as List<Note>).map((n) => n.id).toSet(),
      orElse: () => <String>{},
    );

    return Container(
      padding: const EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add Notes to Bundle',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary)),
          const SizedBox(height: 16),
          Expanded(
            child: myNotesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(getFriendlyErrorMessage(e)),
              data: (notes) => ListView.builder(
                itemCount: notes.length,
                itemBuilder: (ctx, i) {
                  final n = notes[i];
                  final isAlreadyIn = existingNoteIds.contains(n.id);
                  final isProcessing = _processingIds.contains(n.id);

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(n.title,
                        style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            fontWeight: isAlreadyIn ? FontWeight.w600 : FontWeight.normal)),
                    subtitle: Text(n.subject,
                        style: TextStyle(
                            color: isDark ? AppColors.textMutedDark : AppColors.textMuted)),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        n.fileType == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                        color: AppColors.primary.withValues(alpha: 0.7),
                        size: 20,
                      ),
                    ),
                    trailing: isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                        : isAlreadyIn
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.success)
                            : const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                    onTap: isAlreadyIn || isProcessing
                        ? null
                        : () async {
                            setState(() => _processingIds.add(n.id));
                            try {
                              await Supabase.instance.client.from('note_collection_items').insert({
                                'collection_id': widget.collectionId,
                                'note_id': n.id,
                              });
                              ref.invalidate(_collectionDetailsProvider(widget.collectionId));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Note added to bundle!')));
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(getFriendlyErrorMessage(e)),
                                    backgroundColor: AppColors.danger));
                              }
                            } finally {
                              if (mounted) setState(() => _processingIds.remove(n.id));
                            }
                          },
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Done', onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}

final _collectionDetailsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final client = Supabase.instance.client;
  
  // 1. Fetch collection metadata
  final colRes = await client.from('note_collections').select().eq('id', id).single();
  
  // 2. Fetch notes in this collection
  final itemsRes = await client
      .from('note_collection_items')
      .select('notes(*, users(*))')
      .eq('collection_id', id)
      .order('sort_order', ascending: true);
  
  final notesRaw = (itemsRes as List).map((item) => Note.fromJson(item['notes'])).toList();
  final notes = await ref.read(notesServiceProvider).enrichWithInteractions(notesRaw);
  
  return {
    'collection': colRes,
    'notes': notes,
  };
});
