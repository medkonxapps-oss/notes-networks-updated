import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:design_system/design_system.dart';
import 'package:intl/intl.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});
  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final _client = Supabase.instance.client;
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _logs = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 0;
  static const _pageSize = 50;

  String _actionFilter = 'all';
  String _searchQuery = '';

  final _actions = {
    'all': 'All Actions',
    'approve_note': 'Approve Note',
    'reject_note': 'Reject Note',
    'suspend_user': 'Suspend User',
    'unsuspend_user': 'Unsuspend User',
    'verify_creator': 'Verify Creator',
    'delete_note': 'Delete Note',
    'resolve_report': 'Resolve Report',
    'send_broadcast': 'Broadcast',
    'update_config': 'Config Change',
  };

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200 && !_loading && _hasMore) {
        _fetchMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs({bool reset = false}) async {
    if (_loading) return;
    if (reset) {
      setState(() { _page = 0; _logs = []; _hasMore = true; });
    }
    setState(() => _loading = true);
    try {
      var query = _client
          .from('admin_audit_log')
          .select('*, admin:admin_id(full_name, username)');

      if (_actionFilter != 'all') {
        query = query.eq('action', _actionFilter);
      }

      final data = await query
          .order('created_at', ascending: false)
          .range(_page * _pageSize, (_page + 1) * _pageSize - 1);
      final rows = (data as List).cast<Map<String, dynamic>>();

      setState(() {
        _logs = reset ? rows : [..._logs, ...rows];
        _hasMore = rows.length == _pageSize;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchMore() async {
    _page++;
    await _fetchLogs();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_searchQuery.isEmpty) return _logs;
    final q = _searchQuery.toLowerCase();
    return _logs.where((l) {
      final admin = l['admin'] as Map<String, dynamic>?;
      return (l['action'] as String? ?? '').toLowerCase().contains(q) ||
          (l['target_id'] as String? ?? '').contains(q) ||
          (admin?['username'] as String? ?? '').contains(q) ||
          (l['details'] as String? ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Audit Log', style: AppText.headlineMedium.copyWith(color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => _fetchLogs(reset: true)),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(children: [
              Expanded(child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by admin, target, action...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true, fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _actionFilter,
                items: _actions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (v) { if (v != null) { setState(() => _actionFilter = v); _fetchLogs(reset: true); } },
                borderRadius: BorderRadius.circular(10),
                underline: const SizedBox(),
              ),
              const SizedBox(width: 12),
              Text('${filtered.length} entries', style: AppText.bodySmall.copyWith(color: AppColors.textMuted)),
            ]),
          ),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            color: AppColors.background,
            child: Row(children: [
              Expanded(flex: 2, child: Text('Timestamp', style: _hdr)),
              Expanded(flex: 2, child: Text('Admin', style: _hdr)),
              Expanded(flex: 2, child: Text('Action', style: _hdr)),
              Expanded(flex: 2, child: Text('Target ID', style: _hdr)),
              Expanded(flex: 3, child: Text('Details', style: _hdr)),
            ]),
          ),
          const Divider(height: 1),

          // Log rows
          Expanded(
            child: filtered.isEmpty && !_loading
                ? Center(child: Text('No audit entries found', style: AppText.bodyMedium.copyWith(color: AppColors.textMuted)))
                : ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: filtered.length + (_loading ? 1 : 0),
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      if (i >= filtered.length) {
                        return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppColors.primary)));
                      }
                      final log = filtered[i];
                      final admin = log['admin'] as Map<String, dynamic>?;
                      final action = log['action'] as String? ?? '—';
                      final dt = DateTime.tryParse(log['created_at'] as String? ?? '') ?? DateTime.now();
                      final color = _actionColor(action);
                      final targetId = log['target_id'] as String? ?? '—';

                      return InkWell(
                        onTap: () => _showDetail(ctx, log),
                        borderRadius: AppRadius.sm,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(children: [
                            Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(DateFormat('dd MMM, HH:mm').format(dt.toLocal()), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text(DateFormat('yyyy').format(dt.toLocal()), style: AppText.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 10)),
                            ])),
                            Expanded(flex: 2, child: Row(children: [
                              Container(width: 26, height: 26, decoration: const BoxDecoration(color: AppColors.primarySurface, shape: BoxShape.circle),
                                child: Center(child: Text((admin?['username'] as String? ?? '?')[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)))),
                              const SizedBox(width: 8),
                              Expanded(child: Text('@${admin?['username'] ?? '?'}', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                            ])),
                            Expanded(flex: 2, child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: AppRadius.full),
                              child: Text(action.replaceAll('_', ' '), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color), overflow: TextOverflow.ellipsis),
                            )),
                            Expanded(flex: 2, child: GestureDetector(
                              onTap: () { Clipboard.setData(ClipboardData(text: targetId)); ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('ID copied'), duration: Duration(seconds: 1))); },
                              child: Text(targetId.length > 12 ? '${targetId.substring(0, 12)}…' : targetId,
                                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.blue, decoration: TextDecoration.underline)),
                            )),
                            Expanded(flex: 3, child: Text(
                              log['details'] as String? ?? '—',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            )),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> log) {
    final admin = log['admin'] as Map<String, dynamic>?;
    final dt = DateTime.tryParse(log['created_at'] as String? ?? '') ?? DateTime.now();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(log['action'] as String? ?? 'Audit Entry', style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _detail('Admin', '@${admin?['username'] ?? '?'} — ${admin?['full_name'] ?? ''}'),
          _detail('Time', DateFormat('dd MMM yyyy, HH:mm:ss').format(dt.toLocal())),
          _detail('Target ID', log['target_id'] as String? ?? '—'),
          _detail('Details', log['details'] as String? ?? '—'),
          if (log['ip_address'] != null) _detail('IP', log['ip_address'] as String),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _detail(String key, String val) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: RichText(text: TextSpan(style: const TextStyle(fontSize: 13, color: AppColors.textPrimary), children: [
      TextSpan(text: '$key: ', style: const TextStyle(fontWeight: FontWeight.w700)),
      TextSpan(text: val),
    ])),
  );

  TextStyle get _hdr => AppText.bodySmall.copyWith(fontWeight: FontWeight.w700, color: AppColors.textMuted, fontSize: 11);

  Color _actionColor(String a) => switch (a) {
    'approve_note' || 'verify_creator' || 'unsuspend_user' => AppColors.success,
    'reject_note' || 'suspend_user' || 'delete_note' => AppColors.danger,
    'send_broadcast' => AppColors.follow,
    'update_config' => AppColors.warning,
    _ => AppColors.primary,
  };
}
