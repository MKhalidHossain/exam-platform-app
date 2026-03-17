import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class EbookPdfViewerScreen extends StatelessWidget {
  final String title;
  final String pdfUrl;

  const EbookPdfViewerScreen({
    super.key,
    required this.title,
    required this.pdfUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title.isNotEmpty ? title : 'eBook Reader',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color(0xFF2D4F88),
      ),
      body: pdfUrl.trim().isEmpty
          ? const Center(
              child: Text('PDF is not available.'),
            )
          : SfPdfViewer.network(pdfUrl),
    );
  }
}