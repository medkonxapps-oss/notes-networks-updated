import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';

class UploadSelectScreen extends StatefulWidget {
  const UploadSelectScreen({super.key});
  @override
  State<UploadSelectScreen> createState() => _UploadSelectScreenState();
}

class _UploadSelectScreenState extends State<UploadSelectScreen> {
  List<File> _selectedFiles = [];
  String _fileType = 'pdf'; // 'pdf' | 'image_set'
  final bool _isLoading = false;

  Future<void> _pickPDF() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFiles = result.files
            .where((f) => f.path != null)
            .map((f) => File(f.path!))
            .toList();
        _fileType = 'pdf';
      });
    }
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFiles = result.files
            .where((f) => f.path != null)
            .map((f) => File(f.path!))
            .toList();
        _fileType = 'image_set';
      });
    }
  }

  void _removeFile(int index) {
    setState(() => _selectedFiles.removeAt(index));
  }

  void _proceed() {
    if (_selectedFiles.isEmpty) return;
    context.push('/upload/details', extra: {
      'files': _selectedFiles,
      'fileType': _fileType,
    });
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
          title: Text('Upload Notes', style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w700)),
          leading: IconButton(
            icon: Icon(Icons.close_rounded, color: isDark ? Colors.white : AppColors.textPrimary),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
        ),
        body: Column(
          children: [
            LinearProgressIndicator(
              value: 0.33, backgroundColor: isDark ? AppColors.borderDark : AppColors.border, color: AppColors.primary,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Files', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    Text('Upload a PDF or multiple images of your notes', 
                      style: TextStyle(fontSize: 14, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
                    const SizedBox(height: 28),

                    Row(children: [
                      Expanded(child: _UploadOption(
                        icon: Icons.picture_as_pdf_rounded,
                        label: 'PDF File',
                        subtitle: 'Upload a single PDF',
                        color: AppColors.danger,
                        isSelected: _fileType == 'pdf' && _selectedFiles.isNotEmpty,
                        onTap: _pickPDF,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _UploadOption(
                        icon: Icons.photo_library_rounded,
                        label: 'Images',
                        subtitle: 'Multiple pages as JPG/PNG',
                        color: AppColors.primary,
                        isSelected: _fileType == 'image_set' && _selectedFiles.isNotEmpty,
                        onTap: _pickImages,
                      )),
                    ]),

                    if (_selectedFiles.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Selected (${_selectedFiles.length})', 
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimary)),
                          TextButton(
                            onPressed: () => setState(() => _selectedFiles = []),
                            child: const Text('Clear all', style: TextStyle(color: AppColors.danger)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_fileType == 'pdf')
                        _PDFPreview(file: _selectedFiles.first)
                      else
                        _ImageGrid(files: _selectedFiles, onRemove: _removeFile),
                    ],

                    if (_selectedFiles.isEmpty) ...[
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : AppColors.primarySurface, borderRadius: AppRadius.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tips for better notes:', 
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimary)),
                            const SizedBox(height: 10),
                            ...[
                              'Good lighting when photographing handwritten notes',
                              'PDF max size: 50MB | Each image: max 10MB',
                              'Write legibly — good notes get more likes!',
                              'Add accurate subject tags for discoverability',
                            ].map((t) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(children: [
                                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(t, style: TextStyle(fontSize: 12, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary))),
                              ]),
                            )),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: PrimaryButton(
                label: 'Next: Add Details',
                icon: Icons.arrow_forward_rounded,
                onPressed: _selectedFiles.isNotEmpty ? _proceed : null,
                isLoading: _isLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _UploadOption({
    required this.icon, required this.label, required this.subtitle,
    required this.color, required this.isSelected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : (isDark ? AppColors.surfaceDark : Colors.white),
          borderRadius: AppRadius.lg,
          border: Border.all(
            color: isSelected ? color : (isDark ? AppColors.borderDark : AppColors.border),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 8),
            Text(
              label, 
              style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimary), 
              textAlign: TextAlign.center, 
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle, 
              style: TextStyle(fontSize: 11, color: isDark ? AppColors.textMutedDark : AppColors.textMuted), 
              textAlign: TextAlign.center, 
              maxLines: 2, 
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _PDFPreview extends StatelessWidget {
  final File file;
  const _PDFPreview({required this.file});

  @override
  Widget build(BuildContext context) {
    final name = file.path.split('/').last;
    final sizeKb = file.lengthSync() ~/ 1024;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white, 
        borderRadius: AppRadius.md,
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border)),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.1), borderRadius: AppRadius.sm),
          child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.danger),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('$sizeKb KB', style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMuted)),
          ],
        )),
        const Icon(Icons.check_circle_rounded, color: AppColors.success),
      ]),
    );
  }
}

class _ImageGrid extends StatelessWidget {
  final List<File> files;
  final ValueChanged<int> onRemove;
  const _ImageGrid({required this.files, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: files.length,
      itemBuilder: (_, i) => Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: AppRadius.sm,
            child: Image.file(files[i], fit: BoxFit.cover),
          ),
          Positioned(
            top: 4, right: 4,
            child: GestureDetector(
              onTap: () => onRemove(i),
              child: Container(
                width: 20, height: 20,
                decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 12),
              ),
            ),
          ),
          Positioned(
            bottom: 4, left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: AppRadius.full),
              child: Text('${i+1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
