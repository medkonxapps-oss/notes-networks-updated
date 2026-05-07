import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:design_system/design_system.dart';
import 'package:intl/intl.dart';
import '../../shared/utils/audit_logger.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _client = Supabase.instance.client;
  String _statusFilter = 'open';
  Map<String, dynamic>? _selected;
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      var q = _client.from('support_tickets')
          .select('*, users!user_id(id, username, full_name, avatar_url, email)');
      
      if (_statusFilter != 'all') {
        q = q.eq('status', _statusFilter);
      }

      final data = await q.order('created_at', ascending: false);
      setState(() { _tickets = (data as List).cast<Map<String, dynamic>>(); _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _updateStatus(String id, String status, {String? reply}) async {
    try {
      final updates = <String, dynamic>{'status': status, 'updated_at': DateTime.now().toIso8601String()};
      if (reply != null) updates['admin_reply'] = reply;
      await _client.from('support_tickets').update(updates).eq('id', id);

      await AuditLogger.log(
        action: status == 'resolved' ? 'resolve_ticket' : 'update_ticket',
        targetId: id,
        targetType: 'support_ticket',
        details: 'Status set to $status${reply != null ? " with reply" : ""}',
      );

      await _load();
      if (_selected?['id'] == id) setState(() => _selected = _tickets.firstWhere((t) => t['id'] == id, orElse: () => _selected!));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ticket $status'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(children: [
        // ── Left: Ticket List ──
        SizedBox(
          width: 380,
          child: Column(children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppColors.border), right: BorderSide(color: AppColors.border)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Support Tickets', style: AppText.headlineMedium.copyWith(color: AppColors.textPrimary)),
                  IconButton(icon: const Icon(Icons.refresh_rounded, size: 18), onPressed: _load, tooltip: 'Refresh'),
                ]),
                const SizedBox(height: 12),
                SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                  for (final s in ['open', 'in_progress', 'resolved', 'all'])
                    Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
                      label: Text(_label(s)), selected: _statusFilter == s,
                      onSelected: (_) { setState(() { _statusFilter = s; _selected = null; }); _load(); },
                      selectedColor: AppColors.primary, labelStyle: TextStyle(color: _statusFilter == s ? Colors.white : null, fontSize: 12),
                    )),
                ])),
              ]),
            ),

            // Ticket rows
            Expanded(child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _tickets.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.support_agent_rounded, size: 48, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text('No $_statusFilter tickets', style: AppText.bodyMedium.copyWith(color: AppColors.textMuted)),
                  ]))
                : ListView.separated(
                    itemCount: _tickets.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (ctx, i) {
                      final t = _tickets[i];
                      final isSelected = _selected?['id'] == t['id'];
                      final user = t['users'] as Map<String, dynamic>?;
                      final status = t['status'] as String? ?? 'open';
                      final sColor = _statusColor(status);
                      final dt = DateTime.tryParse(t['created_at'] as String? ?? '');

                      return InkWell(
                        onTap: () => setState(() => _selected = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          color: isSelected ? AppColors.primary.withValues(alpha: 0.06) : Colors.transparent,
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(t['subject'] as String? ?? '(no subject)',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(color: sColor.withValues(alpha: 0.1), borderRadius: AppRadius.full),
                                child: Text(status.replaceAll('_', ' '), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: sColor))),
                            ]),
                            const SizedBox(height: 4),
                            Text('@${user?['username'] ?? '?'}  ·  ${dt != null ? DateFormat('d MMM').format(dt) : ''}',
                              style: AppText.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11)),
                            if ((t['message'] as String?)?.isNotEmpty == true) ...[
                              const SizedBox(height: 4),
                              Text(t['message'] as String, style: AppText.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 12),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ]),
                        ),
                      );
                    },
                  ),
            ),
          ]),
        ),

        // ── Right: Ticket Detail ──
        Expanded(child: _selected == null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.inbox_rounded, size: 56, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text('Select a ticket to view details', style: AppText.bodyMedium.copyWith(color: AppColors.textMuted)),
            ]))
          : _TicketDetail(ticket: _selected!, onUpdate: _updateStatus),
        ),
      ]),
    );
  }

  String _label(String s) => switch (s) { 'open' => 'Open', 'in_progress' => 'In Progress', 'resolved' => 'Resolved', _ => 'All' };
  Color _statusColor(String s) => switch (s) { 'open' => AppColors.warning, 'in_progress' => AppColors.primary, 'resolved' => AppColors.success, _ => AppColors.textMuted };
}

class _TicketDetail extends StatefulWidget {
  final Map<String, dynamic> ticket;
  final Future<void> Function(String id, String status, {String? reply}) onUpdate;
  const _TicketDetail({required this.ticket, required this.onUpdate});
  @override
  State<_TicketDetail> createState() => _TicketDetailState();
}

class _TicketDetailState extends State<_TicketDetail> {
  final _replyCtrl = TextEditingController();
  bool _sending = false;

  @override
  void didUpdateWidget(_TicketDetail old) {
    super.didUpdateWidget(old);
    if (old.ticket['id'] != widget.ticket['id']) _replyCtrl.clear();
  }

  @override
  void dispose() { _replyCtrl.dispose(); super.dispose(); }

  Future<void> _send(String newStatus) async {
    setState(() => _sending = true);
    await widget.onUpdate(widget.ticket['id'] as String, newStatus, reply: _replyCtrl.text.trim().isEmpty ? null : _replyCtrl.text.trim());
    if (mounted) { _replyCtrl.clear(); setState(() => _sending = false); }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    final user = t['users'] as Map<String, dynamic>?;
    final status = t['status'] as String? ?? 'open';
    final dt = DateTime.tryParse(t['created_at'] as String? ?? '');
    final existingReply = t['admin_reply'] as String?;

    return Container(
      decoration: const BoxDecoration(border: Border(left: BorderSide(color: AppColors.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t['subject'] as String? ?? '(no subject)', style: AppText.headlineMedium.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Row(children: [
                CircleAvatar(radius: 14, backgroundColor: AppColors.primarySurface,
                  child: Text((user?['full_name'] as String? ?? 'U')[0].toUpperCase(), style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700))),
                const SizedBox(width: 8),
                Text('${user?['full_name'] ?? 'Unknown'}  ·  @${user?['username'] ?? '?'}', style: AppText.bodySmall.copyWith(color: AppColors.textMuted)),
                const SizedBox(width: 12),
                if (dt != null) Text(DateFormat('d MMM yyyy, HH:mm').format(dt.toLocal()), style: AppText.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11)),
              ]),
            ])),
            // Actions
            if (status != 'resolved') ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                label: const Text('Mark In Progress'),
                onPressed: _sending ? null : () => _send('in_progress'),
              ),
              const SizedBox(width: 8),
            ],
            FilledButton.icon(
              icon: Icon(status == 'resolved' ? Icons.refresh_rounded : Icons.check_rounded, size: 16),
              label: Text(status == 'resolved' ? 'Reopen' : 'Resolve'),
              onPressed: _sending ? null : () => _send(status == 'resolved' ? 'open' : 'resolved'),
              style: FilledButton.styleFrom(backgroundColor: status == 'resolved' ? AppColors.warning : AppColors.success),
            ),
          ]),
        ),

        // Body
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // User message
          _Bubble(label: 'User Message', text: t['message'] as String? ?? '(no message)', isAdmin: false),
          const SizedBox(height: 16),

          // Category & Priority
          if (t['category'] != null || t['priority'] != null)
            Row(children: [
              if (t['category'] != null) _Tag(label: 'Category: ${t['category']}', color: Colors.blue),
              if (t['priority'] != null) ...[const SizedBox(width: 8), _Tag(label: 'Priority: ${t['priority']}', color: AppColors.warning)],
            ]),
          const SizedBox(height: 16),

          // Existing admin reply
          if (existingReply?.isNotEmpty == true) ...[
            _Bubble(label: 'Previous Admin Reply', text: existingReply!, isAdmin: true),
            const SizedBox(height: 16),
          ],

          // Reply box
          if (status != 'resolved') ...[
            Text('Reply to User', style: AppText.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            TextField(
              controller: _replyCtrl,
              maxLines: 5,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Type your reply here...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true, fillColor: AppColors.background,
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              FilledButton.icon(
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('Send & Resolve'),
                onPressed: _sending ? null : () => _send('resolved'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.success),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('Send Reply Only'),
                onPressed: _sending ? null : () => _send(status),
              ),
            ]),
          ] else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.08), borderRadius: AppRadius.md, border: Border.all(color: AppColors.success.withValues(alpha: 0.2))),
              child: const Row(children: [
                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                SizedBox(width: 8),
                Text('This ticket has been resolved.', style: TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
        ]))),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String label, text;
  final bool isAdmin;
  const _Bubble({required this.label, required this.text, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final color = isAdmin ? AppColors.primary : AppColors.background;
    final textColor = isAdmin ? Colors.white : AppColors.textPrimary;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppText.bodySmall.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: AppRadius.md,
          border: Border.all(color: isAdmin ? Colors.transparent : AppColors.border),
        ),
        child: Text(text, style: TextStyle(fontSize: 14, color: textColor, height: 1.5)),
      ),
    ]);
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: AppRadius.full, border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  );
}
