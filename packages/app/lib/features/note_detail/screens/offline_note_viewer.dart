import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:photo_view/photo_view.dart';

import '../../../core/services/local_db_service.dart';

class OfflineNoteViewer extends StatelessWidget {
  final LocalNote note;
  const OfflineNoteViewer({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(note.title, style: const TextStyle(color: Colors.white, fontSize: 16)),
            Text(note.authorName, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
      body: note.fileType == 'pdf'
          ? SfPdfViewer.file(
              File(note.localPath),
              pageLayoutMode: PdfPageLayoutMode.single,
              scrollDirection: PdfScrollDirection.horizontal,
              canShowScrollHead: false,
              canShowScrollStatus: false,
            )
          : Center(
              child: PhotoView(
                imageProvider: FileImage(File(note.localPath)),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2.0,
              ),
            ),
    );
  }
}
