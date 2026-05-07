import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/async_value_widget.dart';
import '../widgets/feed_filter_bar.dart';

class HomeFeedScreen extends ConsumerStatefulWidget {
  const HomeFeedScreen({super.key});
  @override
  ConsumerState<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends ConsumerState<HomeFeedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _scrollController = ScrollController();
  String? _selectedSubject;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(feedProvider.notifier)
            .switchType(_tabController.index == 0 ? 'for_you' : 'following');
      }
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(feedProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(feedProvider);
    final viewMode = ref.watch(feedViewModeProvider);
    final unreadChatAsync = ref.watch(unreadChatCountProvider);
    final unreadChat = unreadChatAsync.value ?? 0;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxScrolled) => [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: theme.appBarTheme.backgroundColor,
            elevation: 0,
            title: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: AppRadius.sm),
                child: const Icon(Icons.sticky_note_2_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('NotesNet', 
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ), 
            ]),
            actions: [
              IconButton(
                icon: Stack(
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, 
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
                    if (unreadChat > 0)
                      Positioned(
                        right: 0, top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                          constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                          child: Text(
                            unreadChat > 9 ? '9+' : '$unreadChat',
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () => context.push('/chat'),
                tooltip: 'Chats',
              ),
              IconButton(
                icon: Icon(Icons.quiz_rounded, 
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
                onPressed: () => context.push('/forums'),
                tooltip: 'Forums',
              ),
              IconButton(
                icon: Icon(Icons.leaderboard_rounded, 
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary), 
                onPressed: () => context.push('/leaderboard'),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: isDark ? AppColors.textMutedDark : AppColors.textMuted,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),      
              tabs: const [Tab(text: 'For You'), Tab(text: 'Following')],
            ),
          ),
          SliverToBoxAdapter(
            child: FeedFilterBar(
              selectedSubject: _selectedSubject,
              onSubjectChanged: (s) {
                setState(() => _selectedSubject = s);
                ref.read(feedProvider.notifier).setSubject(s);
              },
            ),
          ),
        ],
        body: AsyncValueWidget(
          value: feedAsync,
          loading: () => ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 5,
            itemBuilder: (_, __) => const SkeletonCard(),
          ),
          onRetry: () => ref.read(feedProvider.notifier).refresh(),
          data: (notes) {
            if (notes.isEmpty) {
              return EmptyState(
                icon: Icons.article_outlined,
                title: 'No notes yet',
                subtitle: _tabController.index == 1
                    ? 'Follow creators to see their notes here'
                    : 'Be the first to upload notes!',
                buttonLabel: 'Upload Notes',
                onButtonPressed: () => context.go('/upload'),
              );
            }
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => ref.read(feedProvider.notifier).refresh(),
              child: viewMode == FeedViewMode.grid
                  ? _buildGrid(context, notes)
                  : _buildList(context, notes),
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List notes) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(interactionProvider.notifier).seed(notes.cast());
    });
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        final interaction = ref.watch(interactionProvider)[note.id];
        return NoteCard(
          note: NoteCardData(
            id: note.id,
            title: note.title,
            subject: note.subject,
            authorName: note.authorName ?? 'Unknown',
            authorId: note.userId,
            authorAvatarUrl: note.authorAvatarUrl,
            isAuthorVerified: note.authorIsVerified,
            thumbnailUrl: note.thumbnailUrl,
            likesCount: interaction?.likesCount ?? note.likesCount,
            savesCount: interaction?.savesCount ?? note.savesCount,
            pageCount: note.pageCount,
            fileType: note.fileType,
            isLiked: interaction?.isLiked ?? note.isLiked,
            isSaved: interaction?.isSaved ?? note.isSaved,
            isSponsored: note.isSponsored,
            tags: note.tags,
            createdAt: note.createdAt,
          ),
          onTap: () => context.push('/notes/${note.id}'),
          onAuthorTap: () {
            final me = ref.read(supabaseClientProvider).auth.currentUser;
            if (me?.id == note.userId) {
              context.push('/profile/me');
            } else {
              context.push('/profile/${note.userId}');
            }
          },
          onLike: () => ref.read(interactionProvider.notifier).toggleLike(note.id),        
          onSave: () => ref.read(interactionProvider.notifier).toggleSave(note.id),        
          onReport: () => _showReportDialog(context, note.id),
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context, List notes) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    
    int crossAxisCount = 2;
    if (width > 1200) {
      crossAxisCount = 5;
    } else if (width > 900) {
      crossAxisCount = 4;
    } else if (width > 600) {
      crossAxisCount = 3;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(interactionProvider.notifier).seed(notes.cast());
    });

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount, 
            crossAxisSpacing: 12, 
            mainAxisSpacing: 12, 
            childAspectRatio: 0.68),
          itemCount: notes.length,
          itemBuilder: (context, i) {
            final note = notes[i];
            final interaction = ref.watch(interactionProvider)[note.id];
            final isLiked = interaction?.isLiked ?? note.isLiked;
            final likesCount = interaction?.likesCount ?? note.likesCount;
            
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => context.push('/notes/${note.id}'),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white, 
                    borderRadius: AppRadius.lg,
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12, offset: const Offset(0, 4))
                    ]
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
                                child: (note.thumbnailUrl != null && note.thumbnailUrl!.isNotEmpty)
                                    ? (note.fileType == 'pdf'
                                        ? IgnorePointer(
                                            child: SfPdfViewer.network(
                                              note.thumbnailUrl!,
                                              canShowScrollHead: false,
                                              canShowPaginationDialog: false,
                                              enableDoubleTapZooming: false,
                                            ),
                                          )
                                        : CachedNetworkImage(
                                        imageUrl: note.thumbnailUrl!,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 600,
                                        placeholder: (_, __) => Container(
                                            color: isDark ? const Color(0xFF1E1E35) : AppColors.primarySurface,
                                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                                        errorWidget: (_, __, ___) => Container(
                                            color: isDark ? const Color(0xFF1E1E35) : AppColors.primarySurface,
                                            child: Center(child: Icon(
                                              note.fileType == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.photo_library_rounded,
                                              color: AppColors.primary.withValues(alpha: 0.5), size: 32))),
                                      ))
                                    : Container(
                                        color: isDark ? const Color(0xFF1E1E35) : AppColors.primarySurface,
                                        child: Center(child: Icon(
                                          note.fileType == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.photo_library_rounded,
                                          color: AppColors.primary.withValues(alpha: 0.5), size: 32))),
                              ),
                            ),
                            Positioned(
                              top: 10, right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7), 
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min, 
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.library_books_rounded, size: 11, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${note.pageCount}P', 
                                      style: const TextStyle(
                                        color: Colors.white, 
                                        fontSize: 10, 
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.2,
                                      )
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [  
                          Text(note.title, 
                            style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary), 
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Row(children: [
                            Expanded(
                              child: Text(note.subject, 
                                style: TextStyle(
                                  fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMuted),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            const Spacer(),
                            Icon(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                size: 12, color: isLiked ? AppColors.like : (isDark ? AppColors.textMutedDark : AppColors.textMuted)),
                            const SizedBox(width: 4),
                            Text('$likesCount', 
                              style: TextStyle(
                                fontSize: 11, color: isDark ? AppColors.textMutedDark : AppColors.textMuted)),
                          ]),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context, String noteId) {
    String reason = 'spam';
    final detailsCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Report Note', 
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
                const SizedBox(height: 16),
                Column(
                  children: ['spam', 'inappropriate', 'copyright', 'misleading', 'other']  
                      .map((r) => 
                          // ignore: deprecated_member_use
                          RadioListTile<String>(
                            value: r,
                            // ignore: deprecated_member_use
                            groupValue: reason,
                            title: Text(r[0].toUpperCase() + r.substring(1),
                              style: TextStyle(color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary, fontSize: 14)),
                            activeColor: AppColors.primary,
                            // ignore: deprecated_member_use
                            onChanged: (v) => setState(() => reason = v!),
                            contentPadding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: detailsCtrl,
                  maxLines: 2,
                  maxLength: 200,
                  decoration: InputDecoration(
                    hintText: 'Add details (optional)',
                    hintStyle: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMuted, fontSize: 13),
                    counterStyle: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMuted),
                  ),
                  style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Submit Report',
                  onPressed: () async {
                    await ref.read(notesServiceProvider).reportNote(
                      noteId, 
                      reason, 
                      detailsCtrl.text.trim().isEmpty ? null : detailsCtrl.text.trim()
                    );   
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text('Report submitted. Thank you.'),
                        backgroundColor: AppColors.success,
                      ));
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}






