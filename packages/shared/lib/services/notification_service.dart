import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification.dart';

class NotificationService {
  final SupabaseClient _client;
  NotificationService(this._client);

  Future<List<AppNotification>> getNotifications() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final data = await _client.from('notifications').select()
        .eq('user_id', uid).order('created_at', ascending: false).limit(50);
    return (data as List).map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<int> getUnreadCount() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return 0;
    final count = await _client.from('notifications')
        .select('id')
        .eq('user_id', uid).eq('is_read', false);
    return count.length;
  }

  Future<void> markAllRead() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client.from('notifications')
        .update({'is_read': true}).eq('user_id', uid).eq('is_read', false);
  }

  Future<void> markRead(String notificationId) async {
    await _client.from('notifications')
        .update({'is_read': true}).eq('id', notificationId);
  }

  Stream<List<Map<String, dynamic>>> watchUnread(String userId) {
    return _client.from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
  }
}
