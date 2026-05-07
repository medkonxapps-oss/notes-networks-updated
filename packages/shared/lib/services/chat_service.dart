import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat.dart';
import '../models/user.dart';

class ChatService {
  final SupabaseClient _client;
  ChatService(this._client);

  // ── Rooms ───────────────────────────────────────────────────────────
  final Map<String, UserProfile> _userCache = {};

  Stream<List<ChatRoom>> getChatRoomsStream() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return Stream.value([]);

    return _client
        .from('chat_rooms')
        .stream(primaryKey: ['id'])
        .order('last_message_at', ascending: false)
        .asyncMap((data) async {
          final List<ChatRoom> rooms = [];
          
          // Collect all unique "other user" IDs that aren't in cache
          final otherUserIds = data
              .map((row) => row['student_id'] == uid ? row['teacher_id'] : row['student_id'] as String)
              .where((id) => !_userCache.containsKey(id))
              .toSet()
              .toList();

          // Fetch missing user profiles in one batch
          if (otherUserIds.isNotEmpty) {
            final usersRes = await _client.from('users').select().inFilter('id', otherUserIds);
            for (final userRow in usersRes) {
              final user = UserProfile.fromJson(userRow);
              _userCache[user.id] = user;
            }
          }

          for (final row in data) {
            final otherId = row['student_id'] == uid ? row['teacher_id'] : row['student_id'];
            final otherUser = _userCache[otherId];
            if (otherUser != null) {
              rooms.add(ChatRoom.fromJson(row, otherUser: otherUser));
            }
          }
          return rooms;
        });
  }

  Future<ChatRoom> createOrGetRoom(String teacherId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    // Check if room already exists
    final existing = await _client
        .from('chat_rooms')
        .select()
        .eq('student_id', uid)
        .eq('teacher_id', teacherId)
        .maybeSingle();

    if (existing != null) {
      return ChatRoom.fromJson(existing);
    }

    // Create new room
    final data = await _client.from('chat_rooms').insert({
      'student_id': uid,
      'teacher_id': teacherId,
    }).select().single();

    return ChatRoom.fromJson(data);
  }

  // ── Messages ────────────────────────────────────────────────────────
  Stream<List<ChatMessage>> getMessagesStream(String roomId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: true)
        .map((data) => data.map((e) => ChatMessage.fromJson(e)).toList());
  }

  Future<void> sendMessage(String roomId, String receiverId, String content, {String? imageUrl}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    await _client.from('messages').insert({
      'room_id': roomId,
      'sender_id': uid,
      'receiver_id': receiverId,
      'content': content,
      if (imageUrl != null) 'image_url': imageUrl,
    });
  }

  Future<String> uploadChatImage(String roomId, List<int> bytes, String extension) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
    final key = '$roomId/$fileName';

    await _client.storage.from('chat-media').uploadBinary(
      key, 
      Uint8List.fromList(bytes),
      fileOptions: FileOptions(contentType: 'image/$extension', upsert: true),
    );
    
    return _client.storage.from('chat-media').getPublicUrl(key);
  }

  Future<void> updateMessage(String messageId, String content) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    await _client.from('messages').update({
      'content': content,
    }).eq('id', messageId).eq('sender_id', uid);
  }

  Future<void> deleteMessage(String messageId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    await _client.from('messages').delete().eq('id', messageId).eq('sender_id', uid);
  }

  Future<void> markAsRead(String roomId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    await _client
        .from('messages')
        .update({'is_read': true})
        .eq('room_id', roomId)
        .eq('receiver_id', uid);
  }
}
