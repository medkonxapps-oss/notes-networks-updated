import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/local_db_service.dart';
import '../../core/services/data_export_service.dart';
import '../utils/error_utils.dart';

// ── Supabase client ────────────────────────────────────────────────────────────
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final localDbServiceProvider = Provider<LocalDbService>((ref) {
  return LocalDbService();
});

// ── Services ───────────────────────────────────────────────────────────────────
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseClientProvider));
});

final notesServiceProvider = Provider<NotesService>((ref) {
  return NotesService(ref.watch(supabaseClientProvider));
});

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService(ref.watch(supabaseClientProvider));
});

final leaderboardServiceProvider = Provider<LeaderboardService>((ref) {
  return LeaderboardService(ref.watch(supabaseClientProvider));
});

final rewardsServiceProvider = Provider<RewardsService>((ref) {
  return RewardsService(ref.watch(supabaseClientProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(supabaseClientProvider));
});

final forumServiceProvider = Provider<ForumService>((ref) {
  return ForumService(ref.watch(supabaseClientProvider));
});

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService(ref.watch(supabaseClientProvider));
});

final collectionsServiceProvider = Provider<CollectionsService>((ref) {
  return CollectionsService(ref.watch(supabaseClientProvider));
});

final chatMessagesProvider = StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, roomId) {
  ref.watch(authStateProvider); // Rebuild on auth change/refresh
  return ref.watch(chatServiceProvider).getMessagesStream(roomId);
});

final chatRoomsProvider = StreamProvider.autoDispose<List<ChatRoom>>((ref) {
  ref.watch(authStateProvider); // Rebuild on auth change/refresh
  return ref.watch(chatServiceProvider).getChatRoomsStream();
});

final unreadChatCountProvider = StreamProvider<int>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.valueOrNull?.session?.user.id;
  if (uid == null) return Stream.value(0);

  final client = ref.read(supabaseClientProvider);
  return client
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('receiver_id', uid).order('id')
      .map((rows) => rows.where((row) => row['is_read'] == false).length);
});

final roomUnreadCountProvider = StreamProvider.family<int, String>((ref, roomId) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.valueOrNull?.session?.user.id;
  if (uid == null) return Stream.value(0);

  final client = ref.read(supabaseClientProvider);
  return client
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('receiver_id', uid).order('id')
      .map((rows) => rows.where((row) => row['room_id'] == roomId && row['is_read'] == false).length);
});

final dataExportServiceProvider = Provider<DataExportService>((ref) {
  return DataExportService(
    ref.watch(supabaseClientProvider),
    ref.watch(notesServiceProvider),
    ref.watch(profileServiceProvider),
  );
});

// ── Auth State ────────────────────────────────────────────────────────────────
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

// ── Current user profile — real-time stream ───────────────────────────────────
final currentUserProfileProvider = Provider<AsyncValue<UserProfile?>>((ref) {
  // Re-run whenever auth state changes (sign in/out/refresh)
  final authState = ref.watch(authStateProvider);
  final uid = authState.valueOrNull?.session?.user.id;

  if (uid == null) {
    return const AsyncValue.data(null);
  }

  // Use the existing family-based stream provider
  return ref.watch(profileProvider(uid));
});

// ── Global Key for SnackBar ──────────────────────────────────────────────────
final messengerKeyProvider = Provider((ref) => GlobalKey<ScaffoldMessengerState>());

// ── Global Like/Save Interaction State ───────────────────────────────────────
class InteractionNotifier extends StateNotifier<Map<String, ({bool isLiked, bool isSaved, int likesCount, int savesCount})>> {
  final NotesService _service;
  final Ref _ref;

  final _pendingLikes = <String>{};
  final _pendingSaves = <String>{};

  InteractionNotifier(this._service, this._ref) : super({});

  void updateNoteStats(String noteId, {int? likesCount, int? savesCount}) {
    final current = state[noteId];
    if (current == null) return;
    state = {
      ...state,
      noteId: (
        isLiked: current.isLiked,
        isSaved: current.isSaved,
        likesCount: likesCount ?? current.likesCount,
        savesCount: savesCount ?? current.savesCount,
      ),
    };
  }

  void seed(List<Note> notes) {
    final updated = Map<String, ({bool isLiked, bool isSaved, int likesCount, int savesCount})>.from(state);
    for (final n in notes) {
      if (!updated.containsKey(n.id)) {
        updated[n.id] = (
          isLiked: n.isLiked, isSaved: n.isSaved,
          likesCount: n.likesCount, savesCount: n.savesCount,
        );
      }
    }
    state = updated;
  }

  void seedNote(Note note, {bool forceOverwrite = false}) {
    if (forceOverwrite || !state.containsKey(note.id)) {
      seed([note]);
    }
  }

  ({bool isLiked, bool isSaved, int likesCount, int savesCount})? get(String noteId) => state[noteId];

  Future<void> toggleLike(String noteId) async {
    if (_pendingLikes.contains(noteId)) return;
    _pendingLikes.add(noteId);

    final current = state[noteId];
    if (current == null) {
      _pendingLikes.remove(noteId);
      return;
    }
    final nowLiked = !current.isLiked;
    state = {
      ...state,
      noteId: (
        isLiked: nowLiked,
        isSaved: current.isSaved,
        likesCount: nowLiked ? current.likesCount + 1 : (current.likesCount - 1).clamp(0, 99999),
        savesCount: current.savesCount,
      ),
    };
    _ref.read(feedProvider.notifier).syncLike(noteId, nowLiked);

    try {
      await _service.toggleLike(noteId);
      _ref.invalidate(likedNotesProvider);
    } catch (_) {
      state = {...state, noteId: current};
      _ref.read(feedProvider.notifier).syncLike(noteId, current.isLiked);
    } finally {
      _pendingLikes.remove(noteId);
    }
  }

  Future<void> toggleSave(String noteId) async {
    if (_pendingSaves.contains(noteId)) return;
    _pendingSaves.add(noteId);

    final current = state[noteId];
    if (current == null) {
      _pendingSaves.remove(noteId);
      return;
    }
    final nowSaved = !current.isSaved;
    state = {
      ...state,
      noteId: (
        isLiked: current.isLiked,
        isSaved: nowSaved,
        likesCount: current.likesCount,
        savesCount: nowSaved ? current.savesCount + 1 : (current.savesCount - 1).clamp(0, 99999),
      ),
    };
    _ref.read(feedProvider.notifier).syncSave(noteId, nowSaved);

    try {
      await _service.toggleSave(noteId);
      _ref.invalidate(savedNotesProvider);
      
      if (nowSaved) {
        _ref.read(messengerKeyProvider).currentState?.showSnackBar(
          const SnackBar(
            content: Text('Note saved to library'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      state = {...state, noteId: current};
      _ref.read(feedProvider.notifier).syncSave(noteId, current.isSaved);
    } finally {
      _pendingSaves.remove(noteId);
    }
  }
}

final interactionProvider = StateNotifierProvider<InteractionNotifier,
    Map<String, ({bool isLiked, bool isSaved, int likesCount, int savesCount})>>(
  (ref) => InteractionNotifier(ref.read(notesServiceProvider), ref),
);

// ── Global Follow Interaction State ──────────────────────────────────────────
class FollowNotifier extends StateNotifier<Map<String, bool>> {
  final ProfileService _service;
  final Ref _ref;
  final _pending = <String>{};

  FollowNotifier(this._service, this._ref) : super({});

  void seed(String userId, bool isFollowing) {
    state = {...state, userId: isFollowing};
  }

  bool? getState(String userId) => state[userId];

  Future<void> toggleFollow(String userId) async {
    final myId = _ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (myId == null) {
      _ref.read(messengerKeyProvider).currentState?.showSnackBar(
        const SnackBar(content: Text('Please login to follow creators')),
      );
      return;
    }
    if (myId == userId) return;

    if (_pending.contains(userId)) return;
    _pending.add(userId);

    try {
      bool isFollowing = state[userId] ?? false;
      final next = !isFollowing;
      state = {...state, userId: next};

      final result = await _service.toggleFollow(userId);
      state = {...state, userId: result};
      
      _ref.invalidate(profileProvider(userId));
      _ref.invalidate(currentUserProfileProvider);
      _ref.invalidate(followersListProvider(userId));
    } catch (e) {
      _ref.read(messengerKeyProvider).currentState?.showSnackBar(
        SnackBar(
          content: Text(getFriendlyErrorMessage(e)),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      _pending.remove(userId);
    }
  }
}

final followProvider = StateNotifierProvider<FollowNotifier, Map<String, bool>>((ref) {
  return FollowNotifier(ref.read(profileServiceProvider), ref);
});

// ── Feed ──────────────────────────────────────────────────────────────────────
class FeedNotifier extends StateNotifier<AsyncValue<List<Note>>> {
  final NotesService _service;
  final Ref _ref;
  int _page = 0;
  String _type = 'for_you';
  String? _subject;
  RealtimeChannel? _channel;

  FeedNotifier(this._service, this._ref) : super(const AsyncValue.loading()) {
    load();
    _subscribe();
  }

  void _subscribe() {
    final client = _ref.read(supabaseClientProvider);
    _channel = client.channel('feed_realtime').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'notes',
      callback: (payload) {
        if (_page == 0) {
          refresh();
        }
      },
    ).subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final notes = _type == 'for_you'
          ? await _service.getForYouFeed(page: _page, subject: _subject)
          : await _service.getFollowingFeed(page: _page);
      state = AsyncValue.data(notes);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    _page = 0;
    await load();
  }

  Future<void> loadMore() async {
    final current = state.value ?? [];
    _page++;
    try {
      final more = _type == 'for_you'
          ? await _service.getForYouFeed(page: _page, subject: _subject)
          : await _service.getFollowingFeed(page: _page);
      state = AsyncValue.data([...current, ...more]);
    } catch (_) {
      _page--;
    }
  }

  void switchType(String type) {
    _type = type;
    _page = 0;
    load();
  }

  void setSubject(String? subject) {
    _subject = subject;
    _page = 0;
    load();
  }

  void syncLike(String noteId, bool isLiked) {
    state.whenData((notes) {
      state = AsyncValue.data(notes.map((n) {
        if (n.id != noteId || n.isLiked == isLiked) return n;
        return n.copyWith(
          isLiked: isLiked,
          likesCount: isLiked ? n.likesCount + 1 : (n.likesCount - 1).clamp(0, 99999),
        );
      }).toList());
    });
  }

  void syncSave(String noteId, bool isSaved) {
    state.whenData((notes) {
      state = AsyncValue.data(notes.map((n) {
        if (n.id != noteId || n.isSaved == isSaved) return n;
        return n.copyWith(
          isSaved: isSaved,
          savesCount: isSaved ? n.savesCount + 1 : (n.savesCount - 1).clamp(0, 99999),
        );
      }).toList());
    });
  }

  void toggleLike(String noteId) => syncLike(noteId,
      !(state.value?.firstWhere((n) => n.id == noteId, orElse: () => state.value!.first).isLiked ?? false));

  void toggleSave(String noteId) => syncSave(noteId,
      !(state.value?.firstWhere((n) => n.id == noteId, orElse: () => state.value!.first).isSaved ?? false));

  void syncExternalStats(String noteId, int? likesCount, int? savesCount) {
    state.whenData((notes) {
      state = AsyncValue.data(notes.map((n) {
        if (n.id != noteId) return n;
        return n.copyWith(
          likesCount: likesCount ?? n.likesCount,
          savesCount: savesCount ?? n.savesCount,
        );
      }).toList());
    });
  }
}

final feedProvider = StateNotifierProvider<FeedNotifier, AsyncValue<List<Note>>>((ref) {
  ref.watch(authStateProvider); // Rebuild on auth change/refresh
  return FeedNotifier(ref.watch(notesServiceProvider), ref);
});

// ── Notifications ─────────────────────────────────────────────────────────────
final unreadNotifCountProvider = StreamProvider<int>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.valueOrNull?.session?.user.id;
  if (uid == null) return Stream.value(0);

  final client = ref.read(supabaseClientProvider);
  return client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', uid)
      .map((rows) => rows.where((row) => row['is_read'] == false).length);
});

// ── Leaderboard ───────────────────────────────────────────────────────────────
final leaderboardProvider = FutureProvider.family<List<LeaderboardEntry>, String>(
  (ref, period) async {
    return ref.watch(leaderboardServiceProvider).getLeaderboard(period: period);
  },
);

// ── Rewards ───────────────────────────────────────────────────────────────────
final rewardsCatalogProvider = FutureProvider<List<Reward>>((ref) async {
  return ref.watch(rewardsServiceProvider).getCatalog();
});

/// Live streak info — invalidated after every upload and on profile refresh
final streakInfoProvider = FutureProvider.autoDispose<StreakInfo>((ref) async {
  ref.watch(currentUserProfileProvider); // rebuild when profile changes
  return ref.read(rewardsServiceProvider).getStreakInfo();
});

/// User's earned badges
final myBadgesProvider = FutureProvider.autoDispose<List<UserBadge>>((ref) async {
  return ref.read(rewardsServiceProvider).getMyBadges();
});

/// Points ledger history
final pointsHistoryProvider = FutureProvider.autoDispose<List<PointsEvent>>((ref) async {
  ref.watch(currentUserProfileProvider);
  return ref.read(rewardsServiceProvider).getPointsHistory();
});

// ── User & Profile ────────────────────────────────────────────────────────────
final profileProvider = FutureProvider.autoDispose.family<UserProfile?, String>((ref, userId) async {
  ref.watch(authStateProvider); // Rebuild on auth change/refresh
  final client = ref.read(supabaseClientProvider);
  
  final data = await client
      .from('users')
      .select()
      .eq('id', userId)
      .maybeSingle();
      
  if (data == null) return null;
  return UserProfile.fromJson(data);
});

final userNotesProvider = FutureProvider.autoDispose.family<List<Note>, String>(
  (ref, userId) => ref.read(notesServiceProvider).getUserNotes(userId),
);

final pendingNotesProvider = FutureProvider.autoDispose.family<List<Note>, String>(
  (ref, userId) => ref.read(notesServiceProvider).getUserNotes(userId, status: 'pending_review'),
);

final userFoldersProvider = FutureProvider.autoDispose.family<List<Folder>, String>(
  (ref, userId) => ref.read(profileServiceProvider).getUserFolders(userId),
);

final subFoldersProvider = FutureProvider.autoDispose.family<List<Folder>, String>(
  (ref, parentFolderId) =>
      ref.read(profileServiceProvider).getSubFolders(parentFolderId),
);

final folderNotesProvider = FutureProvider.autoDispose
    .family<List<Note>, ({String userId, String folderId})>(
  (ref, args) => ref
      .read(notesServiceProvider)
      .getUserNotes(args.userId, folderId: args.folderId),
);

// ── Saved & Liked Notes ───────────────────────────────────────────────────────
// ── Saved & Liked Notes with realtime invalidation ───────────────────────────
// These providers watch a realtime trigger so they refresh when saves/likes change
final _savesRealtimeProvider = StreamProvider.autoDispose<void>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.valueOrNull?.session?.user.id;
  if (uid == null) return const Stream.empty();
  final client = ref.read(supabaseClientProvider);
  return client
      .from('saves')
      .stream(primaryKey: ['id'])
      .eq('user_id', uid)
      .map((_) {}); // emit void whenever saves table changes for this user
});

final _likesRealtimeProvider = StreamProvider.autoDispose<void>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.valueOrNull?.session?.user.id;
  if (uid == null) return const Stream.empty();
  final client = ref.read(supabaseClientProvider);
  return client
      .from('likes')
      .stream(primaryKey: ['id'])
      .eq('user_id', uid)
      .map((_) {}); // emit void whenever likes table changes for this user
});

final savedNotesProvider = FutureProvider.autoDispose<List<Note>>((ref) async {
  // Watch realtime saves stream so this refreshes when another device/user triggers a save
  ref.watch(_savesRealtimeProvider);
  return ref.read(notesServiceProvider).getSavedNotes();
});

final likedNotesProvider = FutureProvider.autoDispose<List<Note>>((ref) async {
  // Watch realtime likes stream so this refreshes when another device triggers a like
  ref.watch(_likesRealtimeProvider);
  return ref.read(notesServiceProvider).getLikedNotes();
});

final downloadedNotesProvider = FutureProvider.autoDispose<List<LocalNote>>((ref) async {
  return ref.read(localDbServiceProvider).getAllDownloadedNotes();
});

final userCollectionsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, userId) async {
  final res = await ref.read(supabaseClientProvider)
      .from('note_collections_with_stats')
      .select()
      .eq('user_id', userId)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(res);
});

final isNoteDownloadedProvider = FutureProvider.autoDispose.family<bool, String>((ref, id) async {
  return ref.read(localDbServiceProvider).isDownloaded(id);
});

// ── Theme State ──────────────────────────────────────────────
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

class ThemeNotifier extends StateNotifier<ThemeMode> {
  final SharedPreferences _prefs;
  ThemeNotifier(this._prefs) : super(_loadTheme(_prefs));

  static ThemeMode _loadTheme(SharedPreferences prefs) {
    final val = prefs.getString('theme_mode');
    if (val == 'dark') return ThemeMode.dark;
    if (val == 'light') return ThemeMode.light;
    return ThemeMode.light;
  }

  void setTheme(ThemeMode mode) {
    state = mode;
    _prefs.setString('theme_mode', mode.name);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier(ref.watch(sharedPreferencesProvider));
});

// ── Feed View Mode (List/Grid) ────────────────────────────────────────
enum FeedViewMode { list, grid }
class FeedViewModeNotifier extends StateNotifier<FeedViewMode> {
  final SharedPreferences _prefs;
  FeedViewModeNotifier(this._prefs) : super(_loadViewMode(_prefs));

  static FeedViewMode _loadViewMode(SharedPreferences prefs) {
    final val = prefs.getString('feed_view_mode');
    return val == 'grid' ? FeedViewMode.grid : FeedViewMode.list;
  }

  void setViewMode(FeedViewMode mode) {
    state = mode;
    _prefs.setString('feed_view_mode', mode.name);
  }
}

final feedViewModeProvider = StateNotifierProvider<FeedViewModeNotifier, FeedViewMode>((ref) {
  return FeedViewModeNotifier(ref.watch(sharedPreferencesProvider));
});


// ── Followers / Following Lists ──────────────────────────────────────────────
final followersListProvider = FutureProvider.autoDispose.family<List<UserProfile>, String>(
  (ref, userId) => ref.read(profileServiceProvider).getFollowers(userId),
);

final followingListProvider = FutureProvider.autoDispose.family<List<UserProfile>, String>(
  (ref, userId) => ref.read(profileServiceProvider).getFollowing(userId),
);

// ── Search Users ──────────────────────────────────────────────
final userSearchProvider = FutureProvider.autoDispose.family<List<UserProfile>, String>(
  (ref, query) => query.isEmpty
      ? Future.value([])
      : ref.read(profileServiceProvider).searchUsers(query),
);

final popularCreatorsProvider = FutureProvider.autoDispose<List<UserProfile>>((ref) {
  return ref.read(profileServiceProvider).getPopularCreators();
});

final popularTeachersProvider = FutureProvider.autoDispose<List<UserProfile>>((ref) {
  return ref.read(profileServiceProvider).getPopularTeachers();
});

final teacherSearchProvider = FutureProvider.autoDispose.family<List<UserProfile>, String>(
  (ref, query) => query.isEmpty
      ? Future.value([])
      : ref.read(profileServiceProvider).searchTeachers(query),
);


final popularNotesProvider = FutureProvider.autoDispose<List<Note>>((ref) {
  return ref.read(notesServiceProvider).getPopularNotes();
});

// ── Forum ─────────────────────────────────────────────────────────────────────
final forumQuestionsProvider = FutureProvider.autoDispose.family<List<ForumQuestion>, ({String? subject, String? query, String? userId})>(
  (ref, args) => ref.read(forumServiceProvider).getQuestions(subject: args.subject, query: args.query, userId: args.userId),
);

final forumQuestionDetailProvider = FutureProvider.autoDispose.family<ForumQuestion?, String>(
  (ref, id) => ref.read(forumServiceProvider).getQuestionById(id),
);

final forumAnswersProvider = FutureProvider.autoDispose.family<List<ForumAnswer>, String>(
  (ref, questionId) => ref.read(forumServiceProvider).getAnswers(questionId),
);

// ── Real-time Note Stats Sync ──────────────────────────────────────────────
final noteStatsSyncProvider = Provider.autoDispose((ref) {
  final client = ref.read(supabaseClientProvider);
  // Only subscribe when user is authenticated
  final uid = client.auth.currentUser?.id;
  if (uid == null) return;

  final channel = client.channel('public:notes_stats_\$uid');
  channel.onPostgresChanges(
    event: PostgresChangeEvent.update,
    schema: 'public',
    table: 'notes',
    callback: (payload) {
      final data = payload.newRecord;
      final noteId = data['id'] as String;
      final likesCount = data['likes_count'] as int?;
      final savesCount = data['saves_count'] as int?;
      
      ref.read(interactionProvider.notifier).updateNoteStats(
        noteId,
        likesCount: likesCount,
        savesCount: savesCount,
      );
      
      // Also sync feed if needed
      ref.read(feedProvider.notifier).syncExternalStats(noteId, likesCount, savesCount);
    },
  ).subscribe();

  ref.onDispose(() => client.removeChannel(channel));
});
