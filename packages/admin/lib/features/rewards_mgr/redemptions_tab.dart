import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RedemptionsTab extends StatefulWidget {
  const RedemptionsTab({super.key});

  @override
  State<RedemptionsTab> createState() => _RedemptionsTabState();
}

class _RedemptionsTabState extends State<RedemptionsTab> {
  final _client = Supabase.instance.client;

  Future<void> _updateStatus(String id, String status) async {
    final adminId = _client.auth.currentUser?.id;

    // Get the redemption record first
    final record = await _client
        .from('redemptions')
        .select('user_id, points_spent, reward_id, rewards_catalog!reward_id(name)')
        .eq('id', id)
        .maybeSingle();

    await _client.from('redemptions').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
      if (status == 'delivered') 'delivered_at': DateTime.now().toIso8601String(),
    }).eq('id', id);

    if (record != null) {
      final userId = record['user_id'] as String;
      final pts = record['points_spent'] as int? ?? 0;
      final rewardName = (record['rewards_catalog'] as Map?)?['name'] as String? ?? 'Reward';

      // Notify the user about status change
      String notifTitle, notifMsg;
      switch (status) {
        case 'dispatched':
          notifTitle = '📦 Reward Dispatched!';
          notifMsg = 'Your reward "$rewardName" has been dispatched. Check your email for details.';
          break;
        case 'delivered':
          notifTitle = '🎉 Reward Delivered!';
          notifMsg = 'Your reward "$rewardName" has been marked as delivered. Enjoy!';
          break;
        case 'cancelled':
          // Refund points to user
          await _client.from('users').update({
            'total_points': await _getPoints(userId) + pts,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', userId);
          // Log refund to ledger
          await _client.from('points_ledger').insert({
            'user_id': userId,
            'event_type': 'admin_grant',
            'points': pts,
            'reference_id': id,
          });
          notifTitle = '↩️ Redemption Cancelled';
          notifMsg = 'Your redemption for "$rewardName" was cancelled. $pts points have been refunded.';
          break;
        default:
          notifTitle = 'Reward Status Update';
          notifMsg = 'Your reward status has been updated to: $status';
      }

      await _client.from('notifications').insert({
        'user_id': userId,
        'type': 'reward',
        'title': notifTitle,
        'message': notifMsg,
        'reference_id': id,
      }).catchError((_) {});

      // Audit log
      if (adminId != null) {
        await _client.rpc('log_admin_action', params: {
          'p_admin_id': adminId,
          'p_action': 'update_redemption_status',
          'p_target_id': id,
          'p_target_type': 'redemption',
          'p_details': 'Status set to $status for reward "$rewardName"${status == 'cancelled' ? ', $pts pts refunded' : ''}',
        }).catchError((_) {});
      }
    }
    setState(() {});
  }

  Future<int> _getPoints(String userId) async {
    final data = await _client.from('users').select('total_points').eq('id', userId).maybeSingle();
    return (data?['total_points'] as int?) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _client.from('redemptions')
          .select('*, users(full_name, username, email, phone, institution_name), rewards_catalog(name)')
          .order('created_at', ascending: false),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final items = snap.data as List;

        if (items.isEmpty) {
          return const Center(child: EmptyState(icon: Icons.history_rounded, title: 'No redemptions yet', subtitle: ''));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final user = item['users'];
            final reward = item['rewards_catalog'];
            final status = item['status'] as String;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                title: Text('${user['full_name']} redeemed ${reward['name']}'),
                subtitle: Text('Spent ${item['points_spent']} pts · ${item['created_at'].toString().substring(0, 16)}'),
                leading: _StatusBadge(status: status),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) => _updateStatus(item['id'], v),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'pending', child: Text('Pending')),
                    const PopupMenuItem(value: 'dispatched', child: Text('Dispatched')),
                    const PopupMenuItem(value: 'delivered', child: Text('Delivered')),
                    const PopupMenuItem(value: 'cancelled', child: Text('Cancelled')),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text('CONTACT DETAILS:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                        const SizedBox(height: 8),
                        _InfoRow(label: 'Email', value: user['email'] ?? 'N/A', icon: Icons.email_outlined),
                        _InfoRow(label: 'Phone', value: user['phone'] ?? 'N/A', icon: Icons.phone_outlined),
                        _InfoRow(label: 'School/College', value: user['institution_name'] ?? 'N/A', icon: Icons.school_outlined),
                        const SizedBox(height: 12),
                        const Text('DELIVERY INFO:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                        const SizedBox(height: 4),
                        Text(item['delivery_info']?.toString() ?? 'No delivery info provided.', style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _InfoRow({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    Color color = Colors.grey;
    switch (status) {
      case 'pending': color = Colors.orange; break;
      case 'dispatched': color = Colors.blue; break;
      case 'delivered': color = Colors.green; break;
      case 'cancelled': color = Colors.red; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
