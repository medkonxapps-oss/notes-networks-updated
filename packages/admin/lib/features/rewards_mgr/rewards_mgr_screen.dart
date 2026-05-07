import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'redemptions_tab.dart';

class RewardsMgrScreen extends StatefulWidget {
  const RewardsMgrScreen({super.key});

  @override
  State<RewardsMgrScreen> createState() => _RewardsMgrScreenState();
}

class _RewardsMgrScreenState extends State<RewardsMgrScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rewards Management', style: AppText.headlineMedium),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Catalog'),
            Tab(text: 'User Claims'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _CatalogTab(),
          RedemptionsTab(),
        ],
      ),
    );
  }
}

class _CatalogTab extends StatefulWidget {
  const _CatalogTab();
  @override
  State<_CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<_CatalogTab> {
  void _showRewardDialog([Map<String, dynamic>? reward]) {
    showDialog(
      context: context,
      builder: (context) => _RewardEditDialog(reward: reward),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FutureBuilder(
        future: Supabase.instance.client.from('rewards_catalog').select('*').eq('is_active', true).order('created_at', ascending: false),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final rewards = snap.data as List;

          if (rewards.isEmpty) {
            return const Center(child: EmptyState(icon: Icons.redeem_rounded, title: 'No rewards found', subtitle: ''));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.8,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
            ),
            itemCount: rewards.length,
            itemBuilder: (context, index) {
              final reward = rewards[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        color: AppColors.primarySurface,
                        width: double.infinity,
                        child: const Icon(Icons.redeem_rounded, size: 64, color: AppColors.primary),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(reward['name'], style: AppText.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('${reward['points_cost']} Points', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                          const SizedBox(height: 8),
                          Text('Stock: ${reward['stock']}', style: AppText.bodySmall),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => _showRewardDialog(reward),
                              child: const Text('Edit Reward'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRewardDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add New Reward'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}

class _RewardEditDialog extends StatefulWidget {
  final Map<String, dynamic>? reward;
  const _RewardEditDialog({this.reward});

  @override
  State<_RewardEditDialog> createState() => _RewardEditDialogState();
}

class _RewardEditDialogState extends State<_RewardEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _pointsCtrl;
  late TextEditingController _stockCtrl;
  String _rewardType = 'voucher';
  bool _isLoading = false;

  static const List<String> _validTypes = ['voucher', 'coupon', 'courier'];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.reward?['name'] ?? '');
    _descCtrl = TextEditingController(text: widget.reward?['description'] ?? '');
    _pointsCtrl = TextEditingController(text: widget.reward?['points_cost']?.toString() ?? '100');
    _stockCtrl = TextEditingController(text: widget.reward?['stock']?.toString() ?? '999');
    final rawType = widget.reward?['reward_type'] ?? 'voucher';
    _rewardType = _validTypes.contains(rawType) ? rawType : _validTypes.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _descCtrl.dispose(); _pointsCtrl.dispose(); _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final client = Supabase.instance.client;
      final data = {
        'name': _nameCtrl.text,
        'description': _descCtrl.text,
        'points_cost': int.parse(_pointsCtrl.text),
        'stock': int.parse(_stockCtrl.text),
        'reward_type': _rewardType,
        'is_active': true,
      };

      if (widget.reward == null) {
        await client.from('rewards_catalog').insert(data);
      } else {
        await client.from('rewards_catalog').update(data).eq('id', widget.reward!['id']);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.from('rewards_catalog').update({'is_active': false}).eq('id', widget.reward!['id']);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.reward != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Reward' : 'New Reward'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name'), validator: (v) => v!.isEmpty ? 'Required' : null),
              TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
              TextFormField(controller: _pointsCtrl, decoration: const InputDecoration(labelText: 'Points Cost'), keyboardType: TextInputType.number),
              TextFormField(controller: _stockCtrl, decoration: const InputDecoration(labelText: 'Stock'), keyboardType: TextInputType.number),
              DropdownButtonFormField<String>(
                initialValue: _rewardType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: _validTypes.map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(t[0].toUpperCase() + t.substring(1).replaceAll('_', ' ')),
                )).toList(),
                onChanged: (v) => setState(() => _rewardType = v!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (isEdit) TextButton(onPressed: _isLoading ? null : _delete, child: const Text('Delete', style: TextStyle(color: Colors.red))),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _isLoading ? null : _save, child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save')),
      ],
    );
  }
}
