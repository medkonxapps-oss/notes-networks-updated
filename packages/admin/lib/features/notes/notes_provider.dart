import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final adminNotesListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await Supabase.instance.client
      .from('notes')
      .select('*, users(full_name, username)')
      .order('created_at', ascending: false);
  return (data as List).cast<Map<String, dynamic>>();
});

class AdminNotesActions {
  final Ref _ref;
  AdminNotesActions(this._ref);

  Future<void> updateStatus(String noteId, String status) async {
    await Supabase.instance.client
        .from('notes')
        .update({'status': status})
        .eq('id', noteId);
    _ref.invalidate(adminNotesListProvider);
  }

  Future<void> deleteNote(String noteId) async {
    // Soft delete if possible, but let's just use the status field
    await updateStatus(noteId, 'removed');
  }
}

final adminNotesActionsProvider = Provider((ref) => AdminNotesActions(ref));
