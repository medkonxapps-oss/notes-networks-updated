import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';
import 'package:shared/shared.dart';
import '../../../shared/providers/providers.dart';
import '../../../core/constants/app_constants.dart';

final _searchQueryProvider = StateProvider<String>((ref) => '');
final _searchTabProvider = StateProvider<int>((ref) => 0); 
final _filterSubjectProvider = StateProvider<String?>((ref) => null);
final _filterBoardProvider = StateProvider<String?>((ref) => null);

final _searchNotesProvider = FutureProvider.autoDispose<List<Note>>((ref) async {
  final q = ref.watch(_searchQueryProvider);
  final subject = ref.watch(_filterSubjectProvider);
  final board = ref.watch(_filterBoardProvider);
  if (q.length < 2 && subject == null && board == null) return [];
  return ref.read(notesServiceProvider).searchNotes(q, subject: subject, board: board);
});

final _searchUsersProvider = FutureProvider.autoDispose<List<UserProfile>>((ref) async {   
  final q = ref.watch(_searchQueryProvider);
  if (q.isEmpty) return [];
  return ref.read(profileServiceProvider).searchUsers(q);
});

final _searchTeachersProvider = FutureProvider.autoDispose<List<UserProfile>>((ref) async {   
  final q = ref.watch(_searchQueryProvider);
  if (q.isEmpty) return [];
  return ref.read(profileServiceProvider).searchTeachers(q);
});

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});
  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(_searchTabProvider.notifier).state = _tabController.index;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _clearSearchAndFilters() {
    _searchCtrl.clear();
    ref.read(_searchQueryProvider.notifier).state = '';
    ref.read(_filterSubjectProvider.notifier).state = null;
    ref.read(_filterBoardProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter = ref.watch(_searchQueryProvider).isNotEmpty || ref.watch(_filterSubjectProvider) != null || ref.watch(_filterBoardProvider) != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: !hasActiveFilter,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _clearSearchAndFilters(); },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.appBarTheme.backgroundColor,
          title: TextField(
            controller: _searchCtrl,
            onChanged: (v) => ref.read(_searchQueryProvider.notifier).state = v,
            style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search notes, creators...',
              hintStyle: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMuted, fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded, color: isDark ? AppColors.textMutedDark : AppColors.textMuted),
              suffixIcon: hasActiveFilter ? IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white70), onPressed: _clearSearchAndFilters) : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(borderRadius: AppRadius.md, borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          actions: [ IconButton(icon: Icon(Icons.tune_rounded, color: isDark ? Colors.white : AppColors.textPrimary), onPressed: _showFilters) ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: isDark ? AppColors.textMutedDark : AppColors.textMuted,
            indicatorColor: AppColors.primary,
            tabs: const [Tab(text: 'Notes'), Tab(text: 'Creators'), Tab(text: 'Teachers')],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [ _NotesTab(), _UsersTab(), _TeachersTab() ],
        ),
      ),
    );
  }

  void _showFilters() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _FilterSheet(),
    );
  }
}

class _NotesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final query = ref.watch(_searchQueryProvider);
    final subject = ref.watch(_filterSubjectProvider);
    final board = ref.watch(_filterBoardProvider);

    if (query.isEmpty && subject == null && board == null) {
      final popularAsync = ref.watch(popularNotesProvider);
      return RefreshIndicator(
        onRefresh: () async => ref.invalidate(popularNotesProvider),
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TrendingSubjects(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: Row(
                  children: [
                    const Icon(Icons.auto_graph_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text('Popular Notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              popularAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (notes) {
                  if (notes.isEmpty) return const SizedBox.shrink();
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: width > 600 ? 3 : 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: notes.length,
                    itemBuilder: (ctx, i) {
                      final n = notes[i];
                      return NoteCard(
                        note: NoteCardData(
                          id: n.id, title: n.title, subject: n.subject, authorName: n.authorName ?? '', authorId: n.userId,
                          authorAvatarUrl: n.authorAvatarUrl, isAuthorVerified: n.authorIsVerified, thumbnailUrl: n.thumbnailUrl,
                          likesCount: n.likesCount, savesCount: n.savesCount, pageCount: n.pageCount, fileType: n.fileType,
                          isLiked: n.isLiked, isSaved: n.isSaved, createdAt: n.createdAt,
                        ),
                        onTap: () {
                          ref.read(notesServiceProvider).recordSearch(n.id);
                          context.push('/notes/${n.id}');
                        },
                        onAuthorTap: () => context.push('/profile/${n.userId}'),
                        onLike: () => ref.read(interactionProvider.notifier).toggleLike(n.id),
                        onSave: () => ref.read(interactionProvider.notifier).toggleSave(n.id),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      );
    }
    
    final searchAsync = ref.watch(_searchNotesProvider);
    return searchAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: 'Error', subtitle: e.toString()),
      data: (notes) {
        if (notes.isEmpty) return const EmptyState(icon: Icons.search_off_rounded, title: 'No results', subtitle: 'Try different keywords');
        WidgetsBinding.instance.addPostFrameCallback((_) { if (context.mounted) ref.read(interactionProvider.notifier).seed(notes); });

        int crossAxisCount = 2;
        if (width > 1200) {
          crossAxisCount = 5;
        } else if (width > 900) {
          crossAxisCount = 4;
        } else if (width > 600) {
          crossAxisCount = 3;
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_searchNotesProvider),
          color: AppColors.primary,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                physics: const AlwaysScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.72,
                ),
                itemCount: notes.length,
                itemBuilder: (ctx, i) {
                  final n = notes[i];
                  final interaction = ref.watch(interactionProvider)[n.id];
                  return NoteCard(
                    note: NoteCardData(
                      id: n.id, title: n.title, subject: n.subject, authorName: n.authorName ?? '', authorId: n.userId,
                      authorAvatarUrl: n.authorAvatarUrl, isAuthorVerified: n.authorIsVerified, thumbnailUrl: n.thumbnailUrl,
                      likesCount: interaction?.likesCount ?? n.likesCount, savesCount: interaction?.savesCount ?? n.savesCount,
                      pageCount: n.pageCount, fileType: n.fileType, isLiked: interaction?.isLiked ?? n.isLiked, isSaved: interaction?.isSaved ?? n.isSaved,
                      createdAt: n.createdAt,
                    ),
                    onTap: () {
                      ref.read(notesServiceProvider).recordSearch(n.id);
                      context.push('/notes/${n.id}');
                    },
                    onAuthorTap: () => context.push(ref.read(supabaseClientProvider).auth.currentUser?.id == n.userId ? '/profile/me' : '/profile/${n.userId}'),
                    onLike: () => ref.read(interactionProvider.notifier).toggleLike(n.id),
                    onSave: () => ref.read(interactionProvider.notifier).toggleSave(n.id),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UsersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(_searchQueryProvider);
    if (query.isEmpty) {
      final popularAsync = ref.watch(popularCreatorsProvider);
      return RefreshIndicator(
        onRefresh: () async => ref.invalidate(popularCreatorsProvider),
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(
                  children: [
                    Icon(Icons.star_rounded, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text('Popular Creators', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              popularAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (users) {
                  if (users.isEmpty) return const SizedBox.shrink();
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: users.length,
                    itemBuilder: (ctx, i) => _UserFollowTile(user: users[i], recordSearch: true),
                  );
                },
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      );
    }
    final usersAsync = ref.watch(_searchUsersProvider);
    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: 'Error', subtitle: e.toString()),
      data: (users) {
        if (users.isEmpty) return const EmptyState(icon: Icons.person_search_rounded, title: 'No creators found', subtitle: 'Try another name');
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_searchUsersProvider),
          color: AppColors.primary,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView.builder(
                padding: const EdgeInsets.all(16), 
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: users.length, 
                itemBuilder: (ctx, i) => _UserFollowTile(user: users[i], recordSearch: true),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UserFollowTile extends ConsumerStatefulWidget {
  final UserProfile user;
  final bool recordSearch;
  const _UserFollowTile({required this.user, this.recordSearch = false});
  @override
  ConsumerState<_UserFollowTile> createState() => _UserFollowTileState();
}

class _UserFollowTileState extends ConsumerState<_UserFollowTile> {
  @override
  void initState() { super.initState(); _checkFollow(); }
  Future<void> _checkFollow() async {
    final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (uid == null) return;
    final following = await ref.read(profileServiceProvider).isFollowing(uid, widget.user.id);
    if (mounted) ref.read(followProvider.notifier).seed(widget.user.id, following);
  }
  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMe = ref.watch(supabaseClientProvider).auth.currentUser?.id == u.id;
    final isFollowing = ref.watch(followProvider)[u.id];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, borderRadius: AppRadius.lg, border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border)),
      child: ListTile(
        onTap: () {
          if (widget.recordSearch) {
            ref.read(profileServiceProvider).recordSearch(u.id);
          }
          context.push('/profile/${u.id}');
        },
        leading: AppAvatar(imageUrl: u.avatarUrl, name: u.fullName, size: 52, isVerified: u.isVerifiedCreator),
        title: Row(
          children: [
            Expanded(child: Text(u.fullName, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimary))),
            if (u.role == 'teacher')
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: AppRadius.sm),
                child: const Text('TEACHER', style: TextStyle(color: AppColors.primary, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('@${u.username}', style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMuted)),
            if (u.institutionName != null && u.institutionName!.isNotEmpty)
              Text(u.institutionName!, style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
          ],
        ),
        trailing: isMe ? null : (isFollowing == null ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : OutlinedButton(
          onPressed: () => ref.read(followProvider.notifier).toggleFollow(u.id),
          child: Text(isFollowing ? 'Following' : 'Follow'),
        )),
      ),
    );
  }
}

class _TrendingSubjects extends ConsumerWidget {
  final List<Color> _chipColors = [
    const Color(0xFFEEF2FF), // Indigo
    const Color(0xFFFFF7ED), // Orange
    const Color(0xFFECFDF5), // Emerald
    const Color(0xFFFEF2F2), // Rose
    const Color(0xFFF5F3FF), // Violet
    const Color(0xFFFFFBEB), // Amber
  ];
  final List<Color> _textColors = [
    const Color(0xFF4F46E5),
    const Color(0xFFEA580C),
    const Color(0xFF059669),
    const Color(0xFFDC2626),
    const Color(0xFF7C3AED),
    const Color(0xFFD97706),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Browse by Subject', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.textPrimary)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.5),
            itemCount: AppConstants.subjects.length,
            itemBuilder: (ctx, i) {
              final s = AppConstants.subjects[i];
              final colorIdx = i % _chipColors.length;
              final bgColor = isDark ? _textColors[colorIdx].withValues(alpha: 0.15) : _chipColors[colorIdx];
              final textColor = isDark ? _textColors[colorIdx].withValues(alpha: 0.9) : _textColors[colorIdx];
              
              return GestureDetector(
                onTap: () { ref.read(_searchQueryProvider.notifier).state = s; ref.read(_filterSubjectProvider.notifier).state = s; },
                child: Container(
                  decoration: BoxDecoration(color: bgColor, borderRadius: AppRadius.md, border: Border.all(color: textColor.withValues(alpha: 0.3))),
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [ Icon(Icons.menu_book_rounded, color: textColor, size: 18), const SizedBox(width: 8), Expanded(child: Text(s, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis)) ]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FilterSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.textPrimary)),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
            style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Subject'),
            items: [null, ...AppConstants.subjects].map((s) => DropdownMenuItem(value: s, child: Text(s ?? 'All Subjects'))).toList(),
            onChanged: (v) => ref.read(_filterSubjectProvider.notifier).state = v,
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Apply Filters', onPressed: () => Navigator.pop(context)),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _TeachersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(_searchQueryProvider);
    if (query.isEmpty) {
      final popularAsync = ref.watch(popularTeachersProvider);
      return RefreshIndicator(
        onRefresh: () async => ref.invalidate(popularTeachersProvider),
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(
                  children: [
                    Icon(Icons.school_rounded, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text('Popular Teachers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              popularAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (users) {
                  if (users.isEmpty) return const SizedBox.shrink();
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: users.length,
                    itemBuilder: (ctx, i) => _UserFollowTile(user: users[i], recordSearch: true),
                  );
                },
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      );
    }
    final usersAsync = ref.watch(_searchTeachersProvider);
    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: 'Error', subtitle: e.toString()),
      data: (users) {
        if (users.isEmpty) return const EmptyState(icon: Icons.person_search_rounded, title: 'No teachers found', subtitle: 'Try another name');
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_searchTeachersProvider),
          color: AppColors.primary,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView.builder(
                padding: const EdgeInsets.all(16), 
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: users.length, 
                itemBuilder: (ctx, i) => _UserFollowTile(user: users[i], recordSearch: true),
              ),
            ),
          ),
        );
      },
    );
  }
}
