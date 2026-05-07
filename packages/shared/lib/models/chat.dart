import 'package:shared/models/user.dart';

class ChatRoom {
  final String id;
  final String studentId;
  final String teacherId;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final UserProfile? otherUser; // Populated for UI convenience

  ChatRoom({
    required this.id,
    required this.studentId,
    required this.teacherId,
    this.lastMessageText,
    this.lastMessageAt,
    required this.createdAt,
    this.otherUser,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json, {UserProfile? otherUser}) {
    return ChatRoom(
      id: json['id'],
      studentId: json['student_id'],
      teacherId: json['teacher_id'],
      lastMessageText: json['last_message_text'],
      lastMessageAt: json['last_message_at'] != null ? DateTime.parse(json['last_message_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
      otherUser: otherUser,
    );
  }

  ChatRoom copyWith({UserProfile? otherUser}) {
    return ChatRoom(
      id: id,
      studentId: studentId,
      teacherId: teacherId,
      lastMessageText: lastMessageText,
      lastMessageAt: lastMessageAt,
      createdAt: createdAt,
      otherUser: otherUser ?? this.otherUser,
    );
  }
}

class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String receiverId;
  final String content;
  final String? imageUrl;
  final bool isRead;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.imageUrl,
    required this.isRead,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      roomId: json['room_id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      content: json['content'],
      imageUrl: json['image_url'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
