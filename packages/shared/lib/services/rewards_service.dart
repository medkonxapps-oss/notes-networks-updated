import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reward.dart';

class RewardsService {
  final SupabaseClient _client;
  RewardsService(this._client);

  // ── Catalog ───────────────────────────────────────────────────────────────

  Future<List<Reward>> getCatalog() async {
    final data = await _client
        .from('rewards_catalog')
        .select()
        .eq('is_active', true)
        .order('points_cost');
    return (data as List).map((e) => Reward.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Redemptions ───────────────────────────────────────────────────────────

  Future<List<Redemption>> getMyRedemptions() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final data = await _client
        .from('redemptions')
        .select('*, rewards_catalog!reward_id(name, reward_type, image_url)')
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Redemption.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Atomic redeem via DB function — prevents race conditions and double-spend.
  /// Returns remaining points on success, throws on failure.
  Future<int> redeem(String rewardId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not logged in');

    final result = await _client.rpc('redeem_reward', params: {
      'p_reward_id': rewardId,
      'p_user_id': uid,
    });

    final map = result as Map<String, dynamic>;

    if (map['success'] != true) {
      throw Exception(map['error'] as String? ?? 'Redemption failed');
    }

    return map['remaining_points'] as int? ?? 0;
  }

  // ── Streak Info ───────────────────────────────────────────────────────────

  /// Get the current user's streak and points summary.
  Future<StreakInfo> getStreakInfo() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const StreakInfo();

    final data = await _client
        .from('users')
        .select('current_streak, longest_streak, total_points, last_upload_date, notes_count')
        .eq('id', uid)
        .single();

    return StreakInfo.fromJson(data);
  }

  /// Get user's earned badges.
  Future<List<UserBadge>> getMyBadges() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];

    final data = await _client
        .from('user_badges')
        .select('earned_at, badges!badge_id(name, description, badge_type, icon_name, milestone_value)')
        .eq('user_id', uid)
        .order('earned_at', ascending: false);

    return (data as List).map((e) => UserBadge.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Get the user's points history from the ledger.
  Future<List<PointsEvent>> getPointsHistory() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];

    final data = await _client
        .from('points_ledger')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(50);

    return (data as List).map((e) => PointsEvent.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Admin Methods ─────────────────────────────────────────────────────────

  Future<void> createReward({
    required String name,
    required String description,
    required int pointsCost,
    required String rewardType,
    String? imageUrl,
    int stock = 999,
  }) async {
    await _client.from('rewards_catalog').insert({
      'name': name,
      'description': description,
      'points_cost': pointsCost,
      'reward_type': rewardType,
      'image_url': imageUrl,
      'stock': stock,
      'is_active': true,
    });
  }

  Future<void> updateReward(String id, Map<String, dynamic> updates) async {
    await _client.from('rewards_catalog').update(updates).eq('id', id);
  }

  Future<void> deleteReward(String id) async {
    await _client.from('rewards_catalog').update({'is_active': false}).eq('id', id);
  }
}

// ── Models ────────────────────────────────────────────────────────────────────

class StreakInfo {
  final int currentStreak;
  final int longestStreak;
  final int totalPoints;
  final int notesCount;
  final DateTime? lastUploadDate;

  const StreakInfo({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalPoints = 0,
    this.notesCount = 0,
    this.lastUploadDate,
  });

  bool get uploadedToday {
    if (lastUploadDate == null) return false;
    final today = DateTime.now();
    return lastUploadDate!.year == today.year &&
        lastUploadDate!.month == today.month &&
        lastUploadDate!.day == today.day;
  }

  factory StreakInfo.fromJson(Map<String, dynamic> j) => StreakInfo(
    currentStreak: j['current_streak'] as int? ?? 0,
    longestStreak: j['longest_streak'] as int? ?? 0,
    totalPoints: j['total_points'] as int? ?? 0,
    notesCount: j['notes_count'] as int? ?? 0,
    lastUploadDate: j['last_upload_date'] != null
        ? DateTime.tryParse(j['last_upload_date'] as String)
        : null,
  );
}

class UserBadge {
  final String name;
  final String description;
  final String badgeType;
  final String? iconName;
  final int? milestoneValue;
  final DateTime earnedAt;

  const UserBadge({
    required this.name,
    required this.description,
    required this.badgeType,
    this.iconName,
    this.milestoneValue,
    required this.earnedAt,
  });

  factory UserBadge.fromJson(Map<String, dynamic> j) {
    final badge = j['badges'] as Map<String, dynamic>? ?? {};
    return UserBadge(
      name: badge['name'] as String? ?? '',
      description: badge['description'] as String? ?? '',
      badgeType: badge['badge_type'] as String? ?? '',
      iconName: badge['icon_name'] as String?,
      milestoneValue: badge['milestone_value'] as int?,
      earnedAt: DateTime.parse(j['earned_at'] as String),
    );
  }
}

class PointsEvent {
  final String eventType;
  final int points;
  final DateTime createdAt;
  final String? referenceId;

  const PointsEvent({
    required this.eventType,
    required this.points,
    required this.createdAt,
    this.referenceId,
  });

  factory PointsEvent.fromJson(Map<String, dynamic> j) => PointsEvent(
    eventType: j['event_type'] as String,
    points: j['points'] as int,
    createdAt: DateTime.parse(j['created_at'] as String),
    referenceId: j['reference_id'] as String?,
  );

  String get label => switch (eventType) {
    'upload'               => '📤 Note Upload',
    'first_upload'         => '🎉 First Upload Bonus',
    'like_received'        => '❤️ Like Received',
    'save_received'        => '🔖 Note Saved',
    'download_received'    => '⬇️ Note Downloaded',
    'streak_bonus'         => '🔥 Streak Bonus',
    'verification_bonus'   => '✅ Verification Bonus',
    'admin_grant'          => '🎁 Admin Grant',
    'penalty'              => '⚠️ Penalty',
    'redemption'           => '🛍️ Reward Redeemed',
    _                      => eventType,
  };

  bool get isPositive => points > 0;
}
