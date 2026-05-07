import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/note.dart';

class NotesService {
  final SupabaseClient _client;
  NotesService(this._client);

  static const int _pageSize = 20;

  // -- Feed -------------------------------------------------------------------
  Future<List<Note>> getForYouFeed({int page = 0, String? subject}) async {
    var query = _client
        .from('notes')
        .select('*, users!user_id(id, full_name, username, avatar_url, is_verified_creator)')
        .eq('status', 'active')
        .eq('visibility', 'public');

    if (subject != null) {
      query = query.eq('subject', subject);
    }

    final data = await query
        .order('created_at', ascending: false)
        .range(page * _pageSize, (page + 1) * _pageSize - 1);

    final notes = (data as List).map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();

    // Enrich is_liked / is_saved / thumbnail URLs for current user
    return enrichWithInteractions(notes);
  }

  Future<List<Note>> getFollowingFeed({int page = 0}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final followed = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', uid);
    final ids = (followed as List).map((e) => e['following_id'] as String).toList();
    if (ids.isEmpty) return [];
    final data = await _client
        .from('notes')
        .select('*, users!user_id(id, full_name, username, avatar_url, is_verified_creator)')
        .inFilter('user_id', ids)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .range(page * _pageSize, (page + 1) * _pageSize - 1);
    final notes = (data as List).map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
    return enrichWithInteractions(notes);
  }

  /// Fetch is_liked / is_saved for a batch of notes in ONE query each.
  /// Also generates signed thumbnail URLs in a single batch storage call.
  /// This prevents N+1 queries and ensures cross-screen sync accuracy.
  Future<List<Note>> enrichWithInteractions(List<Note> notes) async {
    final uid = _client.auth.currentUser?.id;
    if (notes.isEmpty) return notes;

    // -- 1. Batch-fetch liked / saved state ------------------------------
    Set<String> likedIds = {};
    Set<String> savedIds = {};

    if (uid != null) {
      final ids = notes.map((n) => n.id).toList();

      final likesData = await _client
          .from('likes')
          .select('note_id')
          .eq('user_id', uid)
          .inFilter('note_id', ids);
      likedIds = (likesData as List).map((e) => e['note_id'] as String).toSet();

      final savesData = await _client
          .from('saves')
          .select('note_id')
          .eq('user_id', uid)
          .inFilter('note_id', ids);
      savedIds = (savesData as List).map((e) => e['note_id'] as String).toSet();
    }

    // -- 2. Batch-generate signed thumbnail URLs -------------------------
    // FIX: Fallback to first file key if thumbnail_key is missing (especially for images)
    final needsThumbnail = notes
        .where((n) => (n.thumbnailKey != null && n.thumbnailKey!.isNotEmpty || n.fileKeys.isNotEmpty) && n.thumbnailUrl == null)
        .toList();

    Map<String, String> thumbnailUrls = {};
    if (needsThumbnail.isNotEmpty) {
      try {
        final keys = needsThumbnail.map((n) {
          if (n.thumbnailKey != null && n.thumbnailKey!.isNotEmpty) return n.thumbnailKey!;

          // Fallback logic
          if (n.fileType == 'image_set' && n.fileKeys.isNotEmpty) {
            return n.fileKeys.first;
          } else if (n.fileType == 'pdf' && n.fileKeys.isNotEmpty) {
            // Try to use the first page image if it exists (standard convention in this app)
            return n.fileKeys.first;
          }
          return n.fileKeys.isNotEmpty ? n.fileKeys.first : '';
        }).where((k) => k.isNotEmpty).toList();

        if (keys.isNotEmpty) {
          final signed = await _client.storage
              .from('notes-files')
              .createSignedUrls(keys, 3600 * 6); // 6-hour expiry

          // Map back to notes (signed list matches keys list order)
          for (int i = 0; i < keys.length; i++) {
            final url = signed[i].signedUrl;
            if (url.isNotEmpty) {
              thumbnailUrls[needsThumbnail[i].id] = url;
            }
          }
        }
      } catch (_) {
        // Thumbnail URLs are non-critical — fall back to placeholder silently
      }
    }

    // -- 3. Merge everything ---------------------------------------------
    return notes.map((n) => n.copyWith(
      isLiked: likedIds.contains(n.id) || n.isLiked,
      isSaved: savedIds.contains(n.id) || n.isSaved,
      thumbnailUrl: thumbnailUrls[n.id] ?? n.thumbnailUrl,
    )).toList();
  }

  // -- Single Note ------------------------------------------------------------
  Future<Note?> getNoteById(String noteId) async {
    final data = await _client
        .from('notes')
        .select('*, users!user_id(id, full_name, username, avatar_url, is_verified_creator)')
        .eq('id', noteId)
        .maybeSingle();
    if (data == null) return null;
    var note = Note.fromJson(data);

    // Enrich with interaction state
    final uid = _client.auth.currentUser?.id;
    if (uid != null) {
      final liked = await _client.from('likes').select('id')
          .eq('note_id', noteId).eq('user_id', uid).maybeSingle();
      final saved = await _client.from('saves').select('id')
          .eq('note_id', noteId).eq('user_id', uid).maybeSingle();
      note = note.copyWith(isLiked: liked != null, isSaved: saved != null);
    }

    // Generate signed thumbnail URL if needed
    if (note.thumbnailUrl == null) {
       String? tKey;
       if (note.thumbnailKey != null && note.thumbnailKey!.isNotEmpty) {
         tKey = note.thumbnailKey;
       } else if (note.fileKeys.isNotEmpty) {
         if (note.fileType == 'image_set') {
           tKey = note.fileKeys.first;
         } else if (note.fileType == 'pdf') {
           tKey = note.fileKeys.first;
         } else {
           tKey = note.fileKeys.first;
         }
       }

      if (tKey != null) {
        try {
          final signed = await _client.storage
              .from('notes-files')
              .createSignedUrls([tKey], 3600 * 6);
          final url = signed.first.signedUrl;
          if (url.isNotEmpty) note = note.copyWith(thumbnailUrl: url);
        } catch (_) {}
      }
    }

    return note;
  }

  // -- Like / Save (using atomic DB toggle for safety) ------------------------
  Future<void> toggleLike(String noteId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      // Try new atomic RPC first (migration 017)
      await _client.rpc('toggle_like', params: {
        'p_note_id': noteId,
        'p_user_id': uid,
      });
    } catch (_) {
      // Fallback to original insert/delete pattern
      await _legacyToggleLike(noteId, uid);
    }
  }

  Future<void> _legacyToggleLike(String noteId, String uid) async {
    final note = await _client.from('notes').select('user_id, title').eq('id', noteId).single();
    final authorId = note['user_id'] as String;
    final noteTitle = note['title'] as String;

    try {
      await _client.from('likes').insert({'note_id': noteId, 'user_id': uid});
      try {
        await _client.rpc('increment_like_count', params: {'target_note_id': noteId});
        await _client.rpc('increment_user_points', params: {'target_user_id': authorId, 'amount': 5});
      } catch (_) {}

      if (authorId != uid) {
        try {
          final me = await _client.from('users').select('full_name').eq('id', uid).single();
          await _client.from('notifications').insert({
            'user_id': authorId,
            'type': 'like',
            'title': 'New Like',
            'message': "${me['full_name']} liked your note: $noteTitle",
            'reference_id': noteId,
          });
        } catch (_) {}
      }
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        await _client.from('likes').delete().eq('note_id', noteId).eq('user_id', uid);
        try {
          await _client.rpc('decrement_like_count', params: {'target_note_id': noteId});
          await _client.rpc('decrement_user_points', params: {'target_user_id': authorId, 'amount': 5});
        } catch (_) {}
      } else {
        rethrow;
      }
    }
  }

  Future<void> toggleSave(String noteId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      await _client.rpc('toggle_save', params: {
        'p_note_id': noteId,
        'p_user_id': uid,
      });
    } catch (_) {
      await _legacyToggleSave(noteId, uid);
    }
  }

  Future<void> _legacyToggleSave(String noteId, String uid) async {
    final note = await _client.from('notes').select('user_id, title').eq('id', noteId).single();
    final authorId = note['user_id'] as String;
    final noteTitle = note['title'] as String;

    try {
      await _client.from('saves').insert({'note_id': noteId, 'user_id': uid});
      try {
        await _client.rpc('increment_save_count', params: {'target_note_id': noteId});
        await _client.rpc('increment_user_points', params: {'target_user_id': authorId, 'amount': 10});
      } catch (_) {}

      if (authorId != uid) {
        try {
          final me = await _client.from('users').select('full_name').eq('id', uid).single();
          await _client.from('notifications').insert({
            'user_id': authorId,
            'type': 'save',
            'title': 'Note Saved',
            'message': "${me['full_name']} saved your note: $noteTitle",
            'reference_id': noteId,
          });
        } catch (_) {}
      }
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        await _client.from('saves').delete().eq('note_id', noteId).eq('user_id', uid);
        try {
          await _client.rpc('decrement_save_count', params: {'target_note_id': noteId});
          await _client.rpc('decrement_user_points', params: {'target_user_id': authorId, 'amount': 10});
        } catch (_) {}
      } else {
        rethrow;
      }
    }
  }

  Future<void> processDownload(String noteId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      // Award points and notify author via atomic DB function
      await _client.rpc('process_download', params: {
        'p_note_id': noteId,
        'p_user_id': uid,
      });
    } catch (e) {
      // Silent error for analytics-like features
    }
  }

  // -- Upload ------------------------------------------------------------------
  Future<String> createNote({
    required String title, required String description, required String subject,
    required String board, required String classLevel, required List<String> tags,
    required String folderId, required int pageCount,
  }) async {
    final uid = _client.auth.currentUser!.id;
    final data = await _client.from('notes').insert({
      'user_id': uid, 'title': title, 'description': description,
      'subject': subject, 'board': board, 'class_level': classLevel,
      'tags': tags, 'folder_id': folderId, 'page_count': pageCount,
      'status': 'processing',
    }).select('id').single();
    return data['id'];
  }

  Future<List<String>> getSignedPageUrls(String noteId, int count) async {
    final data = await _client.from('notes').select('file_keys').eq('id', noteId).maybeSingle();
    if (data == null) throw Exception('Note not found: $noteId');

    final fileKeys = (data['file_keys'] as List<dynamic>?)
        ?.map((e) => e.toString()).where((k) => k.isNotEmpty).toList() ?? [];

    if (fileKeys.isEmpty) throw Exception('No files attached to this note yet.');

    final signedUrls = await _client.storage
        .from('notes-files')
        .createSignedUrls(fileKeys, 3600);

    final result = signedUrls.where((e) => e.signedUrl.isNotEmpty).map((e) => e.signedUrl).toList();
    if (result.isEmpty) throw Exception('Could not generate signed URLs for files');
    return result;
  }

  Future<List<String>> uploadFiles({
    required List<dynamic> files, required String noteId, required String userId,
  }) async {
    final keys = <String>[];
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final key = "$userId/$noteId/original_$i.${file.path.split('.').last}";
      await _client.storage.from('notes-files').upload(
        key, file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );
      keys.add(key);
    }
    return keys;
  }

  Stream<String> watchNoteStatus(String noteId) {
    return _client.from('notes')
        .stream(primaryKey: ['id'])
        .eq('id', noteId)
        .map((rows) => rows.isNotEmpty ? rows.first['status'] as String : 'processing');
  }

  Future<List<Note>> getUserNotes(String userId, {String? folderId, String? status}) async {
    var query = _client.from('notes')
        .select('*, users!user_id(id, full_name, username, avatar_url, is_verified_creator)')
        .eq('user_id', userId);

    if (status != null) {
      query = query.eq('status', status);
    } else {
      // For profile/folder views where no status is specified, 
      // fetch everything non-removed (UI will handle visibility filtering)
      query = query.inFilter('status', ['active', 'pending_review', 'processing']);
    }

    if (folderId != null) query = query.eq('folder_id', folderId);

    final data = await query.order('created_at', ascending: false);
    final notes = (data as List).map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
    return enrichWithInteractions(notes);
  }

  // -- Saved Notes --------------------------------------------------------------
  Future<List<Note>> getSavedNotes() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final data = await _client
        .from('saves')
        .select('note_id, notes!note_id(*, users!user_id(id, full_name, username, avatar_url, is_verified_creator))')
        .eq('user_id', uid)
        .order('created_at', ascending: false);

    final notes = (data as List).map((e) {
      final noteData = e['notes'] as Map<String, dynamic>;
      if (noteData['status'] != 'active') return null;
      return Note.fromJson({...noteData, 'is_saved': true});
    }).whereType<Note>().toList();

    return enrichWithInteractions(notes);
  }

  // -- Liked Notes --------------------------------------------------------------
  Future<List<Note>> getLikedNotes() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final data = await _client
        .from('likes')
        .select('note_id, notes!note_id(*, users!user_id(id, full_name, username, avatar_url, is_verified_creator))')
        .eq('user_id', uid)
        .order('created_at', ascending: false);

    final notes = (data as List).map((e) {
      final noteData = e['notes'] as Map<String, dynamic>;
      if (noteData['status'] != 'active') return null;
      return Note.fromJson({...noteData, 'is_liked': true});
    }).whereType<Note>().toList();

    return enrichWithInteractions(notes);
  }

  // -- Explore/Search -----------------------------------------------------------
  Future<List<Note>> searchNotes(String query,
      {String? subject, String? board, String? classLevel}) async {
    if (query.isEmpty && subject == null) return [];
    
    try {
      final data = await _client.rpc('search_notes_fuzzy', params: {
        'p_query': query,
        'p_subject': subject,
        'p_limit': 30,
      });
      final notes = (data as List).map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
      return enrichWithInteractions(notes);
    } catch (_) {
      // Fallback to legacy ILIKE search
      var q = _client
          .from('notes')
          .select('*, users!user_id(id, full_name, username, avatar_url, is_verified_creator)')
          .eq('status', 'active')
          .or('title.ilike.%$query%,description.ilike.%$query%,subject.ilike.%$query%');

      if (subject != null) q = q.eq('subject', subject);
      if (board != null) q = q.eq('board', board);
      if (classLevel != null) q = q.eq('class_level', classLevel);

      final data = await q.order('created_at', ascending: false).limit(30);
      final notes = (data as List).map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
      return enrichWithInteractions(notes);
    }
  }

  Future<List<Note>> getPopularNotes() async {
    try {
      final data = await _client.rpc('get_popular_notes', params: {'p_limit': 15});
      final notes = (data as List).map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
      return enrichWithInteractions(notes);
    } catch (e) {
      // Fallback if RPC fails: Fetch by likes_count
      final data = await _client.from('notes')
          .select('*, users!user_id(id, full_name, username, avatar_url, is_verified_creator)')
          .eq('status', 'active')
          .eq('visibility', 'public')
          .order('likes_count', ascending: false)
          .limit(15);
      final notes = (data as List).map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
      return enrichWithInteractions(notes);
    }
  }

  Future<void> recordSearch(String noteId) async {
    try {
      await _client.rpc('increment_note_search', params: {'p_note_id': noteId});
    } catch (_) {}
  }

  Future<void> recordView(String noteId) async {
    try { await _client.rpc('increment_views', params: {'note_id': noteId}); } catch (_) {}
  }

  Future<void> reportNote(String noteId, String reason, String? extra) async {
    await _client.from('reports').insert({
      'note_id': noteId,
      'reporter_id': _client.auth.currentUser?.id,
      'reason': reason,
      'details': extra,
    });
  }

  Future<void> deleteNote(String noteId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client.from('notes')
        .update({'status': 'removed', 'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', noteId).eq('user_id', uid);
  }

  Future<void> updateNote({
    required String noteId, required String title, required String description,
    required String subject, required String classLevel, required String board,
    required String visibility, required List<String> tags,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client.from('notes').update({
      'title': title, 'description': description, 'subject': subject,
      'class_level': classLevel, 'board': board, 'visibility': visibility,
      'tags': tags, 'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', noteId).eq('user_id', uid);
  }

  Future<void> updatePageCount(String noteId, int count) async {
    try {
      await _client.from('notes').update({'page_count': count}).eq('id', noteId);
    } catch (_) {}
  }

  Future<String> createNoteDraft({
    required String title, required String subject, required String board,
    required String classLevel, required String fileType, required List<String> fileKeys,
    required List<String> tags, required String visibility, required String description,
    String? folderId, bool requiresApproval = false,
  }) async {
    final uid = _client.auth.currentUser!.id;

    // Auto-set thumbnail_key if it's an image set
    String? thumbnailKey;
    if (fileType == 'image_set' && fileKeys.isNotEmpty) {
      thumbnailKey = fileKeys.first;
    } else if (fileType == 'pdf' && fileKeys.isNotEmpty) {
       // Conventional fallback for PDFs (backend often generates this)
       thumbnailKey = fileKeys.first;
    }

    final data = await _client.from('notes').insert({
      'user_id': uid, 'title': title, 'subject': subject, 'board': board,
      'class_level': classLevel, 'file_type': fileType, 'file_keys': fileKeys,
      'thumbnail_key': thumbnailKey,
      'tags': tags, 'visibility': visibility, 'description': description,
      'folder_id': folderId,
      'status': requiresApproval ? 'pending_review' : 'active',
      'page_count': fileKeys.length,
    }).select('id').single();
    return data['id'];
  }
}





