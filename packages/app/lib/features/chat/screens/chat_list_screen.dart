import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';
import '../../../shared/providers/providers.dart';
import 'package:intl/intl.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(chatRoomsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: const Text('Messages'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(chatRoomsProvider);
          await ref.read(chatRoomsProvider.future);
        },
        color: AppColors.primary,
        child: roomsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (rooms) {
            if (rooms.isEmpty) {
              return const SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: 400,
                  child: EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'No messages yet',
                    subtitle: 'Start a conversation with a teacher to solve your doubts.',
                  ),
                ),
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: rooms.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final room = rooms[i];
                final otherUser = room.otherUser;
                if (otherUser == null) return const SizedBox.shrink();

                final unreadCountAsync = ref.watch(roomUnreadCountProvider(room.id));

                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: AppRadius.lg,
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
                  ),
                  child: ListTile(
                    onTap: () => context.push('/chat/${room.id}', extra: otherUser),
                    leading: AppAvatar(imageUrl: otherUser.avatarUrl, name: otherUser.fullName, size: 48),
                    title: Text(
                      otherUser.fullName,
                      style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimary),
                    ),
                    subtitle: Text(
                      room.lastMessageText ?? 'Start chatting...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMuted, fontSize: 13),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (room.lastMessageAt != null)
                          Text(
                            DateFormat.jm().format(room.lastMessageAt!),
                            style: TextStyle(fontSize: 11, color: isDark ? AppColors.textMutedDark : AppColors.textMuted),
                          ),
                        const SizedBox(height: 4),
                        unreadCountAsync.when(
                          data: (count) => count > 0 
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              )
                            : const SizedBox(height: 14),
                          loading: () => const SizedBox(height: 14),
                          error: (_, __) => const SizedBox(height: 14),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
