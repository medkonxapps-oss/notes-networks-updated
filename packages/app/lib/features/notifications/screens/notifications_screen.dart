import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';
import 'package:shared/shared.dart';
import '../../../shared/providers/providers.dart';

final _notificationsStreamProvider = StreamProvider.autoDispose<List<AppNotification>>((ref) {
  final client = ref.read(supabaseClientProvider);
  final uid = client.auth.currentUser?.id;
  if (uid == null) return const Stream.empty();
  return client.from('notifications').stream(primaryKey: ['id']).eq('user_id', uid).order('created_at', ascending: false).limit(50).map((rows) => rows.map((e) => AppNotification.fromJson(e)).toList());
});

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Mark all as read when user enters the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAllAsRead();
    });
  }

  Future<void> _markAllAsRead() async {
    try {
      await ref.read(notificationServiceProvider).markAllRead();
      if (mounted) {
        ref.invalidate(unreadNotifCountProvider);
      }
    } catch (e) {
      debugPrint('Error marking notifications as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifsAsync = ref.watch(_notificationsStreamProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final unreadCount = ref.watch(unreadNotifCountProvider).value ?? 0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        title: Text(
          unreadCount > 0 ? 'Notifications ($unreadCount)' : 'Notifications',
          style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
        ),
      ),

      body: notifsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: 'Error', subtitle: e.toString()),
        data: (notifs) {
          if (notifs.isEmpty) return const EmptyState(icon: Icons.notifications_none_rounded, title: 'No notifications yet', subtitle: 'You''ll be notified when someone likes or saves your notes');
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
               ref.invalidate(_notificationsStreamProvider);
               await _markAllAsRead();
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: notifs.length,
              itemBuilder: (ctx, i) => _NotifCard(notif: notifs[i]),
            ),
          );
        },
      ),
    );
  }
}

class _NotifCard extends ConsumerWidget {
  final AppNotification notif;
  const _NotifCard({required this.notif});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = _iconForType(notif.type);
    final color = _colorForType(notif.type);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () async {
        if (!notif.isRead) {
          await ref.read(notificationServiceProvider).markRead(notif.id);
          ref.invalidate(unreadNotifCountProvider);
        }
        if (!context.mounted) return;
        if (notif.referenceId != null) {
          switch (notif.type) {
            case 'like': 
            case 'save':
            case 'comment':
            case 'system': context.push('/notes/${notif.referenceId}'); break;
            case 'forum': context.push('/forums/${notif.referenceId}'); break;
            case 'follow': context.push('/profile/${notif.referenceId}'); break;
            case 'reward': context.push('/rewards'); break;
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: notif.isRead ? (isDark ? AppColors.surfaceDark : Colors.white) : (isDark ? const Color(0xFF2D2D4D) : AppColors.primarySurface),
          borderRadius: AppRadius.md,
          border: Border.all(color: notif.isRead ? (isDark ? AppColors.borderDark : AppColors.border) : AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          leading: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(notif.title, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary), maxLines: 1),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notif.message, style: TextStyle(fontSize: 13, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary), maxLines: 2),
              const SizedBox(height: 4),
              Text(_timeAgo(notif.createdAt), style: TextStyle(fontSize: 10, color: isDark ? AppColors.textMutedDark : AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'like': return Icons.favorite_rounded;
      case 'save': return Icons.bookmark_rounded;
      case 'comment': return Icons.chat_bubble_rounded;
      case 'download': return Icons.file_download_rounded;
      case 'follow': return Icons.person_add_rounded;
      case 'reward': return Icons.card_giftcard_rounded;
      case 'streak': return Icons.local_fire_department_rounded;
      case 'forum': return Icons.forum_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'like': return AppColors.like;
      case 'save': return AppColors.save;
      case 'download': return AppColors.info;
      case 'follow': return AppColors.primary;
      case 'reward': return AppColors.accent;
      case 'streak': return AppColors.danger;
      case 'forum': return AppColors.primary;
      default: return AppColors.primary;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 7) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
