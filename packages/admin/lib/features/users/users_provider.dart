import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final usersListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await Supabase.instance.client
      .from('users')
      .select(
        'id, full_name, username, email, avatar_url, role, is_active, '
        'is_verified_creator, total_points, notes_count, followers_count, '
        'following_count, current_streak, suspension_until, created_at, deleted_at, '
        'teacher_status, linkedin_url, id_card_url',
      )
      .order('created_at', ascending: false)
      .limit(500);
  return (data as List).cast<Map<String, dynamic>>();
});
