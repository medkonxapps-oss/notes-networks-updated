import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/utils/audit_logger.dart';

// Reports (user-reported content)
final moderationListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client
      .from('reports')
      .select('''
        *,
        note:note_id(id, title, status, subject, file_type, file_keys),
        reporter:reporter_id(id, username, full_name),
        target_user:target_user_id(id, username, full_name)
      ''')
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});

// Notes pending admin review
final pendingReviewProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client
      .from('notes')
      .select('*, users!user_id(id, username, full_name, avatar_url)')
      .eq('status', 'pending_review')
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});

// Moderation history (Approved/Rejected notes)
final moderationHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client
      .from('notes')
      .select('*, users!user_id(id, username, full_name, avatar_url)')
      .neq('status', 'pending_review')
      .order('updated_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});

// Selected note IDs for bulk operations
final selectedNoteIdsProvider = StateProvider<Set<String>>((ref) => {});

final moderationActionsProvider = Provider((ref) => ModerationActions(ref));

class ModerationActions {
  final Ref _ref;
  ModerationActions(this._ref);

  Future<void> updateReportStatus(String id, String status, {String? adminNote}) async {
    await Supabase.instance.client
        .from('reports')
        .update({'status': status, if (adminNote != null) 'admin_note': adminNote})
        .eq('id', id);
    _ref.invalidate(moderationListProvider);
  }

  Future<void> resolveReport(String reportId, String status, {String? adminNote, String action = 'none', int penaltyPoints = 0}) async {
    await Supabase.instance.client.rpc('resolve_report', params: {
      'p_report_id': reportId,
      'p_status': status,
      'p_admin_note': adminNote,
      'p_action': action,
      'p_penalty_points': penaltyPoints,
    });
    _ref.invalidate(moderationListProvider);
  }

  Future<void> restoreNote(String noteId) async {
    await Supabase.instance.client.rpc('restore_note', params: {
      'p_note_id': noteId,
    });
    _ref.invalidate(moderationListProvider);
    _ref.invalidate(moderationHistoryProvider);
  }

  Future<void> updateNoteStatus(String noteId, String status) async {
    final adminId = Supabase.instance.client.auth.currentUser?.id;
    await Supabase.instance.client
        .from('notes')
        .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', noteId);
    // Audit log
    if (adminId != null) {
      await Supabase.instance.client.rpc('log_admin_action', params: {
        'p_admin_id': adminId,
        'p_action': status == 'active' ? 'approve_note' : status == 'removed' ? 'reject_note' : 'update_note_status',
        'p_target_id': noteId,
        'p_target_type': 'note',
        'p_details': 'Note status changed to $status',
      }).catchError((_) {});
    }
    _ref.invalidate(moderationListProvider);
    _ref.invalidate(pendingReviewProvider);
  }

  Future<void> approveNote(String noteId, String userId) async {
    await Supabase.instance.client
        .from('notes')
        .update({'status': 'active', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', noteId);
    await Supabase.instance.client.from('notifications').insert({
      'user_id': userId,
      'type': 'reward',
      'title': '✅ Note Approved! (+50 pts)',
      'message': 'Your note has been approved. You earned 50 points!',
      'reference_id': noteId,
    });
    _ref.invalidate(pendingReviewProvider);
    _ref.read(selectedNoteIdsProvider.notifier).update((s) => {...s}..remove(noteId));
  }

  Future<void> unapproveNote(String noteId) async {
    await Supabase.instance.client
        .from('notes')
        .update({'status': 'pending_review', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', noteId);
    _ref.invalidate(pendingReviewProvider);
    _ref.invalidate(moderationHistoryProvider);
  }

  Future<void> updateAdminReview(String noteId, String review) async {
    // Assuming there is a column 'admin_review' in notes table
    // If it fails, we know it's missing.
    await Supabase.instance.client
        .from('notes')
        .update({'admin_review': review})
        .eq('id', noteId);
    _ref.invalidate(pendingReviewProvider);
    _ref.invalidate(moderationHistoryProvider);
  }

  /// Bulk approve — approves all selected notes
  Future<int> bulkApprove(Set<String> selectedIds) async {
    if (selectedIds.isEmpty) return 0;
    
    debugPrint('bulkApprove: Fetching details for ${selectedIds.length} notes...');
    
    try {
      // 1. Fetch the notes to get user_ids for notifications
      // We fetch directly from DB to ensure we have the latest data and all selected items
      final notesRes = await Supabase.instance.client
          .from('notes')
          .select('id, user_id')
          .inFilter('id', selectedIds.toList());
      
      final toApprove = List<Map<String, dynamic>>.from(notesRes);
      if (toApprove.isEmpty) {
        debugPrint('bulkApprove: No matching notes found in database for IDs: $selectedIds');
        return 0;
      }

      final noteIds = toApprove.map((n) => n['id'].toString()).toList();
      debugPrint('bulkApprove: Updating ${noteIds.length} notes to active status');

      // 2. Bulk update notes status to active
      await Supabase.instance.client
          .from('notes')
          .update({
            'status': 'active', 
            'updated_at': DateTime.now().toIso8601String()
          })
          .inFilter('id', noteIds);

      // 3. Prepare and insert bulk notifications
      final notifications = toApprove.map((n) => {
        'user_id': n['user_id'],
        'type': 'reward',
        'title': '✅ Note Approved! (+50 pts)',
        'message': 'Your note has been approved. You earned 50 points!',
        'reference_id': n['id'],
      }).toList();

      if (notifications.isNotEmpty) {
        try {
          await Supabase.instance.client.from('notifications').insert(notifications);
        } catch (notifErr) {
          debugPrint('Warning: Bulk notifications failed (notes were updated): $notifErr');
        }
      }

      // 4. Log the bulk action
      try {
        await AuditLogger.log(
          action: 'bulk_approve_notes',
          targetId: 'multiple',
          targetType: 'note',
          details: 'Approved ${toApprove.length} notes: ${noteIds.take(5).join(', ')}${noteIds.length > 5 ? '...' : ''}',
        );
      } catch (logErr) {
        debugPrint('Warning: Audit log failed: $logErr');
      }

      // 5. Update state and invalidate providers
      _ref.read(selectedNoteIdsProvider.notifier).state = {};
      _ref.invalidate(pendingReviewProvider);
      _ref.invalidate(moderationHistoryProvider);
      
      return toApprove.length;
    } catch (e) {
      debugPrint('Error in bulkApprove: $e');
      rethrow;
    }
  }

  Future<void> rejectNote(String noteId, String userId, String reason) async {
    await Supabase.instance.client
        .from('notes')
        .update({'status': 'removed', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', noteId);
    await Supabase.instance.client.from('notifications').insert({
      'user_id': userId,
      'type': 'system',
      'title': '❌ Note Not Approved',
      'message': 'Your note was not approved. Reason: $reason',
      'reference_id': noteId,
    });
    _ref.invalidate(pendingReviewProvider);
    _ref.read(selectedNoteIdsProvider.notifier).update((s) => {...s}..remove(noteId));
  }

  /// Real-time stream of notes pending review
  Stream<List<Map<String, dynamic>>> watchPendingNotes() {
    return Supabase.instance.client
        .from('notes')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending_review')
        .order('created_at', ascending: false)
        .map((rows) => List<Map<String, dynamic>>.from(rows));
  }

  /// Fetch signed URLs for a note's files (for preview)
  Future<List<String>> getPreviewUrls(List<dynamic> fileKeys) async {
    if (fileKeys.isEmpty) return [];
    final keys = fileKeys.map((e) => e.toString()).toList();
    final result = await Supabase.instance.client.storage
        .from('notes-files')
        .createSignedUrls(keys, 3600);
    return result.map((e) => e.signedUrl).where((u) => u.isNotEmpty).toList();
  }
}
