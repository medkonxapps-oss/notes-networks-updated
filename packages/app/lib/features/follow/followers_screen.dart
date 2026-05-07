import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';
import '../../shared/providers/providers.dart';

/// Shows either followers or following list for a user.
class FollowListScreen extends ConsumerWidget {
  final String userId;
  final bool showFollowers; // true = followers, false = following

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.showFollowers,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final listAsync = showFollowers
        ? ref.watch(followersListProvider(userId))
        : ref.watch(followingListProvider(userId));
    final currentUid =
        ref.read(supabaseClientProvider).auth.currentUser?.id;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: Text(
          showFollowers ? 'Followers' : 'Following',
          style: TextStyle(
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor:
            isDark ? AppColors.surfaceDark : Colors.white,
        iconTheme: IconThemeData(
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimary,
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: isDark ? AppColors.borderDark : AppColors.border,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (showFollowers) {
            ref.invalidate(followersListProvider(userId));
            await ref.read(followersListProvider(userId).future);
          } else {
            ref.invalidate(followingListProvider(userId));
            await ref.read(followingListProvider(userId).future);
          }
        },
        color: AppColors.primary,
        child: listAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (e, _) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: 400,
              child: EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Error',
                subtitle: e.toString(),
              ),
            ),
          ),
          data: (users) {
            if (users.isEmpty) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: 400,
                  child: EmptyState(
                    icon: showFollowers
                        ? Icons.people_outline_rounded
                        : Icons.person_add_alt_rounded,
                    title: showFollowers ? 'No followers yet' : 'Not following anyone',
                    subtitle: showFollowers
                        ? 'Share your profile to get followers!'
                        : 'Follow people to see their notes.',
                  ),
                ),
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: users.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 72,
                color: isDark ? AppColors.borderDark : AppColors.border,
              ),
              itemBuilder: (ctx, i) {
                final u = users[i];
                final isMe = u.id == currentUid;
                final followState = ref.watch(followProvider)[u.id];

                return ListTile(
                  onTap: () => context.push('/profile/${u.id}'),
                  leading: AppAvatar(
                    imageUrl: u.avatarUrl,
                    name: u.fullName,
                    size: 52,
                    isVerified: u.isVerifiedCreator,
                  ),
                  title: Text(
                    u.fullName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '@${u.username}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textMutedDark
                          : AppColors.textMuted,
                    ),
                  ),
                  trailing: isMe
                      ? null
                      : _FollowButton(userId: u.id, followState: followState),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _FollowButton extends ConsumerWidget {
  final String userId;
  final bool? followState;
  const _FollowButton({required this.userId, this.followState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (followState == null) {
      // Seed follow state if not known
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final uid =
            ref.read(supabaseClientProvider).auth.currentUser?.id;
        if (uid == null) return;
        final isFollowing = await ref
            .read(profileServiceProvider)
            .isFollowing(uid, userId);
        if (context.mounted) {
          ref.read(followProvider.notifier).seed(userId, isFollowing);
        }
      });
      return const SizedBox(
        width: 68,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    final isFollowing = followState!;
    return SizedBox(
      height: 34,
      child: OutlinedButton(
        onPressed: () =>
            ref.read(followProvider.notifier).toggleFollow(userId),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          backgroundColor: isFollowing
              ? Colors.transparent
              : AppColors.primary,
          foregroundColor: isFollowing
              ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)
              : Colors.white,
          side: BorderSide(
            color: isFollowing
                ? (isDark ? AppColors.borderDark : AppColors.border)
                : AppColors.primary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(isFollowing ? 'Following' : 'Follow'),
      ),
    );
  }
}
