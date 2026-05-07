import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';
import 'package:shared/shared.dart';
import 'package:app/shared/utils/error_utils.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/providers/providers.dart';

class FolderViewScreen extends ConsumerStatefulWidget {
  final String userId;
  final String folderId;
  const FolderViewScreen({super.key, required this.userId, required this.folderId});
  @override
  ConsumerState<FolderViewScreen> createState() => _FolderViewScreenState();
}

class _FolderViewScreenState extends ConsumerState<FolderViewScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(userFoldersProvider(widget.userId));
    final subFoldersAsync = ref.watch(subFoldersProvider(widget.folderId));
    final notesAsync = ref.watch(folderNotesProvider((userId: widget.userId, folderId: widget.folderId)));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Folder? folder = foldersAsync.value?.firstWhere((f) => f.id == widget.folderId, orElse: () => Folder(id: '', userId: '', name: 'Folder', createdAt: DateTime(2024)));
    if (folder?.id.isEmpty == true) { folder = subFoldersAsync.value?.firstWhere((f) => f.id == widget.folderId, orElse: () => Folder(id: '', userId: '', name: 'Folder', createdAt: DateTime(2024))); }

    final color = (folder != null && folder.colorHex.isNotEmpty) ? Color(int.parse('0xFF${folder.colorHex.replaceAll('#', '')}')) : AppColors.primary;
    final isOwner = ref.read(supabaseClientProvider).auth.currentUser?.id == widget.userId;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: isOwner ? FloatingActionButton.extended(onPressed: () => _showCreateSubFolderDialog(color), backgroundColor: color, icon: const Icon(Icons.create_new_folder_rounded, color: Colors.white), label: const Text('Sub-folder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))) : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userFoldersProvider(widget.userId));
          ref.invalidate(subFoldersProvider(widget.folderId));
          ref.invalidate(folderNotesProvider((userId: widget.userId, folderId: widget.folderId)));
          await ref.read(folderNotesProvider((userId: widget.userId, folderId: widget.folderId)).future);
        },
        color: color,
        child: NestedScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          headerSliverBuilder: (_, __) => [
            SliverAppBar(
              expandedHeight: 100, pinned: true, backgroundColor: color, foregroundColor: Colors.white,
              actions: [
                if (isOwner) PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                  onSelected: (val) { if (val == 'edit') { _showEditFolderDialog(folder); } else if (val == 'delete') { _confirmDelete(); } },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 20, color: AppColors.textPrimary), SizedBox(width: 10), Text('Edit Folder')])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger), SizedBox(width: 10), Text('Delete Folder', style: TextStyle(color: AppColors.danger))])),
                  ],
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(centerTitle: false, titlePadding: const EdgeInsets.only(left: 56, bottom: 60, right: 48), title: Text(folder?.name ?? 'Folder', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis), background: Container(color: color, child: Align(alignment: Alignment.center, child: Padding(padding: const EdgeInsets.only(top: 20), child: Icon(Icons.folder_rounded, color: Colors.white.withValues(alpha: 0.15), size: 64))))),
              bottom: TabBar(controller: _tabCtrl, labelColor: Colors.white, unselectedLabelColor: Colors.white60, indicatorColor: Colors.white, indicatorWeight: 3, tabs: [ Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [ const Icon(Icons.article_rounded, size: 16), const SizedBox(width: 6), Text('Notes (${notesAsync.value?.length ?? 0})') ])), Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [ const Icon(Icons.folder_rounded, size: 16), const SizedBox(width: 6), Text('Folders (${subFoldersAsync.value?.length ?? 0})') ])) ]),
            ),
          ],
          body: TabBarView(
            controller: _tabCtrl,
            children: [
              notesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (e, _) => SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), child: EmptyState(icon: Icons.error_outline_rounded, title: 'Error', subtitle: getFriendlyErrorMessage(e))),
                data: (notes) {
                  if (notes.isEmpty) return const SingleChildScrollView(physics: AlwaysScrollableScrollPhysics(), child: EmptyState(icon: Icons.article_outlined, title: 'No notes in this folder', subtitle: 'Upload a note and assign it to this folder'));
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16), itemCount: notes.length,
                    itemBuilder: (ctx, i) {
                      final n = notes[i];
                      final interaction = ref.watch(interactionProvider)[n.id];
                      return Stack(children: [
                        NoteCard(
                          note: NoteCardData(
                            id: n.id, title: n.title, subject: n.subject, 
                            authorName: n.authorName ?? '', authorId: n.userId, 
                            authorAvatarUrl: n.authorAvatarUrl, isAuthorVerified: n.authorIsVerified, 
                            thumbnailUrl: n.thumbnailUrl, 
                            likesCount: interaction?.likesCount ?? n.likesCount, 
                            savesCount: interaction?.savesCount ?? n.savesCount, 
                            pageCount: n.pageCount, 
                            isLiked: interaction?.isLiked ?? n.isLiked,
                            isSaved: interaction?.isSaved ?? n.isSaved,
                            tags: n.tags, createdAt: n.createdAt,
                          ),
                          onTap: () => context.push('/notes/${n.id}'),
                          onLike: () => ref.read(interactionProvider.notifier).toggleLike(n.id),
                          onSave: () => ref.read(interactionProvider.notifier).toggleSave(n.id),
                        ),
                        if (isOwner) Positioned(top: 8, right: 8, child: IconButton(icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white : AppColors.textPrimary), style: IconButton.styleFrom(backgroundColor: isDark ? AppColors.surfaceDark.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.8), padding: EdgeInsets.zero), onPressed: () => _showNoteOptions(n))),
                      ]);
                    },
                  );
                },
              ),
              subFoldersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (e, _) => SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), child: EmptyState(icon: Icons.error_outline_rounded, title: 'Error', subtitle: e.toString())),
                data: (subFolders) {
                  if (subFolders.isEmpty) return SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), child: EmptyState(icon: Icons.folder_outlined, title: 'No sub-folders', subtitle: isOwner ? 'Tap "Sub-folder" to create one' : 'No sub-folders here'));
                  return GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.1),
                    itemCount: subFolders.length,
                    itemBuilder: (ctx, i) {
                      final f = subFolders[i];
                      final fColor = Color(int.parse('0xFF${f.colorHex.replaceAll('#', '')}'));
                      return GestureDetector(
                        onTap: () => context.push('/profile/${widget.userId}/folder/${f.id}'),
                        onLongPress: isOwner ? () => _showSubFolderOptions(f) : null,
                        child: Container(
                          decoration: BoxDecoration(color: fColor.withValues(alpha: 0.1), borderRadius: AppRadius.lg, border: Border.all(color: fColor.withValues(alpha: 0.35))),
                          padding: const EdgeInsets.all(14),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Stack(alignment: Alignment.center, children: [
                              Icon(Icons.folder_open_rounded, color: fColor, size: 44),
                              if (f.notesCount > 0) Positioned(bottom: 2, child: Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: fColor, borderRadius: AppRadius.full), child: Text('${f.notesCount}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)))),
                            ]),
                            const SizedBox(height: 8),
                            Text(f.name, style: TextStyle(fontWeight: FontWeight.w700, color: fColor, fontSize: 13), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text('${f.notesCount} note${f.notesCount == 1 ? '' : 's'}', style: TextStyle(fontSize: 11, color: isDark ? AppColors.textMutedDark : AppColors.textMuted)),
                          ]),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNoteOptions(dynamic note) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context, useRootNavigator: true, backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.only(top: 10, bottom: 4), width: 36, height: 4, decoration: BoxDecoration(color: isDark ? AppColors.borderDark : AppColors.border, borderRadius: AppRadius.full)),
          ListTile(leading: const Icon(Icons.open_in_new_rounded, color: AppColors.primary), title: Text('View Note', style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary)), onTap: () { Navigator.of(sheetCtx).pop(); context.push('/notes/${note.id}'); }),
          ListTile(leading: Icon(Icons.edit_outlined, color: isDark ? Colors.white : AppColors.textPrimary), title: Text('Edit Note', style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary)), onTap: () { Navigator.of(sheetCtx).pop(); context.push('/notes/${note.id}/edit'); }),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
            title: const Text('Delete Note', style: TextStyle(color: AppColors.danger)),
            onTap: () async {
              Navigator.of(sheetCtx).pop();
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogCtx) => AlertDialog(
                  backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
                  title: Text('Delete Note?', style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary)),
                  content: Text('This will permanently remove your note.', style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
                    ElevatedButton(onPressed: () => Navigator.of(dialogCtx).pop(true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger), child: const Text('Delete')),
                  ],
                ),
              );
              if (confirmed == true) {
                try {
                  await ref.read(notesServiceProvider).deleteNote(note.id);
                  ref.invalidate(folderNotesProvider((userId: widget.userId, folderId: widget.folderId)));
                  ref.invalidate(userNotesProvider(widget.userId));
                  ref.invalidate(userFoldersProvider(widget.userId));
                  ref.invalidate(subFoldersProvider(widget.folderId));
                  ref.invalidate(profileProvider(widget.userId));
                  ref.invalidate(feedProvider);
                  ref.invalidate(currentUserProfileProvider);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note deleted successfully'), backgroundColor: AppColors.success));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e)), backgroundColor: AppColors.danger));
                  }
                }
              }
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _showSubFolderOptions(Folder f) async {
    final fColor = Color(int.parse('0xFF${f.colorHex.replaceAll('#', '')}'));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showModalBottomSheet(
      context: context, useRootNavigator: true, backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.only(top: 10, bottom: 4), width: 36, height: 4, decoration: BoxDecoration(color: isDark ? AppColors.borderDark : AppColors.border, borderRadius: AppRadius.full)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), child: Row(children: [ Icon(Icons.folder_open_rounded, color: fColor, size: 22), const SizedBox(width: 10), Text(f.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimary)) ])),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.open_in_new_rounded, color: AppColors.primary), title: Text('Open Folder', style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary)), onTap: () { Navigator.of(sheetCtx).pop(); context.push('/profile/${widget.userId}/folder/${f.id}'); }),
          ListTile(leading: Icon(Icons.edit_outlined, color: isDark ? Colors.white : AppColors.textPrimary), title: Text('Edit Folder', style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary)), onTap: () { Navigator.of(sheetCtx).pop(); _showEditFolderDialog(f); }),
          ListTile(leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger), title: const Text('Delete Folder', style: TextStyle(color: AppColors.danger)), onTap: () async { Navigator.of(sheetCtx).pop(); final confirmed = await showDialog<bool>(context: context, builder: (dialogCtx) => AlertDialog(backgroundColor: isDark ? AppColors.surfaceDark : Colors.white, shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl), title: Text('Delete Sub-folder?', style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary)), content: Text('Notes inside will not be deleted.', style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)), actions: [ TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.of(dialogCtx).pop(true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger), child: const Text('Delete')) ])); if (confirmed == true) { try { await ref.read(profileServiceProvider).deleteFolder(f.id); ref.invalidate(subFoldersProvider(widget.folderId)); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sub-folder deleted'), backgroundColor: AppColors.success)); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e)), backgroundColor: AppColors.danger)); } } }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _showCreateSubFolderDialog(Color parentColor) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showModalBottomSheet<Map<String, String>>(context: context, useRootNavigator: true, isScrollControlled: true, backgroundColor: isDark ? AppColors.surfaceDark : Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (sheetCtx) => _CreateSubFolderSheet(onSubmit: (name, color) => Navigator.of(sheetCtx).pop({'name': name, 'color': color})));
    if (result != null) { try { await ref.read(profileServiceProvider).createFolder(widget.userId, result['name']!, result['color']!, parentFolderId: widget.folderId); ref.invalidate(subFoldersProvider(widget.folderId)); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sub-folder created!'), backgroundColor: AppColors.success)); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e)), backgroundColor: AppColors.danger)); } }
  }

  Future<void> _confirmDelete() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
        title: Text('Delete Folder?', style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary)),
        content: Text('This will delete the folder and all its sub-folders. Notes inside will not be deleted.', style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(dialogCtx).pop(true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(profileServiceProvider).deleteFolder(widget.folderId);
        ref.invalidate(userFoldersProvider(widget.userId));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Folder deleted successfully'), backgroundColor: AppColors.success));
        if (mounted) context.pop();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e)), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _showEditFolderDialog(Folder? folder) async {
    if (folder == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showModalBottomSheet<Map<String, String>>(context: context, useRootNavigator: true, isScrollControlled: true, backgroundColor: isDark ? AppColors.surfaceDark : Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (sheetCtx) => _CreateSubFolderSheet(title: 'Edit Folder', initialName: folder.name, initialColor: folder.colorHex, submitLabel: 'Save Changes', onSubmit: (name, color) => Navigator.of(sheetCtx).pop({'name': name, 'color': color})));
    if (result != null) { try { await ref.read(profileServiceProvider).updateFolder(folder.id, result['name']!, result['color']!); ref.invalidate(userFoldersProvider(widget.userId)); ref.invalidate(subFoldersProvider(widget.folderId)); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Folder updated!'), backgroundColor: AppColors.success)); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e)), backgroundColor: AppColors.danger)); } }
  }
}

class _CreateSubFolderSheet extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialColor;
  final String submitLabel;
  final void Function(String name, String color) onSubmit;
  const _CreateSubFolderSheet({this.title = 'Create Sub-folder', this.initialName, this.initialColor, this.submitLabel = 'Create', required this.onSubmit});
  @override
  State<_CreateSubFolderSheet> createState() => _CreateSubFolderSheetState();
}

class _CreateSubFolderSheetState extends State<_CreateSubFolderSheet> {
  late final TextEditingController _nameCtrl;
  late String _selectedColor;
  @override
  void initState() { super.initState(); _nameCtrl = TextEditingController(text: widget.initialName); _selectedColor = widget.initialColor ?? AppConstants.folderColors.first; }
  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(widget.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.textPrimary)), const SizedBox(height: 20), TextField(controller: _nameCtrl, autofocus: true, maxLength: 80, style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary), decoration: InputDecoration(labelText: 'Folder Name', labelStyle: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMuted), prefixIcon: const Icon(Icons.folder_rounded)), onSubmitted: (_) => _submit()), const SizedBox(height: 12), Text('Color', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimary)), const SizedBox(height: 10), Wrap(spacing: 10, children: AppConstants.folderColors.map((hex) { final c = Color(int.parse('0xFF${hex.replaceAll('#', '')}')); final isSelected = _selectedColor == hex; return GestureDetector(onTap: () => setState(() => _selectedColor = hex), child: AnimatedContainer(duration: const Duration(milliseconds: 150), width: 36, height: 36, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.transparent, width: 3)), child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null)); }).toList()), const SizedBox(height: 24), PrimaryButton(label: widget.submitLabel, icon: Icons.create_new_folder_rounded, onPressed: _submit) ]));
  }
  void _submit() { final name = _nameCtrl.text.trim(); if (name.isNotEmpty) widget.onSubmit(name, _selectedColor); }
}
