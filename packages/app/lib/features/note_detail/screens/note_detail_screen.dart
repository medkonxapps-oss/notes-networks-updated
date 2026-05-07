import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:design_system/design_system.dart';
import 'package:shared/shared.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/async_value_widget.dart';
import '../../../core/services/local_db_service.dart';

final _noteDetailProvider = FutureProvider.autoDispose.family<Note?, String>(
  (ref, noteId) => ref.read(notesServiceProvider).getNoteById(noteId),
);

final _notePageUrlsProvider = FutureProvider.autoDispose.family<List<String>, String>(     
  (ref, noteId) => ref.read(notesServiceProvider).getSignedPageUrls(noteId, 0),
);

class NoteDetailScreen extends ConsumerStatefulWidget {
  final String noteId;
  const NoteDetailScreen({super.key, required this.noteId});
  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen> {
  int _currentPage = 0;
  int _totalPages = 0;
  late PageController _pageController;
  final PdfViewerController _pdfController = PdfViewerController();
  PdfTextSearchResult _searchResult = PdfTextSearchResult();
  bool _isSearching = false;
  final TextEditingController _searchTextController = TextEditingController();
  bool _initialized = false;
  bool _followLoading = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pdfController.dispose();
    _searchResult.dispose();
    _searchTextController.dispose();
    super.dispose();
  }

  void _initInteraction(Note note) {
    if (!_initialized) {
      _initialized = true;
      _currentPage = 0;
      _totalPages = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(interactionProvider.notifier).seedNote(note);
      });
      final me = ref.read(supabaseClientProvider).auth.currentUser;
      
      // Track view
      ref.read(supabaseClientProvider).rpc('increment_note_view', params: {
        'p_note_id': note.id,
        'p_user_id': me?.id,
      }).catchError((_) {});

      if (me != null && me.id != note.userId) {
        _loadFollowState(note.userId);
      }
    }
  }

  Future<void> _loadFollowState(String authorId) async {
    final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (uid == null) return;
    final following = await ref.read(profileServiceProvider).isFollowing(uid, authorId);   
    if (mounted) {
      ref.read(followProvider.notifier).seed(authorId, following);
    }
  }

  Future<void> _toggleFollow(String authorId) async {
    if (_followLoading) return;
    setState(() => _followLoading = true);
    try {
      await ref.read(followProvider.notifier).toggleFollow(authorId);
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  Future<void> _toggleLike(Note note) async {
    await ref.read(interactionProvider.notifier).toggleLike(note.id);
    // Force liked notes screen to refresh on next visit
    ref.invalidate(likedNotesProvider);
  }

  Future<void> _toggleSave(Note note) async {
    await ref.read(interactionProvider.notifier).toggleSave(note.id);
    // Force saved notes screen to refresh on next visit
    ref.invalidate(savedNotesProvider);
  }

  Future<void> _printNote(Note note) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preparing print document...'), duration: Duration(seconds: 2)),
      );

      final urls = await ref.read(notesServiceProvider).getSignedPageUrls(note.id, 0);
      if (urls.isEmpty) throw 'No files found to print';

      if (note.fileType == 'pdf') {
        final response = await http.get(Uri.parse(urls.first));
        if (response.statusCode != 200) throw 'Failed to download PDF';
        
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => response.bodyBytes,
          name: '${note.title}.pdf',
        );
      } else {
        final doc = pw.Document();
        for (final url in urls) {
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            final image = pw.MemoryImage(response.bodyBytes);
            doc.addPage(
              pw.Page(
                build: (pw.Context context) {
                  return pw.Center(child: pw.Image(image));
                },
              ),
            );
          }
        }
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => doc.save(),
          name: '${note.title}.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _downloadNote(Note note) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Starting download...'), duration: Duration(seconds: 1)),
      );

      final urls = await ref.read(notesServiceProvider).getSignedPageUrls(note.id, 0);     
      if (urls.isEmpty) throw 'No files found';

      final appDocDir = await getApplicationDocumentsDirectory();
      final savePath = p.join(appDocDir.path, 'downloads', '${note.id}.${note.fileType == 'pdf' ? 'pdf' : 'zip'}');

      await Directory(p.dirname(savePath)).create(recursive: true);

      final fileInfo = await DefaultCacheManager().downloadFile(urls.first);
      final File localFile = await File(fileInfo.file.path).copy(savePath);

      final localNote = LocalNote(
        id: note.id,
        title: note.title,
        subject: note.subject,
        authorName: note.authorName ?? 'Unknown',
        localPath: localFile.path,
        fileType: note.fileType,
        downloadedAt: DateTime.now(),
      );

      await ref.read(localDbServiceProvider).saveNote(localNote);
      
      // Award points to author
      await ref.read(notesServiceProvider).processDownload(note.id);

      ref.invalidate(downloadedNotesProvider);
      ref.invalidate(isNoteDownloadedProvider(note.id));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note downloaded for offline reading!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _showJumpToPageDialog(int totalPages) {
    if (totalPages <= 1) return;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Jump to Page', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter page number (1-$totalPages)',
            hintStyle: const TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final page = int.tryParse(ctrl.text);
              if (page != null && page >= 1 && page <= totalPages) {
                _pdfController.jumpToPage(page);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Jump'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final noteAsync = ref.watch(_noteDetailProvider(widget.noteId));
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      },
      child: AsyncValueWidget(
        value: noteAsync,
        onRetry: () => ref.invalidate(_noteDetailProvider(widget.noteId)),
        loading: () => Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: theme.appBarTheme.backgroundColor,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
            ),
          ),
          body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),    
        ),
        data: (note) {
          if (note == null) {
            return Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              appBar: AppBar(
                backgroundColor: theme.appBarTheme.backgroundColor,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  },
                ),
                ),
              body: const EmptyState(icon: Icons.article_outlined, title: 'Note not found', subtitle: ''),
            );
          }
          _initInteraction(note);
          final interaction = ref.watch(interactionProvider)[note.id];
          final isLiked = interaction?.isLiked ?? note.isLiked;
          final isSaved = interaction?.isSaved ?? note.isSaved;
          final likesCount = interaction?.likesCount ?? note.likesCount;
          final savesCount = interaction?.savesCount ?? note.savesCount;
          final isDownloadedAsync = ref.watch(isNoteDownloadedProvider(note.id));
          final isDownloaded = isDownloadedAsync.value ?? false;

          return _buildDetail(note, isLiked, isSaved, likesCount, savesCount, isDownloaded); 
        },
      ),
    );
  }

  Widget _buildDetail(Note note, bool isLiked, bool isSaved, int likesCount, int savesCount, bool isDownloaded) {
    final displayTotal = (note.fileType == 'pdf' && _totalPages > 0)
        ? _totalPages
        : note.pageCount;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isDesktop ? 1000 : double.infinity),
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 56,
                  ),
                  child: _PageViewer(
                    note: note,
                    pageController: _pageController,
                    pdfController: _pdfController,
                    searchResult: _searchResult,
                    onPageChanged: (p) => setState(() => _currentPage = p),
                    onTotalPagesKnown: (total) {
                      if (_totalPages != total) {
                        setState(() => _totalPages = total);
                        if (note.pageCount != total) {
                          ref.read(notesServiceProvider).updatePageCount(note.id, total);
                        }
                      }
                    },
                  ),
                ),
              ),

              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],      
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),   
                                onPressed: () {
                                  if (_isSearching) {
                                    setState(() {
                                      _isSearching = false;
                                      _searchResult.clear();
                                      _searchTextController.clear();
                                    });
                                  } else {
                                    if (context.canPop()) {
                                      context.pop();
                                    } else {
                                      context.go('/home');
                                    }
                                  }
                                },
                              ),
                              const SizedBox(width: 4),
                              if (_isSearching)
                                Expanded(
                                  child: Theme(
                                    data: ThemeData.dark().copyWith(
                                      inputDecorationTheme: InputDecorationTheme(
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha: 0.15),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(20),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(20),
                                          borderSide: const BorderSide(color: Colors.white30, width: 1),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(20),
                                          borderSide: const BorderSide(color: Colors.white60, width: 1),
                                        ),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      ),
                                    ),
                                    child: TextField(
                                      controller: _searchTextController,
                                      autofocus: true,
                                      style: const TextStyle(color: Colors.white, fontSize: 14),
                                      cursorColor: Colors.white,
                                      decoration: const InputDecoration(
                                        hintText: 'Search in PDF...',
                                        hintStyle: TextStyle(color: Colors.white60, fontSize: 14),
                                      ),
                                      onSubmitted: (v) {
                                        if (v.trim().isNotEmpty) {
                                          _searchResult = _pdfController.searchText(v);
                                          _searchResult.addListener(() {
                                            if (mounted) setState(() {});
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                )
                              else
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _showJumpToPageDialog(displayTotal),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(note.title, style: const TextStyle(
                                          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                        Text(
                                          displayTotal > 0
                                              ? 'Page ${_currentPage + 1} of $displayTotal'
                                              : 'Loading...',
                                          style: const TextStyle(color: Colors.white70, fontSize: 12), 
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (note.fileType == 'pdf' && !_isSearching)
                                IconButton(
                                  icon: const Icon(Icons.search_rounded, color: Colors.white),
                                  onPressed: () => setState(() => _isSearching = true),
                                ),
                              if (_isSearching && _searchResult.hasResult) ...[
                                IconButton(
                                  icon: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white),
                                  onPressed: () => _searchResult.previousInstance(),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                                  onPressed: () => _searchResult.nextInstance(),
                                ),
                                Text(
                                  '${_searchResult.currentInstanceIndex}/${_searchResult.totalInstanceCount}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ],
                              if (_isSearching)
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                                  onPressed: () {
                                    setState(() {
                                      _isSearching = false;
                                      _searchResult.clear();
                                      _searchTextController.clear();
                                    });
                                  },
                                )
                              else
                                IconButton(
                                  icon: const Icon(Icons.info_outline_rounded, color: Colors.white), 
                                  onPressed: () => _showInfo(note),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],      
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              final me = ref.read(supabaseClientProvider).auth.currentUser;    
                              final targetId = note.userId;
                              if (me?.id == targetId) {
                                context.go('/profile/me');
                              } else {
                                context.go('/profile/$targetId');
                              }
                            },
                            child: Row(children: [
                              AppAvatar(
                                imageUrl: note.authorAvatarUrl,
                                name: note.authorName ?? '',
                                size: 36, isVerified: note.authorIsVerified),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(note.authorName ?? '', style: const TextStyle(        
                                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                    Text('${note.subject} · ${note.classLevel}',
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              if (ref.read(supabaseClientProvider).auth.currentUser?.id != note.userId)
                                Consumer(
                                  builder: (context, ref, child) {
                                    final isFollowing = ref.watch(followProvider)[note.userId];
                                    return _FollowButton(
                                      isFollowing: isFollowing,
                                      isLoading: _followLoading,
                                      onTap: () => _toggleFollow(note.userId),
                                    );
                                  },
                                ),
                            ]),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Expanded(
                                child: _ActionBtn(
                                  icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  label: _formatCount(likesCount),
                                  color: isLiked ? AppColors.like : Colors.white,
                                  onTap: () => _toggleLike(note),
                                ),
                              ),
                              Expanded(
                                child: _ActionBtn(
                                  icon: isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                  label: _formatCount(savesCount),
                                  color: isSaved ? AppColors.save : Colors.white,
                                  onTap: () => _toggleSave(note),
                                ),
                              ),
                              Expanded(
                                child: _ActionBtn(
                                  icon: isDownloaded ? Icons.download_done_rounded : Icons.download_for_offline_rounded,
                                  label: isDownloaded ? 'Offline' : 'Save',
                                  color: isDownloaded ? AppColors.success : Colors.white,        
                                  onTap: isDownloaded ? null : () => _downloadNote(note),        
                                ),
                              ),
                              Expanded(
                                child: _ActionBtn(
                                  icon: Icons.share_rounded,
                                  label: 'Share',
                                  color: Colors.white,
                                  onTap: () => SharePlus.instance.share(
                                    ShareParams(
                                      text: '${note.title}\nhttps://notesnet.app/notes/${note.id}',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInfo(Note note) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(note.title,
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),       
            const SizedBox(height: 8),
            if (note.description != null && note.description!.isNotEmpty)
              Text(note.description!,
                style: TextStyle(
                  fontSize: 14, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
            const SizedBox(height: 16),
            _infoRow(context, 'Subject', note.subject),
            _infoRow(context, 'Class', note.classLevel),
            _infoRow(context, 'Board', note.board),
            _infoRow(context, 'Pages', '${note.pageCount}'),
            _infoRow(context, 'Type', note.fileType.toUpperCase()),
            if (note.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6,
                children: note.tags.map((t) => TagChip(label: '#$t')).toList()),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _printNote(note);
                    },
                    icon: const Icon(Icons.print_rounded, size: 20),
                    label: const Text('Print Note', style: TextStyle(fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: isDark ? AppColors.primary : AppColors.primary),
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showReportDialog(note);
                    },
                    icon: const Icon(Icons.report_problem_rounded, color: AppColors.danger, size: 20),
                    label: const Text('Report Post', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: AppColors.danger.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(Note note) {
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
                      note.id, 
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

  Widget _infoRow(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 80, child: Text(label,
          style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMuted))),
        Expanded(
          child: Text(value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  String _formatCount(int n) => n >= 1000 ? '${(n/1000).toStringAsFixed(1)}k' : '$n';      
}

class _PageViewer extends ConsumerStatefulWidget {
  final Note note;
  final PageController pageController;
  final PdfViewerController pdfController;
  final PdfTextSearchResult searchResult;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onTotalPagesKnown;

  const _PageViewer({
    required this.note,
    required this.pageController,
    required this.pdfController,
    required this.searchResult,
    required this.onPageChanged,
    required this.onTotalPagesKnown,
  });

  @override
  ConsumerState<_PageViewer> createState() => _PageViewerState();
}

class _PageViewerState extends ConsumerState<_PageViewer> {
  // For PDF: we download to a local temp file so SfPdfViewer.file works
  // reliably on all Android/iOS versions (network viewer can fail silently).
  File? _localPdfFile;
  bool _pdfLoading = false;
  String? _pdfError;

  Future<void> _downloadPdf(String url) async {
    if (_pdfLoading || _localPdfFile != null) return;
    setState(() { _pdfLoading = true; _pdfError = null; });
    try {
      final fileInfo = await DefaultCacheManager().downloadFile(url);
      // Copy to a stable path with .pdf extension so SfPdfViewer recognises it
      final dir = await getTemporaryDirectory();
      final dest = File(p.join(dir.path, '${widget.note.id}.pdf'));
      await fileInfo.file.copy(dest.path);
      if (mounted) setState(() { _localPdfFile = dest; _pdfLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _pdfError = e.toString(); _pdfLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final urlsAsync = ref.watch(_notePageUrlsProvider(widget.note.id));
    return urlsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(e.toString(),
                style: const TextStyle(color: Colors.white54, fontSize: 11),
                textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
      data: (urls) {
        if (urls.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.article_outlined, color: Colors.white54, size: 64),
                SizedBox(height: 12),
                Text('No preview available', style: TextStyle(color: Colors.white54)),
              ],
            ),
          );
        }

        if (widget.note.fileType == 'pdf') {
          // Trigger download if not started yet
          if (!_pdfLoading && _localPdfFile == null && _pdfError == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _downloadPdf(urls.first));
          }

          Widget viewer;
          if (_pdfError != null) {
            // Fallback: try network viewer directly if local download failed
            viewer = SfPdfViewer.network(
              urls.first,
              controller: widget.pdfController,
              pageLayoutMode: PdfPageLayoutMode.continuous,
              scrollDirection: PdfScrollDirection.vertical,
              canShowScrollHead: true,
              canShowScrollStatus: true,
              canShowPaginationDialog: false,
              enableDoubleTapZooming: true,
              pageSpacing: 4,
              onDocumentLoaded: (details) {
                widget.onTotalPagesKnown(details.document.pages.count);
              },
              onPageChanged: (details) {
                widget.onPageChanged(details.newPageNumber - 1);
              },
            );
          } else if (_pdfLoading || _localPdfFile == null) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Loading PDF...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            );
          } else {
            viewer = SfPdfViewer.file(
              _localPdfFile!,
              controller: widget.pdfController,
              pageLayoutMode: PdfPageLayoutMode.continuous,
              scrollDirection: PdfScrollDirection.vertical,
              canShowScrollHead: true,
              canShowScrollStatus: true,
              canShowPaginationDialog: false,
              enableDoubleTapZooming: true,
              pageSpacing: 4,
              onDocumentLoaded: (details) {
                widget.onTotalPagesKnown(details.document.pages.count);
              },
              onPageChanged: (details) {
                widget.onPageChanged(details.newPageNumber - 1);
              },
            );
          }

          return Container(
            color: const Color(0xFF1A1A1A), // Fixed dark background for better contrast in light mode
            child: viewer,
          );
        }

        // Image set — swipeable pages
        return PageView.builder(
          controller: widget.pageController,
          onPageChanged: widget.onPageChanged,
          itemCount: urls.length,
          itemBuilder: (_, i) => InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(
              urls[i],
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
              errorBuilder: (_, error, __) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                    const SizedBox(height: 8),
                    Text(error.toString(),
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                      textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionBtn({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  final bool? isFollowing;
  final bool isLoading;
  final VoidCallback onTap;

  const _FollowButton({
    required this.isFollowing,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading || isFollowing == null) {
      return const SizedBox(
        width: 72,
        height: 30,
        child: Center(child: SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        )),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        constraints: const BoxConstraints(maxWidth: 100),
        decoration: BoxDecoration(
          color: isFollowing! ? Colors.transparent : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Text(
          isFollowing! ? 'Following' : 'Follow',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isFollowing! ? Colors.white : Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
