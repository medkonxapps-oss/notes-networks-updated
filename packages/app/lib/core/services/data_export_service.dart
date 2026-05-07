import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DataExportService {
  final SupabaseClient _client;
  final NotesService _notesService;
  final ProfileService _profileService;

  DataExportService(this._client, this._notesService, this._profileService);

  Future<void> exportUserData() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    final uid = user.id;

    // 1. Gather all data
    final profile = await _profileService.getProfile(uid);
    final notes = await _notesService.getUserNotes(uid);
    final folders = await _profileService.getUserFolders(uid);
    final followers = await _profileService.getFollowers(uid);
    final following = await _profileService.getFollowing(uid);
    final savedNotes = await _notesService.getSavedNotes();
    final likedNotes = await _notesService.getLikedNotes();

    // 2. Format as JSON
    final exportData = {
      'export_date': DateTime.now().toIso8601String(),
      'profile': profile?.toJson(),
      'notes': notes.map((n) => n.toJson()).toList(),
      'folders': folders.map((f) => f.toJson()).toList(),
      'followers_count': followers.length,
      'followers': followers.map((f) => {'username': f.username, 'full_name': f.fullName}).toList(),
      'following_count': following.length,
      'following': following.map((f) => {'username': f.username, 'full_name': f.fullName}).toList(),
      'saved_notes_count': savedNotes.length,
      'saved_notes': savedNotes.map((n) => {'id': n.id, 'title': n.title}).toList(),
      'liked_notes_count': likedNotes.length,
      'liked_notes': likedNotes.map((n) => {'id': n.id, 'title': n.title}).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

    // 3. Save to temporary file
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/notesnet_data_export.json');
    await file.writeAsString(jsonString);

    // 4. Share the file
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      subject: 'My NotesNet Data Export',
      text: 'Here is your personal data export from NotesNet.',
    ));
  }
}
