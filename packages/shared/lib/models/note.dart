class Note {
  final String id;
  final String userId;
  final String? folderId;
  final String title;
  final String? description;
  final String subject;
  final String classLevel;
  final String board;
  final String fileType; // 'pdf' | 'image_set'
  final List<String> fileKeys;
  final String? thumbnailKey;
  final String? thumbnailUrl; // signed URL
  final List<String>? pageUrls; // signed URLs for pages
  final int pageCount;
  final int fileSizeBytes;
  final String visibility; // 'public' | 'followers'
  final String status; // 'processing'|'active'|'removed'|'pending_review'
  final List<String> tags;
  final int likesCount;
  final int savesCount;
  final int viewsCount;
  final double feedScore;
  final bool isSponsored;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  // Joined author info
  final String? authorName;
  final String? authorUsername;
  final String? authorAvatarUrl;
  final bool authorIsVerified;
  // User interaction state
  final bool isLiked;
  final bool isSaved;

  const Note({
    required this.id,
    required this.userId,
    this.folderId,
    required this.title,
    this.description,
    required this.subject,
    required this.classLevel,
    required this.board,
    required this.fileType,
    required this.fileKeys,
    this.thumbnailKey,
    this.thumbnailUrl,
    this.pageUrls,
    this.pageCount = 1,
    this.fileSizeBytes = 0,
    this.visibility = 'public',
    this.status = 'processing',
    this.tags = const [],
    this.likesCount = 0,
    this.savesCount = 0,
    this.viewsCount = 0,
    this.feedScore = 0,
    this.isSponsored = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.authorName,
    this.authorUsername,
    this.authorAvatarUrl,
    this.authorIsVerified = false,
    this.isLiked = false,
    this.isSaved = false,
  });

  factory Note.fromJson(Map<String, dynamic> j) {
    final user = j['users'] as Map<String, dynamic>?;
    return Note(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      folderId: j['folder_id'] as String?,
      title: j['title'] as String,
      description: j['description'] as String?,
      subject: j['subject'] as String,
      classLevel: j['class_level'] as String,
      board: j['board'] as String,
      fileType: j['file_type'] as String,
      fileKeys: (j['file_keys'] as List<dynamic>?)
              ?.map((e) => e.toString()).toList() ?? [],
      thumbnailKey: j['thumbnail_key'] as String?,
      thumbnailUrl: j['thumbnail_url'] as String?,
      pageUrls: (j['page_urls'] as List<dynamic>?)
              ?.map((e) => e.toString()).toList(),
      pageCount: j['page_count'] as int? ?? 1,
      fileSizeBytes: j['file_size_bytes'] as int? ?? 0,
      visibility: j['visibility'] as String? ?? 'public',
      status: j['status'] as String? ?? 'processing',
      tags: (j['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      likesCount: j['likes_count'] as int? ?? 0,
      savesCount: j['saves_count'] as int? ?? 0,
      viewsCount: j['views_count'] as int? ?? 0,
      feedScore: (j['feed_score'] as num?)?.toDouble() ?? 0,
      isSponsored: j['is_sponsored'] as bool? ?? false,
      createdAt: DateTime.parse(j['created_at'] as String),
      updatedAt: DateTime.parse(j['updated_at'] as String),
      deletedAt: j['deleted_at'] != null ? DateTime.parse(j['deleted_at'] as String) : null,
            authorName: (user?['full_name'] ?? j['full_name'] ?? j['author_name']) as String?,
      authorUsername: (user?['username'] ?? j['username'] ?? j['author_username']) as String?,
      authorAvatarUrl: (user?['avatar_url'] ?? j['avatar_url'] ?? j['author_avatar_url']) as String?,
      authorIsVerified: (user?['is_verified_creator'] ?? j['is_verified_creator'] ?? j['author_is_verified'] ?? false) as bool,
      isLiked: j['is_liked'] as bool? ?? false,
      isSaved: j['is_saved'] as bool? ?? false,
    );
  }

  Note copyWith({bool? isLiked, bool? isSaved, int? likesCount, int? savesCount,
    String? status, String? thumbnailUrl, List<String>? pageUrls}) => Note(
    id: id, userId: userId, folderId: folderId, title: title,
    description: description, subject: subject, classLevel: classLevel,
    board: board, fileType: fileType, fileKeys: fileKeys,
    thumbnailKey: thumbnailKey,
    thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    pageUrls: pageUrls ?? this.pageUrls,
    pageCount: pageCount, fileSizeBytes: fileSizeBytes,
    visibility: visibility, status: status ?? this.status,
    tags: tags,
    likesCount: likesCount ?? this.likesCount,
    savesCount: savesCount ?? this.savesCount,
    viewsCount: viewsCount, feedScore: feedScore, isSponsored: isSponsored,
    createdAt: createdAt, updatedAt: updatedAt, deletedAt: deletedAt,
    authorName: authorName, authorUsername: authorUsername,
    authorAvatarUrl: authorAvatarUrl, authorIsVerified: authorIsVerified,
    isLiked: isLiked ?? this.isLiked,
    isSaved: isSaved ?? this.isSaved,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'folder_id': folderId,
    'title': title,
    'description': description,
    'subject': subject,
    'class_level': classLevel,
    'board': board,
    'file_type': fileType,
    'file_keys': fileKeys,
    'page_count': pageCount,
    'visibility': visibility,
    'status': status,
    'tags': tags,
    'likes_count': likesCount,
    'saves_count': savesCount,
    'views_count': viewsCount,
    'created_at': createdAt.toIso8601String(),
  };
}
