class LeaderboardEntry {
  final int rank;
  final String userId;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final bool isVerified;
  final int points;
  final int notesCount;
  final int streak;

  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    this.isVerified = false,
    required this.points,
    this.notesCount = 0,
    this.streak = 0,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
    rank: j['rank'] as int? ?? 0,
    userId: j['user_id'] as String? ?? j['id'] as String,
    username: j['username'] as String,
    fullName: j['full_name'] as String,
    avatarUrl: j['avatar_url'] as String?,
    isVerified: j['is_verified_creator'] as bool? ?? false,
    points: j['total_points'] as int? ?? 0,
    notesCount: j['notes_count'] as int? ?? 0,
    streak: j['current_streak'] as int? ?? 0,
  );
}
