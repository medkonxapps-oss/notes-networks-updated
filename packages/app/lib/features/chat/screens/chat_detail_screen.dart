import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';
import 'package:shared/shared.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:app/shared/utils/error_utils.dart';
import '../../../shared/providers/providers.dart';
import 'package:intl/intl.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final String roomId;
  final UserProfile otherUser;

  const ChatDetailScreen({
    super.key,
    required this.roomId,
    required this.otherUser,
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      ref.read(chatServiceProvider).markAsRead(widget.roomId);
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send({String? imageUrl}) async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty && imageUrl == null) return;

    final editingId = _editingMessageId;
    if (editingId != null) {
      _msgCtrl.clear();
      setState(() {
        _isSending = true;
        _editingMessageId = null;
      });
      try {
        await ref.read(chatServiceProvider).updateMessage(editingId, text);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e))));
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
      return;
    }

    if (imageUrl == null) _msgCtrl.clear();
    setState(() => _isSending = true);

    try {
      await ref.read(chatServiceProvider).sendMessage(
        widget.roomId,
        widget.otherUser.id,
        imageUrl != null ? 'Sent an image' : text,
        imageUrl: imageUrl,
      );
      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    setState(() => _isSending = true);
    try {
      final bytes = await image.readAsBytes();
      final ext = image.path.split('.').last;
      final url = await ref.read(chatServiceProvider).uploadChatImage(widget.roomId, bytes, ext);
      _send(imageUrl: url);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e))));
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.roomId));
    final myId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: InkWell(
          onTap: () => context.push('/profile/${widget.otherUser.id}'),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              children: [
                AppAvatar(imageUrl: widget.otherUser.avatarUrl, name: widget.otherUser.fullName, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.otherUser.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      Text(widget.otherUser.role.toUpperCase(), style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(getFriendlyErrorMessage(e))),
              data: (messages) {
                // Mark as read when new messages are received from other user
                if (messages.isNotEmpty && messages.last.senderId == widget.otherUser.id && !messages.last.isRead) {
                   Future.microtask(() => ref.read(chatServiceProvider).markAsRead(widget.roomId));
                }

                final reversedMessages = messages.reversed.toList();
                return ListView.builder(
                  controller: _scrollCtrl,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: reversedMessages.length,
                  itemBuilder: (ctx, i) {
                    final msg = reversedMessages[i];
                    final isMyMsg = msg.senderId == myId;

                    return _MessageBubble(
                      message: msg, 
                      isMe: isMyMsg,
                      onLongPress: isMyMsg ? () => _showMessageMenu(msg) : null,
                    );
                  },
                );
              },
            ),
          ),
          if (_isSending)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(height: 2, child: LinearProgressIndicator(backgroundColor: Colors.transparent)),
            ),
          _buildInput(isDark),
        ],
      ),
    );
  }

  String? _editingMessageId;

  void _showMessageMenu(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.copy_rounded),
            title: const Text('Copy Text'),
            onTap: () {
              Navigator.pop(ctx);
            },
          ),
          if (message.imageUrl == null)
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Edit Message'),
              onTap: () {
                Navigator.pop(ctx);
                _editMessage(message);
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
            title: const Text('Delete Message', style: TextStyle(color: AppColors.danger)),
            onTap: () {
              Navigator.pop(ctx);
              _deleteMessage(message);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _editMessage(ChatMessage message) {
    _msgCtrl.text = message.content;
    setState(() => _editingMessageId = message.id);
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: const Text('Delete message?'),
        content: const Text('This will remove the message for both of you.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(chatServiceProvider).deleteMessage(message.id);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e))));
      }
    }
  }

  Widget _buildInput(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_editingMessageId != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? Colors.blueGrey.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.05),
            child: Row(
              children: [
                const Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Editing message',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    _msgCtrl.clear();
                    setState(() => _editingMessageId = null);
                  },
                  icon: const Icon(Icons.close_rounded, size: 16),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        Container(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            border: Border(top: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add_photo_alternate_rounded, color: AppColors.primary),
                onPressed: (_isSending || _editingMessageId != null) ? null : _pickImage,
              ),
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  enabled: !_isSending,
                  decoration: InputDecoration(
                    hintText: 'Type your doubt here...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  maxLines: 4,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: _isSending ? Colors.grey : AppColors.primary,
                child: IconButton(
                  icon: Icon(_editingMessageId != null ? Icons.check_rounded : Icons.send_rounded, color: Colors.white, size: 20),
                  onPressed: _isSending ? null : () => _send(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final VoidCallback? onLongPress;

  const _MessageBubble({required this.message, required this.isMe, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onLongPress: onLongPress,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: isMe 
              ? AppColors.primary 
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 0),
              bottomRight: Radius.circular(isMe ? 0 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: message.imageUrl!,
                    placeholder: (_, __) => const SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
                    errorWidget: (_, __, ___) => const Icon(Icons.error_outline),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                message.content,
                style: TextStyle(color: isMe ? Colors.white : (isDark ? Colors.white : AppColors.textPrimary)),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat.jm().format(message.createdAt),
                    style: TextStyle(
                      fontSize: 9, 
                      color: isMe ? Colors.white70 : (isDark ? Colors.white60 : AppColors.textMuted),
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.isRead ? Icons.done_all_rounded : Icons.check_rounded,
                      size: 12,
                      color: message.isRead ? Colors.blue[300] : Colors.white70,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
