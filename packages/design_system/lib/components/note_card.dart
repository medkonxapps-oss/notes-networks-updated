import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/border_radius.dart';
import 'avatar.dart';
import 'tag_chip.dart';

class NoteCardData {
  final String id;
  final String title;
  final String subject;
  final String authorName;
  final String authorId;
  final String? authorAvatarUrl;
  final bool isAuthorVerified;
  final String? thumbnailUrl;
  final int likesCount;
  final int savesCount;
  final int pageCount;
  final String fileType;
  final bool isLiked;
  final bool isSaved;
  final bool isSponsored;
  final List<String> tags;
  final DateTime createdAt;

  const NoteCardData({
    required this.id,
    required this.title,
    required this.subject,
    required this.authorName,
    required this.authorId,
    this.authorAvatarUrl,
    this.isAuthorVerified = false,
    this.thumbnailUrl,
    this.likesCount = 0,
    this.savesCount = 0,
    this.pageCount = 1,
    this.fileType = 'pdf',
    this.isLiked = false,
    this.isSaved = false,
    this.isSponsored = false,
    this.tags = const [],
    required this.createdAt,
  });
}

class NoteCard extends StatefulWidget {
  final NoteCardData note;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onReport;

  const NoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.onLike,
    this.onSave,
    this.onAuthorTap,
    this.onReport,
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  bool get _isLiked => widget.note.isLiked;
  bool get _isSaved => widget.note.isSaved;
  int get _likesCount => widget.note.likesCount;
  int get _savesCount => widget.note.savesCount;

  DateTime? _lastLikeTap;
  DateTime? _lastSaveTap;

  void _handleLike() {
    final now = DateTime.now();
    if (_lastLikeTap != null && now.difference(_lastLikeTap!).inMilliseconds < 500) return;
    _lastLikeTap = now;
    widget.onLike?.call();
  }

  void _handleSave() {
    final now = DateTime.now();
    if (_lastSaveTap != null && now.difference(_lastSaveTap!).inMilliseconds < 500) return;
    _lastSaveTap = now;
    widget.onSave?.call();
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onReport,
      child: Container(        margin: const EdgeInsets.only(bottom: 16),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: AppRadius.xl,
          border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
          boxShadow: isDark ? [] : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildThumbnail(context, note),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: _subjectChip(context, note.subject)),
                    if (note.isSponsored) ...[
                      const SizedBox(width: 6),
                      _sponsoredChip(context),
                    ],
                    const Spacer(),
                    _pageCountBadge(context, note.pageCount),
                  ]),
                  const SizedBox(height: 8),
                  Text(note.title,
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary, height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  if (note.tags.isNotEmpty) ...[
                    Wrap(
                      spacing: 6, runSpacing: 4,
                      children: note.tags.take(3)
                          .map((t) => TagChip(label: '#$t'))
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: widget.onAuthorTap,
                        child: Row(children: [
                          AppAvatar(
                            imageUrl: note.authorAvatarUrl,
                            name: note.authorName,
                            size: 28,
                            isVerified: note.isAuthorVerified,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(note.authorName,
                              style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _actionButton(
                      icon: _isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      count: _likesCount,
                      color: _isLiked ? AppColors.like : (isDark ? AppColors.textMutedDark : AppColors.textMuted), 
                      onTap: _handleLike,
                    ),
                    const SizedBox(width: 12),
                    _actionButton(
                      icon: _isSaved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      count: _savesCount,
                      color: _isSaved ? AppColors.save : (isDark ? AppColors.textMutedDark : AppColors.textMuted), 
                      onTap: _handleSave,
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

    Widget _buildThumbnail(BuildContext context, NoteCardData note) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (note.thumbnailUrl != null && note.thumbnailUrl!.isNotEmpty) {
      if (note.fileType == 'pdf') {
        return SizedBox(
          width: double.infinity,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: IgnorePointer(
              child: SfPdfViewer.network(
                note.thumbnailUrl!,
                canShowScrollHead: false,
                canShowPaginationDialog: false,
                enableDoubleTapZooming: false,
              ),
            ),
          ),
        );
      }

      return SizedBox(
        width: double.infinity,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: CachedNetworkImage(
            imageUrl: note.thumbnailUrl!,
            memCacheWidth: 800,
            fit: BoxFit.cover,
            width: double.infinity,
            placeholder: (_, __) => Container(
              color: isDark ? const Color(0xFF2D2D4D) : AppColors.primarySurface,
              child: const Center(child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2))),
            errorWidget: (_, __, ___) => _thumbPlaceholder(context, note),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: _thumbPlaceholder(context, note),
      ),
    );
  }

  Widget _thumbPlaceholder(BuildContext context, NoteCardData note) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF2D2D4D) : AppColors.primarySurface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            note.fileType == 'pdf'
                ? Icons.picture_as_pdf_rounded
                : Icons.photo_library_rounded,
            size: 40, color: AppColors.primary,
          ),
          const SizedBox(height: 8),
          Text(note.title,
            style: const TextStyle(fontSize: 12, color: AppColors.primary,
              fontWeight: FontWeight.w600),
            textAlign: TextAlign.center, maxLines: 2),
        ],
      ),
    );
  }

  Widget _subjectChip(BuildContext context, String subject) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D4D) : AppColors.primarySurface,
        borderRadius: AppRadius.full),
      child: Text(subject,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
    );
  }

  Widget _sponsoredChip(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3D2D0B) : AppColors.accentBg,
        borderRadius: AppRadius.full),
      child: const Text('Sponsored', style: TextStyle(
        fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.accent)),
    );
  }

  Widget _pageCountBadge(BuildContext context, int count) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = count == 1 ? '1 Page' : '$count Pages';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.library_books_rounded, size: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMuted),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(
          fontSize: 11, color: isDark ? AppColors.textMutedDark : AppColors.textMuted, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 3),
          Text(_fmt(count),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}









