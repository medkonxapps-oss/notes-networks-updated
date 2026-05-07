import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';
import 'package:shared/shared.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/providers/providers.dart';

class EditNoteScreen extends ConsumerStatefulWidget {
  final String noteId;
  const EditNoteScreen({super.key, required this.noteId});

  @override
  ConsumerState<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends ConsumerState<EditNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();

  String? _subject;
  String? _classLevel;
  String? _board;
  String? _visibility;
  Set<String> _tags = {};
  bool _loading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  void _initFromNote(Note note) {
    if (_initialized) return;
    _initialized = true;
    _titleCtrl.text = note.title;
    _descCtrl.text = note.description ?? '';
    _subject = note.subject;
    _classLevel = note.classLevel;
    _board = note.board;
    _visibility = note.visibility;
    _tags = Set.from(note.tags);
  }

  void _addTag(String tag) {
    final clean = tag.trim().toLowerCase().replaceAll(' ', '_');
    if (clean.isNotEmpty && clean.length <= 30 && _tags.length < 8) {
      setState(() { _tags.add(clean); _tagCtrl.clear(); });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(notesServiceProvider).updateNote(
        noteId: widget.noteId,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        subject: _subject!,
        classLevel: _classLevel!,
        board: _board!,
        visibility: _visibility!,
        tags: _tags.toList(),
      );

      // Invalidate so detail screen and profile refresh
      ref.invalidate(_noteDetailProviderFamily(widget.noteId));
      final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (uid != null) ref.invalidate(userNotesProvider(uid));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Note updated!'),
          backgroundColor: AppColors.success,
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final noteAsync = ref.watch(_noteDetailProviderFamily(widget.noteId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      },
      child: noteAsync.when(
        loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppColors.primary))),
        error: (e, _) => Scaffold(
            body: EmptyState(icon: Icons.error_outline_rounded, title: 'Error', subtitle: e.toString())),
        data: (note) {
          if (note == null) {
            return const Scaffold(
                body: EmptyState(icon: Icons.article_outlined, title: 'Note not found', subtitle: ''));
          }
          _initFromNote(note);
          return _buildForm(note);
        },
      ),
    );
  }

  Widget _buildForm(Note note) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text('Edit Note',
            style: TextStyle(
              fontWeight: FontWeight.w700, 
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary
            )),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Text('Save',
                    style: TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status banner
              _StatusBanner(status: note.status),
              const SizedBox(height: 20),

              // Title
              TextFormField(
                controller: _titleCtrl,
                maxLength: 150,
                style: TextStyle(color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Note Title *',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                validator: (v) => v!.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 14),

              // Description
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                maxLength: 500,
                style: TextStyle(color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: Icon(Icons.description_rounded),
                ),
              ),
              const SizedBox(height: 14),

              // Subject
              DropdownButtonFormField<String>(
                initialValue: _subject,
                style: TextStyle(color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
                dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
                decoration: const InputDecoration(
                    labelText: 'Subject *', prefixIcon: Icon(Icons.menu_book_rounded)),
                items: AppConstants.subjects
                    .map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary))))
                    .toList(),
                onChanged: (v) => setState(() => _subject = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _classLevel,
                    isExpanded: true,
                    style: TextStyle(color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
                    dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
                    decoration: const InputDecoration(labelText: 'Class'),
                    items: AppConstants.classLevels
                        .map((c) => DropdownMenuItem(
                            value: c, child: Text(c, style: TextStyle(fontSize: 13, color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary))))
                        .toList(),
                    onChanged: (v) => setState(() => _classLevel = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _board,
                    isExpanded: true,
                    style: TextStyle(color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
                    dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
                    decoration: const InputDecoration(labelText: 'Board'),
                    items: AppConstants.boards
                        .map((b) => DropdownMenuItem(
                            value: b, child: Text(b, style: TextStyle(fontSize: 13, color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary))))
                        .toList(),
                    onChanged: (v) => setState(() => _board = v),
                  ),
                ),
              ]),
              const SizedBox(height: 14),

              // Visibility
              Text('Visibility', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(children: ['public', 'followers'].map((v) {
                final isSelected = _visibility == v;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: v == 'public' ? 8 : 0),
                    child: GestureDetector(
                      onTap: () => setState(() => _visibility = v),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : (isDark ? AppColors.surfaceDark : Colors.white),
                          borderRadius: AppRadius.md,
                          border: Border.all(
                              color: isSelected ? AppColors.primary : (isDark ? AppColors.borderDark : AppColors.border)),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(v == 'public' ? Icons.public_rounded : Icons.group_rounded,
                              color: isSelected ? Colors.white : AppColors.textMuted, size: 18),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(v == 'public' ? 'Public' : 'Followers Only',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: isSelected ? Colors.white : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                );
              }).toList()),
              const SizedBox(height: 14),

              // Tags
              Text('Tags (up to 8)', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_tags.isNotEmpty) ...[
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: _tags.map((t) => Chip(
                    label: Text('#$t', style: const TextStyle(fontSize: 12)),
                    onDeleted: () => setState(() => _tags.remove(t)),
                    deleteIcon: const Icon(Icons.close_rounded, size: 14),
                    backgroundColor: isDark ? const Color(0xFF2D2D4D) : AppColors.primarySurface,
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                  )).toList(),
                ),
                const SizedBox(height: 8),
              ],
              if (_tags.length < 8)
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _tagCtrl,
                      style: TextStyle(color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Add tag',
                        prefixIcon: Icon(Icons.tag_rounded),
                        prefixText: '#',
                      ),
                      onSubmitted: _addTag,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _addTag(_tagCtrl.text),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        minimumSize: const Size(60, 50)),
                    child: const Text('Add'),
                  ),
                ]),

              const SizedBox(height: 32),
              PrimaryButton(
                label: 'Save Changes',
                icon: Icons.save_rounded,
                onPressed: _save,
                isLoading: _loading,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// Status banner shown at top of edit screen
class _StatusBanner extends StatelessWidget {
  final String status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String message;

    switch (status) {
      case 'pending_review':
        color = Colors.orange;
        icon = Icons.pending_actions_rounded;
        message = 'This note is pending admin review. You can still edit it while waiting.';
        break;
      case 'active':
        color = AppColors.success;
        icon = Icons.check_circle_rounded;
        message = 'This note is live. Changes will be visible immediately.';
        break;
      case 'removed':
        color = AppColors.danger;
        icon = Icons.block_rounded;
        message = 'This note has been removed and is not visible to others.';
        break;
      default:
        color = AppColors.primary;
        icon = Icons.info_outline_rounded;
        message = 'Status: $status';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.md,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: TextStyle(fontSize: 13, color: color, height: 1.4)),
        ),
      ]),
    );
  }
}

// Re-export the provider so edit screen can use it
final _noteDetailProviderFamily = FutureProvider.autoDispose.family<Note?, String>(
  (ref, noteId) => ref.read(notesServiceProvider).getNoteById(noteId),
);
