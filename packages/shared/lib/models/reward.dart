class Reward {
  final String id;
  final String name;
  final String description;
  final int pointsCost;
  final String rewardType;
  final String? imageUrl;
  final int stock;
  final bool isActive;

  const Reward({
    required this.id,
    required this.name,
    required this.description,
    required this.pointsCost,
    required this.rewardType,
    this.imageUrl,
    this.stock = 999,
    this.isActive = true,
  });

  factory Reward.fromJson(Map<String, dynamic> j) => Reward(
    id: j['id'] as String,
    name: j['name'] as String,
    description: j['description'] as String,
    pointsCost: j['points_cost'] as int,
    rewardType: j['reward_type'] as String,
    imageUrl: j['image_url'] as String?,
    stock: j['stock'] as int? ?? 999,
    isActive: j['is_active'] as bool? ?? true,
  );
}

class Redemption {
  final String id;
  final String userId;
  final String rewardId;
  final int pointsSpent;
  final String status;
  final DateTime createdAt;

  const Redemption({
    required this.id,
    required this.userId,
    required this.rewardId,
    required this.pointsSpent,
    required this.status,
    required this.createdAt,
  });

  factory Redemption.fromJson(Map<String, dynamic> j) => Redemption(
    id: j['id'] as String,
    userId: j['user_id'] as String,
    rewardId: j['reward_id'] as String,
    pointsSpent: j['points_spent'] as int,
    status: j['status'] as String,
    createdAt: DateTime.parse(j['created_at'] as String),
  );
}
