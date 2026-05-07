import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class AuditLogger {
  static final _client = Supabase.instance.client;

  /// Logs an administrative action to the audit log table.
  /// 
  /// [action] - The name of the action (e.g., 'suspend_user', 'approve_note').
  /// [targetId] - The ID of the affected resource (user_id, note_id, etc.).
  /// [targetType] - The type of resource ('user', 'note', 'config', etc.).
  /// [details] - Human-readable description of the change.
  static Future<void> log({
    required String action,
    required String targetId,
    required String targetType,
    required String details,
  }) async {
    try {
      final adminId = _client.auth.currentUser?.id;
      if (adminId == null) return;

      await _client.rpc('log_admin_action', params: {
        'p_admin_id': adminId,
        'p_action': action,
        'p_target_id': targetId,
        'p_target_type': targetType,
        'p_details': details,
      });
    } catch (e) {
      debugPrint('Audit Log Error: $e');
    }
  }
}
