import { supabase } from '../config/supabase';
import { redis } from '../config/redis';

export async function recomputeLeaderboard() {
  console.log('🏆 Recomputing leaderboard...');
  try {
    // Get top 100 users by total_points
    const { data: users } = await supabase
      .from('users')
      .select('id, username, full_name, total_points, notes_count, current_streak')
      .eq('is_active', true)
      .order('total_points', { ascending: false })
      .limit(100);

    if (!users) return;

    // Store in Redis sorted set (score = total_points)
    const pipeline = redis.pipeline();
    pipeline.del('leaderboard:alltime');
    for (const user of users) {
      pipeline.zadd('leaderboard:alltime', user.total_points, JSON.stringify({
        id: user.id,
        username: user.username,
        fullName: user.full_name,
        points: user.total_points,
        notesCount: user.notes_count,
        streak: user.current_streak,
      }));
    }
    pipeline.expire('leaderboard:alltime', 3600); // 1h TTL
    await pipeline.exec();

    // Refresh feed scores in DB
    await supabase.rpc('refresh_feed_scores');

    console.log(`✅ Leaderboard recomputed: ${users.length} users`);
  } catch (error) {
    console.error('❌ Leaderboard recomputation failed:', error);
  }
}
