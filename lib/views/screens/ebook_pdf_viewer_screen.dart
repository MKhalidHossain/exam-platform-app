import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../core/error/error_handler.dart';

class EbookPdfViewerScreen extends StatefulWidget {
  final String title;
  final String pdfUrl;
  final String? localFilePath;

  const EbookPdfViewerScreen({
    super.key,
    required this.title,
    required this.pdfUrl,
    this.localFilePath,
  });

  @override
  State<EbookPdfViewerScreen> createState() => _EbookPdfViewerScreenState();
}

class _EbookPdfViewerScreenState extends State<EbookPdfViewerScreen> {
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _localFilePath;
  String? _savedDirectoryLabel;

  String get _trimmedPdfUrl => widget.pdfUrl.trim();

  @override
  void initState() {
    super.initState();
    _localFilePath = widget.localFilePath?.trim();
    _resolveExistingDownload();
  }

  Future<void> _resolveExistingDownload() async {
    if ((_localFilePath ?? '').isNotEmpty) return;
    if (_trimmedPdfUrl.isEmpty) return;

    final file = await _buildDownloadFile();
    if (!mounted) return;
    if (await file.exists()) {
      setState(() {
        _localFilePath = file.path;
      });
    }
  }

  Future<File> _buildDownloadFile() async {
    final directory = await _resolveSaveDirectory();
    final ebookDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}ebooks',
    );
    if (!await ebookDirectory.exists()) {
      await ebookDirectory.create(recursive: true);
    }

    final sanitizedTitle = widget.title
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final fileName = sanitizedTitle.isEmpty ? 'ebook' : sanitizedTitle;
    return File('${ebookDirectory.path}${Platform.pathSeparator}$fileName.pdf');
  }

  Future<Directory> _resolveSaveDirectory() async {
    try {
      final downloadsDirectory = await getDownloadsDirectory();
      if (downloadsDirectory != null) {
        _savedDirectoryLabel = 'Downloads';
        return downloadsDirectory;
      }
    } catch (_) {
      // Fallback below.
    }

    try {
      if (Platform.isAndroid) {
        final externalDirectory = await getExternalStorageDirectory();
        if (externalDirectory != null) {
          _savedDirectoryLabel = 'device storage';
          return externalDirectory;
        }
      }
    } catch (_) {
      // Fallback below.
    }

    _savedDirectoryLabel = 'app documents';
    return getApplicationDocumentsDirectory();
  }

  Future<void> _downloadPdf() async {
    if (_isDownloading || _trimmedPdfUrl.isEmpty) return;

    final uri = Uri.tryParse(_trimmedPdfUrl);
    if (uri == null) {
      ErrorHandler.showSnackBar(
        'Invalid PDF URL.',
        isError: true,
        context: context,
      );
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    final client = http.Client();
    IOSink? sink;
    File? file;
    try {
      final request = http.Request('GET', uri);
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Download failed');
      }

      file = await _buildDownloadFile();
      sink = file.openWrite();
      final totalBytes = response.contentLength ?? 0;
      var receivedBytes = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (!mounted) continue;
        if (totalBytes > 0) {
          setState(() {
            _downloadProgress = receivedBytes / totalBytes;
          });
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _downloadProgress = 1;
        _localFilePath = file!.path;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved to ${_savedDirectoryLabel ?? 'local storage'}: ${file.path}',
          ),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Open file',
            onPressed: () {
              if (!mounted) return;
              setState(() {});
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0;
      });
      ErrorHandler.showFromException(
        e,
        context: context,
        fallback: 'Failed to download this eBook.',
      );
    } finally {
      await sink?.flush();
      await sink?.close();
      if ((_localFilePath ?? '').isEmpty && file != null && await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      client.close();
    }
  }

  Widget _buildViewer() {
    final localFilePath = _localFilePath?.trim() ?? '';
    if (localFilePath.isNotEmpty) {
      return SfPdfViewer.file(File(localFilePath));
    }
    if (_trimmedPdfUrl.isEmpty) {
      return const Center(
        child: Text('PDF is not available.'),
      );
    }
    return SfPdfViewer.network(_trimmedPdfUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title.isNotEmpty ? widget.title : 'eBook Reader',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color(0xFF2D4F88),
        actions: [
          if (_trimmedPdfUrl.isNotEmpty)
            IconButton(
              onPressed: _isDownloading ? null : _downloadPdf,
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Download',
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isDownloading)
            LinearProgressIndicator(
              value: _downloadProgress > 0 ? _downloadProgress : null,
              minHeight: 3,
            ),
          Expanded(child: _buildViewer()),
        ],
      ),
    );
  }
}
