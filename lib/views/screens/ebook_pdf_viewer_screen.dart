import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../core/error/error_handler.dart';

class EbookPdfViewerScreen extends StatefulWidget {
  final String title;
  final String pdfUrl;
  final String? localFilePath;
  final bool isPreview;
  final int previewPageLimit;
  final VoidCallback? onUnlockRequested;

  const EbookPdfViewerScreen({
    super.key,
    required this.title,
    required this.pdfUrl,
    this.localFilePath,
    this.isPreview = false,
    this.previewPageLimit = 5,
    this.onUnlockRequested,
  });

  @override
  State<EbookPdfViewerScreen> createState() => _EbookPdfViewerScreenState();
}

class _EbookPdfViewerScreenState extends State<EbookPdfViewerScreen> {
  static const MethodChannel _downloadChannel = MethodChannel(
    'com.ej.khalid/downloads',
  );
  final PdfViewerController _pdfViewerController = PdfViewerController();

  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _localFilePath;
  String? _savedDirectoryLabel;
  int _maxPreviewPage = 0;
  bool _isAdjustingPreviewPage = false;
  bool _showLockedOverlay = false;

  String get _trimmedPdfUrl => widget.pdfUrl.trim();
  bool get _isPreviewMode => widget.isPreview;
  int get _previewPageCount =>
      widget.previewPageLimit < 1 ? 1 : widget.previewPageLimit;
  String get _sanitizedFileName {
    final fileName = widget.title
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    return fileName.isEmpty ? 'ebook' : fileName;
  }

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

    return File(
      '${ebookDirectory.path}${Platform.pathSeparator}$_sanitizedFileName.pdf',
    );
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
    if (_isPreviewMode || _isDownloading || _trimmedPdfUrl.isEmpty) return;

    final uri = Uri.tryParse(_trimmedPdfUrl);
    if (uri == null) {
      ErrorHandler.showSnackBar(
        'Invalid PDF URL.',
        isError: true,
        context: context,
      );
      return;
    }

    if (Platform.isAndroid) {
      await _downloadPdfOnAndroid(uri);
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
      if ((_localFilePath ?? '').isEmpty &&
          file != null &&
          await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      client.close();
    }
  }

  Future<void> _downloadPdfOnAndroid(Uri uri) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    try {
      final response = await _downloadChannel.invokeMapMethod<String, dynamic>(
        'downloadPdfToDownloads',
        {'url': uri.toString(), 'fileName': _sanitizedFileName},
      );

      if (!mounted) return;
      setState(() {
        _isDownloading = false;
      });

      final savedFolder = response?['relativePath']?.toString() ?? 'Downloads';
      final savedFileName =
          response?['fileName']?.toString() ?? '$_sanitizedFileName.pdf';
      final savedPath =
          response?['path']?.toString() ?? '$savedFolder/$savedFileName';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to $savedPath'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('PDF download PlatformException');
      debugPrint('  code: ${e.code}');
      debugPrint('  message: ${e.message}');
      debugPrint('  details: ${e.details}');
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
      });
      ErrorHandler.showSnackBar(
        e.message ?? 'Failed to save PDF to Downloads.',
        isError: true,
        context: context,
      );
    } catch (e) {
      debugPrint('PDF download error: $e');
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
      });
      ErrorHandler.showFromException(
        e,
        context: context,
        fallback: 'Failed to save PDF to Downloads.',
      );
    }
  }

  Widget _buildViewer() {
    final localFilePath = _localFilePath?.trim() ?? '';
    if (localFilePath.isNotEmpty) {
      return SfPdfViewer.file(
        File(localFilePath),
        controller: _pdfViewerController,
        onDocumentLoaded: _handleDocumentLoaded,
        onPageChanged: _handlePageChanged,
      );
    }
    if (_trimmedPdfUrl.isEmpty) {
      return const Center(child: Text('PDF is not available.'));
    }
    return SfPdfViewer.network(
      _trimmedPdfUrl,
      controller: _pdfViewerController,
      onDocumentLoaded: _handleDocumentLoaded,
      onPageChanged: _handlePageChanged,
    );
  }

  void _handleDocumentLoaded(PdfDocumentLoadedDetails details) {
    if (!_isPreviewMode) return;

    final pageCount = details.document.pages.count;
    final resolvedLimit = _previewPageCount.clamp(1, pageCount);

    if (!mounted) return;
    setState(() {
      _maxPreviewPage = resolvedLimit;
    });
  }

  void _handlePageChanged(PdfPageChangedDetails details) {
    if (!_isPreviewMode || _maxPreviewPage <= 0 || _isAdjustingPreviewPage) {
      return;
    }

    if (details.newPageNumber <= _maxPreviewPage) {
      if (_showLockedOverlay && mounted) {
        setState(() {
          _showLockedOverlay = false;
        });
      }
      return;
    }

    _isAdjustingPreviewPage = true;
    _pdfViewerController.jumpToPage(_maxPreviewPage);

    if (mounted) {
      setState(() {
        _showLockedOverlay = true;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isAdjustingPreviewPage = false;
    });
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
          if (_trimmedPdfUrl.isNotEmpty && !_isPreviewMode)
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
          Expanded(
            child: _isPreviewMode ? _buildPreviewViewer() : _buildViewer(),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewViewer() {
    return Stack(
      children: [
        Positioned.fill(child: _buildViewer()),
        if (_showLockedOverlay) Positioned.fill(child: _buildLockedOverlay()),
      ],
    );
  }

  Widget _buildLockedOverlay() {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.white.withValues(alpha: 0.18)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.84),
                ],
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFDCE7F7)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 34,
                        color: Color(0xFF10213F),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Only the first $_maxPreviewPage pages are available in preview.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF10213F),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Buy the eBook to unlock the full PDF and download it to your device.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF475569),
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _showLockedOverlay = false;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10213F),
                            side: const BorderSide(color: Color(0xFFD8E3F5)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Continue Preview'),
                        ),
                      ),
                      if (widget.onUnlockRequested != null) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onUnlockRequested!.call();
                            },
                            icon: const Icon(
                              Icons.shopping_bag_outlined,
                              size: 18,
                            ),
                            label: const Text('Buy This eBook'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10213F),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
