class ForumQuestion {
  final String id;
  final String userId;
  final String title;
  final String content;
  final String subject;
  final int viewsCount;
  final int answersCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isClosed;
  final String? authorName;
  final String? authorAvatarUrl;
  final bool authorIsVerified;

  ForumQuestion({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.subject,
    this.viewsCount = 0,
    this.answersCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isClosed = false,
    this.authorName,
    this.authorAvatarUrl,
    this.authorIsVerified = false,
  });

  factory ForumQuestion.fromJson(Map<String, dynamic> j) {
    final user = j['users'] as Map<String, dynamic>?;
    return ForumQuestion(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      title: j['title'] as String,
      content: j['content'] as String,
      subject: j['subject'] as String,
      viewsCount: j['views_count'] as int? ?? 0,
      answersCount: j['answers_count'] as int? ?? 0,
      createdAt: DateTime.parse(j['created_at'] as String),
      updatedAt: DateTime.parse(j['updated_at'] as String),
      isClosed: j['is_closed'] as bool? ?? false,
      authorName: (user?['full_name'] ?? j['full_name'] ?? j['author_name']) as String?,
      authorAvatarUrl: (user?['avatar_url'] ?? j['avatar_url'] ?? j['author_avatar_url']) as String?,
      authorIsVerified: (user?['is_verified_creator'] ?? j['is_verified_creator'] ?? j['author_is_verified'] ?? false) as bool,
    );
  }
}

class ForumAnswer {
  final String id;
  final String questionId;
  final String userId;
  final String? parentId;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? authorName;
  final String? authorAvatarUrl;
  final bool authorIsVerified;

  ForumAnswer({
    required this.id,
    required this.questionId,
    required this.userId,
    this.parentId,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.authorName,
    this.authorAvatarUrl,
    this.authorIsVerified = false,
  });

  factory ForumAnswer.fromJson(Map<String, dynamic> j) {
    final user = j['users'] as Map<String, dynamic>?;
    return ForumAnswer(
      id: j['id'] as String,
      questionId: j['question_id'] as String,
      userId: j['user_id'] as String,
      parentId: j['parent_id'] as String?,
      content: j['content'] as String,
      createdAt: DateTime.parse(j['created_at'] as String),
      updatedAt: DateTime.parse(j['updated_at'] as String),
      authorName: (user?['full_name'] ?? j['full_name'] ?? j['author_name']) as String?,
      authorAvatarUrl: (user?['avatar_url'] ?? j['avatar_url'] ?? j['author_avatar_url']) as String?,
      authorIsVerified: (user?['is_verified_creator'] ?? j['is_verified_creator'] ?? j['author_is_verified'] ?? false) as bool,
    );
  }
}
