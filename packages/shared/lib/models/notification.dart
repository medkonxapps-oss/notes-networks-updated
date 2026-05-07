class AppNotification {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String message;
  final String? referenceId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.referenceId,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] as String,
    userId: j['user_id'] as String,
    type: j['type'] as String,
    title: j['title'] as String,
    message: j['message'] as String,
    referenceId: j['reference_id'] as String?,
    isRead: j['is_read'] as bool? ?? false,
    createdAt: DateTime.parse(j['created_at'] as String),
  );
}
