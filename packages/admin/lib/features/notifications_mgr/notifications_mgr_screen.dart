import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:design_system/design_system.dart';
import 'notifications_mgr_provider.dart';
import 'package:intl/intl.dart';

class NotificationsMgrScreen extends ConsumerStatefulWidget {
  const NotificationsMgrScreen({super.key});
  @override
  ConsumerState<NotificationsMgrScreen> createState() => _NotificationsMgrScreenState();
}

class _NotificationsMgrScreenState extends ConsumerState<NotificationsMgrScreen> {
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _audience = 'all';
  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendNotification() async {
    if (_titleCtrl.text.trim().isEmpty || _messageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter both title and message.')));
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(notificationAdminActionsProvider).sendBroadcast(
        title: _titleCtrl.text.trim(),
        message: _messageCtrl.text.trim(),
        targetAudience: _audience,
      );
      
      if (mounted) {
        _titleCtrl.clear();
        _messageCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Notification sent successfully to selected users!'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(broadcastHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Push Notifications & Broadcasts', style: AppText.headlineMedium.copyWith(color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.lg,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.campaign_rounded, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('Send Global Announcement', style: AppText.titleMedium.copyWith(color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('This will send an in-app notification to all selected users immediately.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  const SizedBox(height: 24),
                  
                  TextField(
                    controller: _titleCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'Enter notification title (e.g. New Feature Update!)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _messageCtrl,
                    maxLines: 4,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Message Body',
                      hintText: 'Enter the details of your announcement here...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  const Text('Target Audience', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _audience,
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: AppColors.textPrimary),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Users (Students, Teachers, Creators)')),
                      DropdownMenuItem(value: 'students', child: Text('Only Students')),
                      DropdownMenuItem(value: 'teachers', child: Text('Only Verified Teachers')),
                      DropdownMenuItem(value: 'creators', child: Text('Only Verified Creators')),
                    ],
                    onChanged: (v) => setState(() => _audience = v!),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: PrimaryButton(
                      label: 'Send Notification Now',
                      isLoading: _loading,
                      onPressed: _sendNotification,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Broadcast History', style: AppText.titleMedium.copyWith(color: AppColors.textPrimary)),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => ref.refresh(broadcastHistoryProvider.future),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading history: $e')),
              data: (history) {
                if (history.isEmpty) {
                  return const Center(child: Text('No broadcasts sent yet.'));
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final item = history[index];
                    final date = DateTime.parse(item['created_at']).toLocal();
                    final adminInfo = item['admin'] as Map<String, dynamic>?;
                    
                    return Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(item['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('To: ${item['target_audience']}', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(item['message'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.person_rounded, size: 14, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text('Sent by ${adminInfo?['full_name'] ?? 'Admin'}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                const Spacer(),
                                const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text(DateFormat('MMM d, yyyy • h:mm a').format(date), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
