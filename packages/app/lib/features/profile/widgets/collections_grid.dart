import 'package:flutter/material.dart';
import 'package:app/shared/utils/error_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:design_system/design_system.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../shared/providers/providers.dart';

class CollectionsGrid extends ConsumerWidget {
  final String userId;
  final bool isMe;

  const CollectionsGrid({super.key, required this.userId, required this.isMe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(userCollectionsProvider(userId));

    return collectionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text(getFriendlyErrorMessage(e))),
      data: (collections) {
        if (collections.isEmpty) {
          return EmptyState(
            icon: Icons.auto_awesome_motion_rounded,
            title: 'No Collections',
            subtitle: isMe ? 'Group your notes into public bundles!' : 'This user hasn''t created any bundles yet.',
          );
        }

        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: collections.length,
          itemBuilder: (context, index) {
            final col = collections[index];
            return _CollectionCard(collection: col);
          },
        );
      },
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final Map<String, dynamic> collection;

  const _CollectionCard({required this.collection});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = collection['title'] as String? ?? 'Untitled';
    final itemsCount = collection['items_count'] as int? ?? 0;
    final thumb = collection['thumbnail_url'] as String?;

    return GestureDetector(
      onTap: () => context.push('/collections/${collection['id']}'),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: AppRadius.lg,
          border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: thumb != null
                    ? CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover, width: double.infinity)
                    : Container(
                        color: AppColors.primarySurface,
                        child: const Center(child: Icon(Icons.auto_awesome_motion_rounded, color: AppColors.primary, size: 32)),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? Colors.white : AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$itemsCount notes',
                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

