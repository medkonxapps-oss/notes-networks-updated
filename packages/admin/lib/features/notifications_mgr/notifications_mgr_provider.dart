import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/utils/audit_logger.dart';

final broadcastHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await Supabase.instance.client
      .from('app_broadcasts')
      .select('*, admin:admin_id(username, full_name)')
      .order('created_at', ascending: false)
      .limit(50);
  return List<Map<String, dynamic>>.from(res);
});

final notificationAdminActionsProvider = Provider((ref) => NotificationAdminActions(ref));

class NotificationAdminActions {
  final Ref _ref;
  NotificationAdminActions(this._ref);

  Future<void> sendBroadcast({
    required String title,
    required String message,
    required String targetAudience, // 'all', 'students', 'teachers', 'creators'
  }) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    final response = await Supabase.instance.client.from('app_broadcasts').insert({
      'admin_id': uid,
      'title': title,
      'message': message,
      'target_audience': targetAudience,
    }).select('id').single();

    await AuditLogger.log(
      action: 'send_broadcast',
      targetId: response['id'] as String,
      targetType: 'broadcast',
      details: 'Sent broadcast "$title" to $targetAudience',
    );

    _ref.invalidate(broadcastHistoryProvider);
  }
}
