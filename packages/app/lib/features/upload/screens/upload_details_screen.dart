import 'package:app/shared/utils/error_utils.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:design_system/design_system.dart';
import 'package:shared/shared.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/providers/providers.dart';

class UploadDetailsScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> uploadData;
  const UploadDetailsScreen({super.key, required this.uploadData});
  @override
  ConsumerState<UploadDetailsScreen> createState() => _UploadDetailsScreenState();
}

class _UploadDetailsScreenState extends ConsumerState<UploadDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  String _subject = AppConstants.subjects.first;
  String _classLevel = AppConstants.classLevels.first;
  String _board = AppConstants.boards.first;
  String _visibility = 'public';
  final Set<String> _tags = {};
  String? _selectedFolderId;
  String? _selectedFolderName;
  final bool _requiresApproval = true;
  bool _uploading = false;
  String _uploadStatus = '';

  List<File> get _files => (widget.uploadData['files'] as List?)?.cast<File>() ?? [];
  String get _fileType => widget.uploadData['fileType'] as String? ?? 'pdf';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final clean = tag.trim().toLowerCase().replaceAll(' ', '_');
    if (clean.isNotEmpty && clean.length <= 30 && _tags.length < 8) {
      setState(() { _tags.add(clean); _tagCtrl.clear(); });
    }
  }

  Future<void> _showFolderPicker() async {
    final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (uid == null) return;
    final rootFolders = await ref.read(profileServiceProvider).getUserFolders(uid);
    if (!mounted) return;
    if (rootFolders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No folders yet. Create one from your profile first.'), behavior: SnackBarBehavior.floating));
      return;
    }

    final flatList = <(Folder, int)>[];
    Future<void> addFolderTree(List<Folder> folders, int depth) async {
      for (final f in folders) {
        flatList.add((f, depth));
        try {
          final subs = await ref.read(profileServiceProvider).getSubFolders(f.id);
          if (subs.isNotEmpty) await addFolderTree(subs, depth + 1);
        } catch (_) {}
      }
    }
    await addFolderTree(rootFolders, 0);
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet(
      context: context, useRootNavigator: true, backgroundColor: isDark ? AppColors.surfaceDark : Colors.white, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.55, maxChildSize: 0.9, minChildSize: 0.3, expand: false,
        builder: (_, ctrl) => Column(
          children: [
            Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 40, height: 4, decoration: BoxDecoration(color: isDark ? AppColors.borderDark : AppColors.border, borderRadius: AppRadius.full)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Select Folder', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.textPrimary)),
                  TextButton(onPressed: () { setState(() { _selectedFolderId = null; _selectedFolderName = null; }); Navigator.of(sheetCtx).pop(); }, child: const Text('No Folder', style: TextStyle(color: AppColors.textMuted))),
                ])),
            const Divider(height: 1),
            Expanded(child: ListView.builder(controller: ctrl, padding: const EdgeInsets.symmetric(vertical: 8), itemCount: flatList.length, itemBuilder: (_, i) {
                  final (f, depth) = flatList[i];
                  final color = Color(int.parse('0xFF${f.colorHex.replaceAll('#', '')}'));
                  final isSelected = _selectedFolderId == f.id;
                  return ListTile(
                    contentPadding: EdgeInsets.only(left: 16.0 + depth * 20.0, right: 16),
                    leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: AppRadius.sm), child: Icon(depth == 0 ? Icons.folder_rounded : Icons.folder_open_rounded, color: color, size: 20)),
                    title: Text(f.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: depth == 0 ? 14 : 13, color: isSelected ? AppColors.primary : (isDark ? Colors.white : AppColors.textPrimary))),
                    subtitle: Text('${f.notesCount} notes', style: TextStyle(fontSize: 11, color: isDark ? AppColors.textMutedDark : AppColors.textMuted)),
                    trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : Icon(Icons.chevron_right_rounded, color: isDark ? AppColors.textMutedDark : AppColors.textMuted, size: 18),
                    onTap: () { setState(() { _selectedFolderId = f.id; _selectedFolderName = depth > 0 ? '${f.name} (sub-folder)' : f.name; }); Navigator.of(sheetCtx).pop(); },
                  );
                })),
          ],
        ),
      ),
    );
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_files.isEmpty) return;
    setState(() { _uploading = true; _uploadStatus = 'Preparing upload...'; });
    try {
      final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (uid == null) throw Exception('Not authenticated');
      setState(() => _uploadStatus = 'Uploading files...');
      final noteId = DateTime.now().millisecondsSinceEpoch.toString();
      final fileKeys = await ref.read(notesServiceProvider).uploadFiles(files: _files, noteId: noteId, userId: uid);
      setState(() => _uploadStatus = 'Creating note...');
      final createdId = await ref.read(notesServiceProvider).createNoteDraft(
        title: _titleCtrl.text.trim(), subject: _subject, classLevel: _classLevel, board: _board, fileType: _fileType, fileKeys: fileKeys, tags: _tags.toList(), visibility: _visibility, description: _descCtrl.text.trim(), folderId: _selectedFolderId, requiresApproval: _requiresApproval,
      );
      ref.invalidate(currentUserProfileProvider);
      if (_selectedFolderId != null) {
        final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
        if (uid != null) ref.invalidate(userFoldersProvider(uid));
      }
      setState(() => _uploadStatus = 'Processing...');
      if (mounted) context.go('/upload/success?noteId=$createdId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e)), backgroundColor: AppColors.danger));
        setState(() { _uploading = false; _uploadStatus = ''; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.appBarTheme.backgroundColor,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
          title: Text('Note Details', style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w700)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(value: 0.66, backgroundColor: isDark ? AppColors.borderDark : AppColors.border, color: AppColors.primary),
          ),
        ),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Preview Section
                        Container(
                          width: double.infinity,
                          height: 180,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                            borderRadius: AppRadius.lg,
                            border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
                          ),
                          child: ClipRRect(
                            borderRadius: AppRadius.lg,
                            child: Stack(
                              children: [
                                if (_fileType == 'pdf' && _files.isNotEmpty)
                                  IgnorePointer(
                                    child: SfPdfViewer.file(
                                      _files.first,
                                      canShowScrollHead: false,
                                      canShowPaginationDialog: false,
                                    ),
                                  )
                                else if (_fileType == 'image_set' && _files.isNotEmpty)
                                  Image.file(_files.first, width: double.infinity, height: 180, fit: BoxFit.cover)
                                else
                                  const Center(child: Icon(Icons.insert_drive_file_rounded, size: 48, color: AppColors.primary)),
                                
                                // Overlay info
                                Positioned(
                                  bottom: 0, left: 0, right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter, end: Alignment.topCenter,
                                        colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(_fileType == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.photo_library_rounded, 
                                          color: Colors.white, size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${_files.length} ${_fileType == 'pdf' ? 'PDF Page(s)' : 'image(s)'} selected',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    const SizedBox(height: 24),
                    _field('Note Title *', _titleCtrl, Icons.title_rounded, theme, maxLength: 150, hint: 'e.g. Chapter 5 - Thermodynamics', validator: (v) => v!.trim().isEmpty ? 'Title is required' : null),
                    const SizedBox(height: 14),
                    _field('Description (optional)', _descCtrl, Icons.description_rounded, theme, maxLines: 3, maxLength: 500, hint: 'What is covered in these notes?'),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _subject,
                      dropdownColor: theme.cardTheme.color,
                      style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
                      decoration: const InputDecoration(labelText: 'Subject *', prefixIcon: Icon(Icons.menu_book_rounded)),
                      items: AppConstants.subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setState(() => _subject = v!),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: DropdownButtonFormField<String>(
                        initialValue: _classLevel,
                        isExpanded: true,
                        dropdownColor: theme.cardTheme.color,
                        style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
                        decoration: const InputDecoration(labelText: 'Class'),
                        items: AppConstants.classLevels.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (v) => setState(() => _classLevel = v!),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: DropdownButtonFormField<String>(
                        initialValue: _board,
                        isExpanded: true,
                        dropdownColor: theme.cardTheme.color,
                        style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
                        decoration: const InputDecoration(labelText: 'Board'),
                        items: AppConstants.boards.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (v) => setState(() => _board = v!),
                      )),
                    ]),
                    const SizedBox(height: 14),
                    Text('Visibility', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    Row(children: ['public', 'followers'].map((v) {
                      final isSelected = _visibility == v;
                      return Expanded(child: Padding(
                        padding: EdgeInsets.only(right: v == 'public' ? 8 : 0),
                        child: GestureDetector(
                          onTap: () => setState(() => _visibility = v),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200), 
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                            decoration: BoxDecoration(color: isSelected ? AppColors.primary : (isDark ? AppColors.surfaceDark : Colors.white), borderRadius: AppRadius.md, border: Border.all(color: isSelected ? AppColors.primary : (isDark ? AppColors.borderDark : AppColors.border))),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(v == 'public' ? Icons.public_rounded : Icons.group_rounded, color: isSelected ? Colors.white : (isDark ? AppColors.textMutedDark : AppColors.textMuted), size: 18),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(v == 'public' ? 'Public' : 'Followers Only', 
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white : AppColors.textPrimary), fontWeight: FontWeight.w600, fontSize: 13)),
                              ),
                            ]),
                          ),
                        ),
                      ));
                    }).toList()),
                    const SizedBox(height: 14),
                    Text('Save to Folder (optional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _showFolderPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, borderRadius: AppRadius.md, border: Border.all(color: _selectedFolderId != null ? AppColors.primary : (isDark ? AppColors.borderDark : AppColors.border))),
                        child: Row(children: [
                          Icon(_selectedFolderId != null ? Icons.folder_rounded : Icons.folder_open_rounded, color: _selectedFolderId != null ? AppColors.primary : (isDark ? AppColors.textMutedDark : AppColors.textMuted), size: 22),
                          const SizedBox(width: 12),
                          Expanded(child: Text(_selectedFolderName ?? 'No folder selected', style: TextStyle(fontSize: 14, color: _selectedFolderId != null ? (isDark ? Colors.white : AppColors.textPrimary) : (isDark ? AppColors.textMutedDark : AppColors.textMuted), fontWeight: _selectedFolderId != null ? FontWeight.w600 : FontWeight.normal))),
                          if (_selectedFolderId != null) GestureDetector(onTap: () => setState(() { _selectedFolderId = null; _selectedFolderName = null; }), child: Icon(Icons.close_rounded, color: isDark ? AppColors.textMutedDark : AppColors.textMuted, size: 18))
                          else Icon(Icons.chevron_right_rounded, color: isDark ? AppColors.textMutedDark : AppColors.textMuted, size: 20),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Tags (up to 8)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    if (_tags.isNotEmpty) ...[
                      Wrap(spacing: 6, runSpacing: 6, children: _tags.map((t) => Chip(label: Text('#$t', style: const TextStyle(fontSize: 12)), onDeleted: () => setState(() => _tags.remove(t)), deleteIcon: const Icon(Icons.close_rounded, size: 14), backgroundColor: isDark ? const Color(0xFF2D2D4D) : AppColors.primarySurface, side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)))).toList()),
                      const SizedBox(height: 8),
                    ],
                    if (_tags.length < 8) Row(children: [
                      Expanded(child: TextFormField(
                        controller: _tagCtrl, 
                        style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary), 
                        decoration: InputDecoration(
                          hintText: 'Add tag', 
                          hintStyle: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMuted, fontSize: 13), 
                          prefixIcon: const Icon(Icons.tag_rounded), 
                          prefixText: '#'
                        ), 
                        onFieldSubmitted: _addTag
                      )),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _addTag(_tagCtrl.text), 
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          minimumSize: const Size(60, 50),
                        ), 
                        child: const Text('Add')
                      ),
                    ]),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : AppColors.primarySurface, borderRadius: AppRadius.md, border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))),
                      child: const Row(children: [ Icon(Icons.admin_panel_settings_rounded, size: 20, color: AppColors.primary), SizedBox(width: 10), Expanded(child: Text('Your note will be reviewed by our admin team before going live. This usually takes 24–48 hours.', style: TextStyle(fontSize: 12, color: AppColors.primary, height: 1.4))) ]),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
            if (_uploading)
              Container(color: Colors.black.withValues(alpha: 0.6), child: Center(child: Container(margin: const EdgeInsets.all(32), padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, borderRadius: AppRadius.xl), child: Column(mainAxisSize: MainAxisSize.min, children: [ const CircularProgressIndicator(color: AppColors.primary), const SizedBox(height: 20), Text(_uploadStatus, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimary), textAlign: TextAlign.center) ])))),
            if (!_uploading)
              Positioned(bottom: 0, left: 0, right: 0, child: Container(color: theme.scaffoldBackgroundColor, padding: const EdgeInsets.all(24), child: PrimaryButton(label: 'Upload Notes', icon: Icons.cloud_upload_rounded, onPressed: _upload))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon, ThemeData theme, {int maxLines = 1, int? maxLength, String? hint, String? Function(String?)? validator}) {
    final isDark = theme.brightness == Brightness.dark;
    return TextFormField(
      controller: ctrl, maxLines: maxLines, maxLength: maxLength,
      style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
      decoration: InputDecoration(labelText: label, hintText: hint, hintStyle: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMuted, fontSize: 13), prefixIcon: Icon(icon)),
      validator: validator,
    );
  }
}
