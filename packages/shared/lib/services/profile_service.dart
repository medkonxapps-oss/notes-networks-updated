import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart';
import '../models/folder.dart';

class ProfileService {
  final SupabaseClient _client;
  ProfileService(this._client);

  Future<UserProfile?> getProfile(String userId) async {
    final data = await _client.from('users').select()
        .eq('id', userId).maybeSingle();
    if (data == null) return null;
    return UserProfile.fromJson(data);
  }

  Future<List<UserProfile>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    try {
      final data = await _client.rpc('search_users_fuzzy', params: {
        'p_query': query,
        'p_limit': 20,
      });
      return (data as List).map((e) => UserProfile.fromJson(e)).toList();
    } catch (_) {
      // Fallback to legacy ILIKE search if RPC fails
      final data = await _client.from('users').select()
          .or('username.ilike.%$query%,full_name.ilike.%$query%,institution_name.ilike.%$query%')
          .neq('role', 'teacher')
          .eq('is_active', true)
          .limit(20);
      return data.map((e) => UserProfile.fromJson(e)).toList();
    }
  }

  Future<List<UserProfile>> getPopularCreators() async {
    final data = await _client.rpc('get_popular_creators', params: {'p_limit': 10});
    return (data as List).map((e) => UserProfile.fromJson(e)).toList();
  }

  Future<List<UserProfile>> getPopularTeachers() async {
    final data = await _client.rpc('get_popular_teachers', params: {'p_limit': 10});
    return (data as List).map((e) => UserProfile.fromJson(e)).toList();
  }

  Future<List<UserProfile>> searchTeachers(String query) async {
    if (query.isEmpty) return [];
    try {
      final data = await _client.rpc('search_teachers_fuzzy', params: {
        'p_query': query,
        'p_limit': 20,
      });
      return (data as List).map((e) => UserProfile.fromJson(e)).toList();
    } catch (_) {
      // Fallback
      final data = await _client.from('users').select()
          .eq('role', 'teacher')
          .eq('teacher_status', 'approved')
          .or('username.ilike.%$query%,full_name.ilike.%$query%,institution_name.ilike.%$query%')
          .eq('is_active', true)
          .limit(20);
      return data.map((e) => UserProfile.fromJson(e)).toList();
    }
  }

  Future<void> recordSearch(String userId) async {
    try {
      await _client.rpc('increment_user_search', params: {'p_user_id': userId});
    } catch (_) {}
  }

  // ── Followers / Following ─────────────────────────────────────────────
  Future<List<UserProfile>> getFollowers(String userId) async {
    final data = await _client
        .from('follows')
        .select('follower_id, users!follower_id(*)')
        .eq('following_id', userId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => UserProfile.fromJson(e['users'] as Map<String, dynamic>))
        .toList();
  }

  Future<List<UserProfile>> getFollowing(String userId) async {
    final data = await _client
        .from('follows')
        .select('following_id, users!following_id(*)')
        .eq('follower_id', userId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => UserProfile.fromJson(e['users'] as Map<String, dynamic>))
        .toList();
  }

  // ── Folders ──────────────────────────────────────────────────────────
  Future<List<Folder>> getUserFolders(String userId) async {
    final data = await _client.from('folders').select()
        .eq('user_id', userId)
        .isFilter('parent_folder_id', null)
        .order('created_at');
    return data.map((e) => Folder.fromJson(e)).toList();
  }

  Future<List<Folder>> getSubFolders(String parentFolderId) async {
    final data = await _client.from('folders').select()
        .eq('parent_folder_id', parentFolderId)
        .order('created_at');
    return data.map((e) => Folder.fromJson(e)).toList();
  }

  Future<Folder> createFolder(String userId, String name, String colorHex,
      {String? parentFolderId}) async {
    final data = await _client.from('folders').insert({
      'user_id': userId,
      'name': name,
      'color_hex': colorHex,
      if (parentFolderId != null) 'parent_folder_id': parentFolderId,
    }).select().single();
    return Folder.fromJson(data);
  }

  Future<void> updateFolder(String folderId, String name, String colorHex) async {
    await _client.from('folders').update({
      'name': name,
      'color_hex': colorHex,
    }).eq('id', folderId);
  }

  Future<void> deleteFolder(String folderId) async {
    await _client.from('folders').delete().eq('id', folderId);
  }

  // ── Follow ───────────────────────────────────────────────────────────
  Future<bool> isFollowing(String followerId, String followingId) async {
    final data = await _client.from('follows').select('id')
        .eq('follower_id', followerId).eq('following_id', followingId)
        .maybeSingle();
    return data != null;
  }

  Future<bool> toggleFollow(String followingId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || uid == followingId) return false;

    final existing = await _client.from('follows').select('id')
        .eq('follower_id', uid).eq('following_id', followingId).maybeSingle();

    if (existing != null) {
      await _client.from('follows').delete()
          .eq('follower_id', uid).eq('following_id', followingId);

      try {
        await _client.rpc('decrement_follower_count', params: {'target_user_id': followingId});
        await _client.rpc('decrement_following_count', params: {'target_user_id': uid});
      } catch (_) {}

      return false;
    } else {
      await _client.from('follows').insert(
          {'follower_id': uid, 'following_id': followingId});

      try {
        await _client.rpc('increment_follower_count', params: {'target_user_id': followingId});
        await _client.rpc('increment_following_count', params: {'target_user_id': uid});
      } catch (_) {}

      try {
        final me = await _client.from('users').select('full_name').eq('id', uid).single();
        await _client.from('notifications').insert({
          'user_id': followingId,
          'type': 'follow',
          'title': 'New Follower',
          'message': '${me['full_name']} started following you!',
          'reference_id': uid,
        });
      } catch (_) {}

      return true;
    }
  }

  Future<String> uploadAvatar(String userId, dynamic bytes) async {
    const extension = 'jpg';
    final fileName = '$userId/avatar.$extension';
    await _client.storage.from('avatars').uploadBinary(
      fileName,
      bytes,
      fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
    );
    final avatarUrl = '${_client.storage.from('avatars').getPublicUrl(fileName)}?t=${DateTime.now().millisecondsSinceEpoch}';
    await _client.from('users').update({'avatar_url': avatarUrl}).eq('id', userId);
    return avatarUrl;
  }

  Future<void> reportUser({
    required String targetUserId,
    required String reason,
    String? details,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    await _client.from('reports').insert({
      'reporter_id': uid,
      'target_user_id': targetUserId,
      'target_type': 'user',
      'reason': reason,
      'details': details,
    });
  }
}
