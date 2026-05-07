import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';
import 'package:shared/shared.dart';
import '../../../shared/providers/providers.dart';

final _savedViewModeProvider = StateProvider<bool>((ref) => false);

class SavedNotesScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const SavedNotesScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<SavedNotesScreen> createState() => _SavedNotesScreenState();
}

class _SavedNotesScreenState extends ConsumerState<SavedNotesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Library', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? AppColors.textMutedDark : AppColors.textMuted,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Saved'),
            Tab(text: 'Liked'),
          ],
        ),
        actions: [
          Consumer(builder: (context, ref, _) {
            final isGrid = ref.watch(_savedViewModeProvider);
            return IconButton(
              icon: Icon(isGrid ? Icons.view_list_rounded : Icons.grid_view_rounded),
              onPressed: () => ref.read(_savedViewModeProvider.notifier).state = !isGrid,
            );
          }),
        ],
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _SavedTab(isSaved: true),
          _SavedTab(isSaved: false), // Liked tab
        ],
      ),
    );
  }
}

class _SavedTab extends ConsumerWidget {
  final bool isSaved;
  const _SavedTab({required this.isSaved});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = isSaved ? ref.watch(savedNotesProvider) : ref.watch(likedNotesProvider);
    final isGrid = ref.watch(_savedViewModeProvider);

    return RefreshIndicator(
      onRefresh: () async {
        if (isSaved) {
          ref.invalidate(savedNotesProvider);
          await ref.read(savedNotesProvider.future);
        } else {
          ref.invalidate(likedNotesProvider);
          await ref.read(likedNotesProvider.future);
        }
      },
      color: AppColors.primary,
      child: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Error',
            subtitle: err.toString(),
          ),
        ),
        data: (notes) {
          if (notes.isEmpty) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: EmptyState(
                  icon: isSaved ? Icons.bookmark_border_rounded : Icons.favorite_border_rounded,
                  title: isSaved ? 'No saved notes' : 'No liked notes',
                  subtitle: isSaved ? 'Notes you save will appear here.' : 'Notes you like will appear here.',
                ),
              ),
            );
          }

          if (isGrid) return _buildGrid(context, ref, notes);
          return _buildList(context, ref, notes);
        },
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<Note> notes) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final n = notes[index];
        final interaction = ref.watch(interactionProvider)[n.id];
        return NoteCard(
          note: NoteCardData(
            id: n.id,
            title: n.title,
            subject: n.subject,
            authorName: n.authorName ?? 'Unknown',
            authorId: n.userId,
            authorAvatarUrl: n.authorAvatarUrl,
            isAuthorVerified: n.authorIsVerified,
            thumbnailUrl: n.thumbnailUrl,
            likesCount: interaction?.likesCount ?? n.likesCount,
            savesCount: interaction?.savesCount ?? n.savesCount,
            pageCount: n.pageCount,
            fileType: n.fileType,
            isLiked: interaction?.isLiked ?? n.isLiked,
            isSaved: interaction?.isSaved ?? n.isSaved,
            isSponsored: n.isSponsored,
            tags: n.tags,
            createdAt: n.createdAt,
          ),
          onTap: () => context.push('/notes/${n.id}'),
          onLike: () => ref.read(interactionProvider.notifier).toggleLike(n.id),
          onSave: () => ref.read(interactionProvider.notifier).toggleSave(n.id),
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context, WidgetRef ref, List<Note> notes) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final n = notes[index];
        final interaction = ref.watch(interactionProvider)[n.id];
        final isLiked = interaction?.isLiked ?? n.isLiked;
        final likesCount = interaction?.likesCount ?? n.likesCount;

        return GestureDetector(
          onTap: () => context.push('/notes/${n.id}'),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: AppRadius.lg,
              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: (n.thumbnailUrl != null && n.thumbnailUrl!.isNotEmpty)
                              ? ((n.thumbnailUrl!.toLowerCase().contains(".pdf") && !n.thumbnailUrl!.toLowerCase().contains(".jpg") && !n.thumbnailUrl!.toLowerCase().contains(".png"))
                                  ? IgnorePointer(
                                      child: SfPdfViewer.network(
                                        n.thumbnailUrl!,
                                        canShowScrollHead: false,
                                        canShowPaginationDialog: false,
                                        enableDoubleTapZooming: false,
                                      ),
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: n.thumbnailUrl!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      memCacheWidth: 600,
                                      placeholder: (_, __) => Container(
                                        color: isDark ? const Color(0xFF1E1E35) : AppColors.primarySurface,
                                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                      ),
                                      errorWidget: (_, __, ___) => _placeholder(context, n),
                                    ))
                              : _placeholder(context, n),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${n.pageCount}P',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 12,
                            color: isLiked ? AppColors.like : (isDark ? AppColors.textMutedDark : AppColors.textMuted),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$likesCount',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.bookmark_rounded,
                            size: 12,
                            color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${n.savesCount}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _placeholder(BuildContext context, Note n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF2D2D4D) : AppColors.primarySurface,
      child: Center(
        child: Icon(
          n.fileType == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.photo_library_rounded,
          color: AppColors.primary,
          size: 32,
        ),
      ),
    );
  }
}



