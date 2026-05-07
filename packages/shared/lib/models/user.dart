class UserProfile {
  final String id;
  final String username;
  final String fullName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String? bio;
  final String? city;
  final String? institutionName;
  final String board;
  final String classLevel;
  final List<String> subjects;
  final String role;
  final bool isVerifiedCreator;
  final bool isActive;
  final DateTime? suspensionUntil;
  final int totalPoints;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastUploadDate;
  final int followersCount;
  final int followingCount;
  final int notesCount;
  final String? fcmToken;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  // Teacher fields
  final String? linkedinUrl;
  final String? idCardUrl;
  final String? teacherStatus;

  const UserProfile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.bio,
    this.city,
    this.institutionName,
    required this.board,
    required this.classLevel,
    this.subjects = const [],
    this.role = 'student',
    this.isVerifiedCreator = false,
    this.isActive = true,
    this.suspensionUntil,
    this.totalPoints = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastUploadDate,
    this.followersCount = 0,
    this.followingCount = 0,
    this.notesCount = 0,
    this.fcmToken,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.linkedinUrl,
    this.idCardUrl,
    this.teacherStatus,
  });

  bool get isAdmin => role == 'admin' || role == 'moderator';
  bool get isCreator => notesCount > 0 || role == 'creator';
  bool get isTeacher => role == 'teacher';
  bool get isSuspended =>
      suspensionUntil != null && suspensionUntil!.isAfter(DateTime.now());

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    id: j['id'] as String,
    username: j['username'] as String,
    fullName: (j['full_name'] ?? j['author_name'] ?? '') as String,
    email: j['email'] as String? ?? '',
    phone: j['phone'] as String?,
    avatarUrl: (j['avatar_url'] ?? j['author_avatar_url']) as String?,
    bio: j['bio'] as String?,
    city: j['city'] as String?,
    institutionName: j['institution_name'] as String?,
    board: j['board'] as String? ?? '',
    classLevel: j['class_level'] as String? ?? '',
    subjects: (j['subjects'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [],
    role: j['role'] as String? ?? 'student',
    isVerifiedCreator: (j['is_verified_creator'] ?? j['author_is_verified'] ?? false) as bool,
    isActive: j['is_active'] as bool? ?? true,
    suspensionUntil: j['suspension_until'] != null
        ? DateTime.parse(j['suspension_until'] as String)
        : null,
    totalPoints: j['total_points'] as int? ?? 0,
    currentStreak: j['current_streak'] as int? ?? 0,
    longestStreak: j['longest_streak'] as int? ?? 0,
    lastUploadDate: j['last_upload_date'] != null
        ? DateTime.parse(j['last_upload_date'] as String)
        : null,
    followersCount: j['followers_count'] as int? ?? 0,
    followingCount: j['following_count'] as int? ?? 0,
    notesCount: j['notes_count'] as int? ?? 0,
    fcmToken: j['fcm_token'] as String?,
    createdAt: DateTime.parse(j['created_at'] as String),
    updatedAt: DateTime.parse(j['updated_at'] as String),
    deletedAt: j['deleted_at'] != null
        ? DateTime.parse(j['deleted_at'] as String)
        : null,
    linkedinUrl: j['linkedin_url'] as String?,
    idCardUrl: j['id_card_url'] as String?,
    teacherStatus: j['teacher_status'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'username': username, 'full_name': fullName,
    'email': email, 'phone': phone, 'avatar_url': avatarUrl,
    'bio': bio, 'city': city, 'institution_name': institutionName,
    'board': board, 'class_level': classLevel,
    'subjects': subjects, 'role': role,
    'is_verified_creator': isVerifiedCreator,
    'total_points': totalPoints, 'current_streak': currentStreak,
    'linkedin_url': linkedinUrl, 'id_card_url': idCardUrl,
    'teacher_status': teacherStatus,
  };

  UserProfile copyWith({
    String? username, String? fullName, String? bio, String? city,
    String? institutionName,
    String? board, String? classLevel, List<String>? subjects,
    String? avatarUrl, String? fcmToken, int? totalPoints,
    int? currentStreak, int? followersCount, int? followingCount, int? notesCount,
  }) => UserProfile(
    id: id, email: email, createdAt: createdAt, updatedAt: DateTime.now(),
    username: username ?? this.username,
    fullName: fullName ?? this.fullName,
    phone: phone, bio: bio ?? this.bio, city: city ?? this.city,
    institutionName: institutionName ?? this.institutionName,
    board: board ?? this.board, classLevel: classLevel ?? this.classLevel,
    subjects: subjects ?? this.subjects, role: role,
    isVerifiedCreator: isVerifiedCreator, isActive: isActive,
    suspensionUntil: suspensionUntil,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    totalPoints: totalPoints ?? this.totalPoints,
    currentStreak: currentStreak ?? this.currentStreak,
    longestStreak: longestStreak, lastUploadDate: lastUploadDate,
    followersCount: followersCount ?? this.followersCount,
    followingCount: followingCount ?? this.followingCount,
    notesCount: notesCount ?? this.notesCount,
    fcmToken: fcmToken ?? this.fcmToken,
    linkedinUrl: linkedinUrl,
    idCardUrl: idCardUrl,
    teacherStatus: teacherStatus,
  );
}
