import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class CollectionsService {
  final SupabaseClient _client;
  CollectionsService(this._client);

  Future<void> createCollection({
    required String title,
    String? description,
    String? thumbnailUrl,
    bool isPublic = true,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    await _client.from('note_collections').insert({
      'user_id': uid,
      'title': title,
      'description': description,
      'thumbnail_url': thumbnailUrl,
      'is_public': isPublic,
    });
  }

  Future<String> uploadCollectionCover(String collectionId, File file) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    final extension = file.path.split('.').last;
    final path = '$uid/collections/$collectionId/cover_$extension';

    await _client.storage.from('notes-files').upload(
      path,
      file,
      fileOptions: const FileOptions(upsert: true),
    );

    // Get signed URL for the cover (6 months expiry)
    final signedUrl = await _client.storage
        .from('notes-files')
        .createSignedUrl(path, 60 * 60 * 24 * 180);

    // Update the collection with the signed URL
    await _client.from('note_collections')
        .update({'thumbnail_url': signedUrl})
        .eq('id', collectionId);

    return signedUrl;
  }

  Future<void> addNoteToCollection(String collectionId, String noteId) async {
    await _client.from('note_collection_items').insert({
      'collection_id': collectionId,
      'note_id': noteId,
    });
  }

  Future<void> removeNoteFromCollection(String collectionId, String noteId) async {
    await _client.from('note_collection_items')
        .delete()
        .eq('collection_id', collectionId)
        .eq('note_id', noteId);
  }

  Future<List<Map<String, dynamic>>> getCollectionNotes(String collectionId) async {
    final res = await _client.from('note_collection_items')
        .select('*, notes(*, users(full_name, username, avatar_url, is_verified_creator))')
        .eq('collection_id', collectionId)
        .order('sort_order', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }
}
