import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/leaderboard.dart';

class LeaderboardService {
  final SupabaseClient _client;
  LeaderboardService(this._client);

  Future<List<LeaderboardEntry>> getLeaderboard({
    required String period, // 'weekly'|'monthly'|'all_time'
    int limit = 50,
  }) async {
    final data = await _client.from('users')
        .select('id, username, full_name, avatar_url, is_verified_creator, total_points, notes_count, current_streak')
        .eq('is_active', true)
        .order('total_points', ascending: false)
        .limit(limit);
    return (data as List).asMap().entries.map((entry) {
      final json = entry.value as Map<String, dynamic>;
      return LeaderboardEntry.fromJson({...json, 'rank': entry.key + 1, 'user_id': json['id']});
    }).toList();
  }
}
