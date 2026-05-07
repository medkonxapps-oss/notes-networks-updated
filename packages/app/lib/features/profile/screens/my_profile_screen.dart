import 'package:app/shared/utils/error_utils.dart';
import 'package:app/features/profile/widgets/collections_grid.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';
import 'package:shared/shared.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/providers/providers.dart';

class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});
  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final theme = Theme.of(context);

    return profileAsync.when(
      loading: () => Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: const Center(child: CircularProgressIndicator(color: AppColors.primary))),
      error: (e, _) => Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: EmptyState(
              icon: Icons.error_outline_rounded, title: 'Error', subtitle: getFriendlyErrorMessage(e))),
      data: (user) {
        if (user == null) {
          return Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              body: const EmptyState(
                  icon: Icons.person_outline_rounded,
                  title: 'Not logged in',
                  subtitle: ''));
        }
        return _ProfileBody(userId: user.id, isMe: true, user: user);
      },
    );
  }
}

class CreatorProfileScreen extends ConsumerWidget {
  final String userId;
  const CreatorProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider(userId));
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
      child: profileAsync.when(
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
          body: const Center(child: CircularProgressIndicator(color: AppColors.primary))),
        error: (e, _) => Scaffold(
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
          body: EmptyState(icon: Icons.error_outline_rounded, title: 'Error', subtitle: getFriendlyErrorMessage(e))),
        data: (user) {
          if (user == null) {
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
              body: const EmptyState(icon: Icons.person_off_rounded, title: 'User not found', subtitle: ''));      
          }
          final me = ref.read(supabaseClientProvider).auth.currentUser;
          return _ProfileBody(userId: userId, isMe: me?.id == userId, user: user);
        },
      ),
    );
  }

}

class _ProfileBody extends ConsumerStatefulWidget {
  final String userId;
  final bool isMe;
  final UserProfile user;

  const _ProfileBody({required this.userId, required this.isMe, required this.user});

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    if (!widget.isMe) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkFollowState();
      });
    }
  }

  Future<void> _checkFollowState() async {
    final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (uid == null) return;
    final following = await ref.read(profileServiceProvider).isFollowing(uid, widget.userId);
    if (mounted) {
      ref.read(followProvider.notifier).seed(widget.userId, following);
    }
  }

  Future<void> _toggleFollow() async {
    try {
      await ref.read(followProvider.notifier).toggleFollow(widget.userId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  Future<void> _startChat() async {
    final me = ref.read(currentUserProfileProvider).value;
    if (me == null) return;

    // RULE: Only allow chat if one person is a teacher
    if (me.role == 'student' && widget.user.role != 'teacher') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('You can only message teachers for doubt solving.'),
        backgroundColor: AppColors.primary,
      ));
      return;
    }

    try {
      final room = await ref.read(chatServiceProvider).createOrGetRoom(widget.userId);
      if (mounted) context.push('/chat/${room.id}', extra: widget.user);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showReportDialog(BuildContext context, String targetUserId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String reason = 'inappropriate';
    final detailsCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Report Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text('Why are you reporting this profile?', style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: reason,
                dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Reason'),
                items: const [
                  DropdownMenuItem(value: 'inappropriate', child: Text('Inappropriate content')),
                  DropdownMenuItem(value: 'spam', child: Text('Spam or fake profile')),
                  DropdownMenuItem(value: 'copyright', child: Text('Copyright violation')),
                  DropdownMenuItem(value: 'misleading', child: Text('Misleading info')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setModalState(() => reason = v!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: detailsCtrl,
                maxLines: 2,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: 'Add details (optional)',
                  hintStyle: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMuted, fontSize: 13),
                ),
                style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Submit Report',
                onPressed: () async {
                  try {
                    await ref.read(profileServiceProvider).reportUser(
                      targetUserId: targetUserId,
                      reason: reason,
                      details: detailsCtrl.text.trim().isEmpty ? null : detailsCtrl.text.trim(),
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Report submitted. Thank you.'),
                        backgroundColor: AppColors.success,
                      ));
                    }
                  } catch (e) {
                    if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _showCreateFolderDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => _CreateFolderSheet(
        initialColor: AppConstants.folderColors.first,
        onSubmit: (name, color) => Navigator.of(sheetCtx).pop({'name': name, 'color': color}),
      ),
    );

    if (result == null) return;

    try {
      await ref.read(profileServiceProvider).createFolder(
        widget.userId, result['name']!, result['color']!,
      );
      ref.invalidate(userFoldersProvider(widget.userId));
    } catch (_) {}
  }

  Future<void> _showCreateCollectionDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => _CreateCollectionSheet(
        onSubmit: (data) => Navigator.of(sheetCtx).pop(data),
      ),
    );

    if (result == null) return;

    try {
      await ref.read(supabaseClientProvider).from('note_collections').insert({
        'user_id': widget.userId,
        'title': result['title'],
        'description': result['description'],
        'is_public': result['is_public'],
      });
      ref.invalidate(userCollectionsProvider(widget.userId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Collection created! Now add some notes to it.'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final notesCountAsync = ref.watch(userNotesProvider(widget.userId));
    final displayNotesCount = notesCountAsync.value?.length ?? u.notesCount;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: widget.isMe
          ? AnimatedBuilder(
              animation: _tabCtrl,
              builder: (_, __) {
                if (_tabCtrl.index == 1) {
                  return FloatingActionButton.extended(
                    onPressed: () => _showCreateCollectionDialog(context),
                    backgroundColor: AppColors.primary,
                    icon: const Icon(Icons.auto_awesome_motion_rounded, color: Colors.white),
                    label: const Text('New Bundle',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  );
                }
                if (_tabCtrl.index == 2) {
                  return FloatingActionButton.extended(
                    onPressed: () => _showCreateFolderDialog(context),
                    backgroundColor: AppColors.primary,
                    icon: const Icon(Icons.create_new_folder_rounded, color: Colors.white),
                    label: const Text('New Folder',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  );
                }
                return const SizedBox.shrink();
              },
            )
          : null,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: RefreshIndicator(
            onRefresh: () async {
              // 1. Invalidate and Force re-fetch
              ref.invalidate(profileProvider(widget.userId));
              ref.invalidate(userNotesProvider(widget.userId));
              ref.invalidate(userFoldersProvider(widget.userId));
              ref.invalidate(userCollectionsProvider(widget.userId));
              
              if (widget.isMe) {
                ref.invalidate(currentUserProfileProvider);
              }

              // 2. Wait for the core data to return
              try {
                await ref.read(profileProvider(widget.userId).future);
                await ref.read(userNotesProvider(widget.userId).future);
              } catch (_) {}
            },
            color: AppColors.primary,
            child: NestedScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              headerSliverBuilder: (_, __) => [
                SliverAppBar(
                  backgroundColor: theme.appBarTheme.backgroundColor,
                  pinned: true,
              title: Text('@${u.username}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
              actions: [
                if (widget.isMe) ...[
                  IconButton(
                    icon: Icon(Icons.download_for_offline_rounded, color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
                    onPressed: () => context.push('/settings/downloads'),
                    tooltip: 'Downloads',
                  ),
                  IconButton(
                    icon: Icon(Icons.card_giftcard_rounded, color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),

                    onPressed: () => context.push('/rewards'),
                    tooltip: 'Rewards Center',
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_rounded, color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
                    onPressed: () async {
                      await context.push('/profile/edit');
                      ref.invalidate(currentUserProfileProvider);
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.settings_rounded, color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
                    onPressed: () => context.push('/settings'),
                  ),
                ],
                if (!widget.isMe)
                  IconButton(
                    icon: const Icon(Icons.report_gmailerrorred_rounded, color: AppColors.danger),
                    onPressed: () => _showReportDialog(context, widget.userId),
                    tooltip: 'Report Profile',
                  ),
              ],
            ),
            SliverToBoxAdapter(child: _buildHeader(u, ref, overrideNotesCount: displayNotesCount)),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabDelegate(TabBar(
                controller: _tabCtrl,
                labelColor: AppColors.primary,
                unselectedLabelColor: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                indicatorColor: AppColors.primary,
                tabs: [
                  const Tab(text: 'Notes'),
                  const Tab(text: 'Collections'),
                  const Tab(text: 'Folders'),
                ],
              ), theme.appBarTheme.backgroundColor!),
            ),
          ],
          body: TabBarView(
            controller: _tabCtrl,
            children: [
              _NotesGrid(userId: widget.userId),
              CollectionsGrid(userId: widget.userId, isMe: widget.isMe),
              _FoldersGrid(userId: widget.userId),
            ],
          ),
        ),
      ),
    ),
  ),
);
}

  Widget _buildHeader(UserProfile u, WidgetRef ref, {int? overrideNotesCount}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(imageUrl: u.avatarUrl, name: u.fullName, size: 80, isVerified: u.isVerifiedCreator, enableFullScreenView: true),       
              const SizedBox(width: 24),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem('${overrideNotesCount ?? u.notesCount}', 'Notes'),
                    _statItem('${u.followersCount}', 'Followers',
                      onTap: () => context.push('/profile/${widget.userId}/followers')),
                    _statItem('${u.followingCount}', 'Following',
                      onTap: () => context.push('/profile/${widget.userId}/following')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(u.fullName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
          if (u.bio != null && u.bio!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(u.bio!, style: TextStyle(fontSize: 14, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
          ],
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              if (u.city != null && u.city!.isNotEmpty) ...[
                Icon(Icons.location_on_outlined, size: 14, color: isDark ? AppColors.textMutedDark : AppColors.textMuted),
                const SizedBox(width: 4),
                Text(u.city!, style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMuted)),
                const SizedBox(width: 12),
              ],
              if (u.institutionName != null && u.institutionName!.isNotEmpty) ...[
                Icon(Icons.account_balance_rounded, size: 14, color: isDark ? AppColors.textMutedDark : AppColors.textMuted),
                const SizedBox(width: 4),
                Text(u.institutionName!, style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMuted)),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            _StatPill(icon: Icons.stars_rounded, label: '${u.totalPoints} pts', color: AppColors.accent),
            const SizedBox(width: 8),
            if (u.currentStreak > 0)
              _StatPill(icon: Icons.local_fire_department_rounded, label: '${u.currentStreak}d streak', color: AppColors.danger),
          ]),
          if (!widget.isMe) ...[
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: Consumer(
                builder: (context, ref, child) {
                  final isFollowing = ref.watch(followProvider)[widget.userId];
                  if (isFollowing == null) return const SizedBox(height: 44, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)));
                  return ElevatedButton(
                    onPressed: _toggleFollow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowing ? (isDark ? AppColors.surfaceDark : Colors.white) : AppColors.primary,
                      foregroundColor: isFollowing ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary) : Colors.white,
                      side: isFollowing ? BorderSide(color: isDark ? AppColors.borderDark : AppColors.border) : null,
                      minimumSize: const Size(double.infinity, 44),
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
                    ),
                    child: Text(isFollowing ? 'Following' : 'Follow'),
                  );
                },
              )),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _startChat,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: EdgeInsets.zero,
                  side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border),
                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
                ),
                child: Icon(Icons.chat_bubble_outline_rounded, color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, {VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
          Text(label, style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
            decoration: onTap != null ? TextDecoration.none : null)),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatPill({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: AppRadius.full),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

class _NotesGrid extends ConsumerStatefulWidget {
  final String userId;
  const _NotesGrid({required this.userId});
  @override
  ConsumerState<_NotesGrid> createState() => _NotesGridState();
}

class _NotesGridState extends ConsumerState<_NotesGrid> {
  void _showNoteOptions(Note note) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.only(top: 10, bottom: 4), width: 36, height: 4, decoration: BoxDecoration(color: isDark ? AppColors.borderDark : AppColors.border, borderRadius: AppRadius.full)),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded, color: AppColors.primary),
              title: Text('View Note', style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary)),    
              onTap: () { Navigator.of(sheetCtx).pop(); context.push('/notes/${note.id}'); },
            ),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: isDark ? Colors.white : AppColors.textPrimary),
              title: Text('Edit Note', style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary)),    
              onTap: () { Navigator.of(sheetCtx).pop(); context.push('/notes/${note.id}/edit'); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              title: const Text('Delete Note', style: TextStyle(color: AppColors.danger)),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
                    title: Text('Delete Note?', style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary)),
                    content: Text('This will permanently remove your note.', style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
                      ElevatedButton(onPressed: () => Navigator.of(dialogCtx).pop(true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger), child: const Text('Delete')),
                    ],
                  ),
                );
                if (confirmed == true) {
                  try {
                    await ref.read(notesServiceProvider).deleteNote(note.id);
                    ref.invalidate(userNotesProvider(widget.userId));
                    ref.invalidate(profileProvider(widget.userId));
                    ref.invalidate(currentUserProfileProvider);
                    ref.invalidate(feedProvider);
                    ref.invalidate(userFoldersProvider(widget.userId));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note deleted successfully'), backgroundColor: AppColors.success));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
                    }
                  }
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(userNotesProvider(widget.userId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    final isMe = currentUserId == widget.userId;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userNotesProvider(widget.userId));
        ref.invalidate(profileProvider(widget.userId));
        if (isMe) ref.invalidate(currentUserProfileProvider);
        await ref.read(userNotesProvider(widget.userId).future);
      },
      color: AppColors.primary,
      child: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: EmptyState(icon: Icons.error_outline_rounded, title: 'Error', subtitle: getFriendlyErrorMessage(e))),      
        data: (allNotes) {
        // Filter: If not me, only show 'active' notes. If me, show everything (active, pending, etc).
        final notes = isMe ? allNotes : allNotes.where((n) => n.status == 'active').toList();

        if (notes.isEmpty) {
          return const SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: 400,
              child: EmptyState(icon: Icons.article_outlined, title: 'No notes yet', subtitle: 'Upload your first note!'),
            ),
          );
        }
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) ref.read(interactionProvider.notifier).seed(notes);
        });

        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.75),
          itemCount: notes.length,
          itemBuilder: (ctx, i) {
            final n = notes[i];
            final isPending = n.status == 'pending_review';
            final interaction = ref.watch(interactionProvider)[n.id];
            final isLiked = interaction?.isLiked ?? n.isLiked;
            final isSaved = interaction?.isSaved ?? n.isSaved;
            final likesCount = interaction?.likesCount ?? n.likesCount;
            final savesCount = interaction?.savesCount ?? n.savesCount;

            return Stack(
              children: [
                GestureDetector(
                  onTap: () => context.push('/notes/${n.id}'),
                  child: Container(
                    decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, borderRadius: AppRadius.lg, border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: Opacity(
                            opacity: isPending ? 0.6 : 1.0,
                            child: (n.thumbnailUrl != null) 
                              ? (n.fileType == 'pdf'
                                  ? IgnorePointer(child: SfPdfViewer.network(n.thumbnailUrl!, canShowScrollHead: false, canShowPaginationDialog: false, enableDoubleTapZooming: false))
                                  : CachedNetworkImage(imageUrl: n.thumbnailUrl!, fit: BoxFit.cover, width: double.infinity, memCacheWidth: 600)) 
                              : Container(color: isDark ? const Color(0xFF2D2D4D) : AppColors.primarySurface, child: Center(child: Icon(n.fileType == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.photo_library_rounded, color: AppColors.primary, size: 32))),
                          ),
                        )),
                        Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(n.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          if (isPending)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: AppRadius.sm),
                              child: const Text('PENDING', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.accent)),
                            )
                          else
                            Row(children: [
                              Icon(isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded, size: 12, color: isLiked ? AppColors.like : (isDark ? AppColors.textMutedDark : AppColors.textMuted)),
                              const SizedBox(width: 4),
                              Text('$likesCount', style: TextStyle(fontSize: 11, color: isDark ? AppColors.textMutedDark : AppColors.textMuted)),
                              const Spacer(),
                              Icon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded, size: 12, color: isSaved ? AppColors.save : (isDark ? AppColors.textMutedDark : AppColors.textMuted)),
                              const SizedBox(width: 4),
                              Text('$savesCount', style: TextStyle(fontSize: 11, color: isDark ? AppColors.textMutedDark : AppColors.textMuted)),
                            ]),
                        ])),
                      ],
                    ),
                  ),
                ),
                if (isMe)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white : AppColors.textPrimary),   
                      style: IconButton.styleFrom(
                        backgroundColor: isDark ? AppColors.surfaceDark.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.8),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => _showNoteOptions(n),
                    ),
                  ),
              ],
            );
          },
        );
      },
    ),
  );
  }
}

class _FoldersGrid extends ConsumerStatefulWidget {
  final String userId;
  const _FoldersGrid({required this.userId});
  @override
  ConsumerState<_FoldersGrid> createState() => _FoldersGridState();
}

class _FoldersGridState extends ConsumerState<_FoldersGrid> {
  void _showFolderOptions(Folder f) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Color(int.parse(f.colorHex.replaceAll('#', '0xFF')));

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.only(top: 10, bottom: 4), width: 36, height: 4, decoration: BoxDecoration(color: isDark ? AppColors.borderDark : AppColors.border, borderRadius: AppRadius.full)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), child: Row(children: [ Icon(Icons.folder_rounded, color: color, size: 22), const SizedBox(width: 10), Text(f.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimary)) ])),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded, color: AppColors.primary),
              title: Text('Open Folder', style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary)),
              onTap: () { Navigator.of(sheetCtx).pop(); context.push('/profile/${widget.userId}/folder/${f.id}'); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              title: const Text('Delete Folder', style: TextStyle(color: AppColors.danger)),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
                    title: Text('Delete Folder?', style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary)),
                    content: Text('Notes inside will not be deleted.', style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
                      ElevatedButton(onPressed: () => Navigator.of(dialogCtx).pop(true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger), child: const Text('Delete')),
                    ],
                  ),
                );
                if (confirmed == true) {
                  try {
                    await ref.read(profileServiceProvider).deleteFolder(f.id);
                    ref.invalidate(userFoldersProvider(widget.userId));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Folder deleted'), backgroundColor: AppColors.success));
                    }
                    } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
                    }
                    }                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(userFoldersProvider(widget.userId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    final isMe = currentUserId == widget.userId;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userFoldersProvider(widget.userId));
        ref.invalidate(profileProvider(widget.userId));
        if (isMe) ref.invalidate(currentUserProfileProvider);
        await ref.read(userFoldersProvider(widget.userId).future);
      },
      color: AppColors.primary,
      child: foldersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: EmptyState(icon: Icons.error_outline_rounded, title: 'Error', subtitle: getFriendlyErrorMessage(e))),      
        data: (folders) {
          if (folders.isEmpty) {
            return const SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: 400,
                child: EmptyState(icon: Icons.folder_outlined, title: 'No folders yet', subtitle: 'Tap "New Folder" to create one'),
              ),
            );
          }
          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.1),
            itemCount: folders.length,
            itemBuilder: (ctx, i) {
              final f = folders[i];
              final color = Color(int.parse(f.colorHex.replaceAll('#', '0xFF')));
              return GestureDetector(
                onTap: () => context.push('/profile/${widget.userId}/folder/${f.id}'),
                onLongPress: isMe ? () => _showFolderOptions(f) : null,
                child: Container(
                  decoration: BoxDecoration(color: isDark ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.1), borderRadius: AppRadius.lg, border: Border.all(color: color.withValues(alpha: 0.35))),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_rounded, color: color, size: 48),
                      const SizedBox(height: 8),
                      Text(f.name, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _TabDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color bgColor;
  _TabDelegate(this.tabBar, this.bgColor);
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: bgColor, child: tabBar);
  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  bool shouldRebuild(_TabDelegate old) => old.bgColor != bgColor || old.tabBar != tabBar;
}

class _CreateFolderSheet extends StatefulWidget {
  final String initialColor;
  final void Function(String name, String color) onSubmit;
  const _CreateFolderSheet({required this.initialColor, required this.onSubmit});
  @override
  State<_CreateFolderSheet> createState() => _CreateFolderSheetState();
}

class _CreateFolderSheetState extends State<_CreateFolderSheet> {
  late final TextEditingController _nameCtrl;
  @override
  void initState() { super.initState(); _nameCtrl = TextEditingController(); }
  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create Folder', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            style: TextStyle(color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
            decoration: InputDecoration(labelText: 'Folder Name', labelStyle: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMuted)),
          ),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Create Folder', onPressed: () => widget.onSubmit(_nameCtrl.text.trim(), widget.initialColor)),
        ],
      ),
    );
  }
}

class _CreateCollectionSheet extends StatefulWidget {
  final void Function(Map<String, dynamic> data) onSubmit;
  const _CreateCollectionSheet({required this.onSubmit});
  @override
  State<_CreateCollectionSheet> createState() => _CreateCollectionSheetState();
}

class _CreateCollectionSheetState extends State<_CreateCollectionSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isPublic = true;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New Collection Bundle', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text('Group your best notes together for others to discover.', style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 24),
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Collection Title', hintText: 'e.g. Physics Full Course'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descCtrl,
            maxLines: 2,
            style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Description (Optional)', hintText: 'What is this bundle about?'),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Text('Public Collection', style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            subtitle: Text('Others can see this on your profile', style: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMuted, fontSize: 12)),
            value: _isPublic,
            activeThumbColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _isPublic = v),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Create Collection',
            onPressed: () {
              final title = _titleCtrl.text.trim();
              if (title.isEmpty) return;
              widget.onSubmit({
                'title': title,
                'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
                'is_public': _isPublic,
              });
            },
          ),
        ],
      ),
    );
  }
} // End of _FoldersGridState



