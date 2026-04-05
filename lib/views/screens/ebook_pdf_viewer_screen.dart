import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class EbookPdfViewerScreen extends StatefulWidget {
  final String title;
  final String pdfUrl;
  final bool isPreview;
  final int previewPageLimit;
  final VoidCallback? onUnlockRequested;

  const EbookPdfViewerScreen({
    super.key,
    required this.title,
    required this.pdfUrl,
    this.isPreview = false,
    this.previewPageLimit = 5,
    this.onUnlockRequested,
  });

  @override
  State<EbookPdfViewerScreen> createState() => _EbookPdfViewerScreenState();
}

class _EbookPdfViewerScreenState extends State<EbookPdfViewerScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();

  int _maxPreviewPage = 0;
  bool _isAdjustingPreviewPage = false;
  bool _showLockedOverlay = false;

  String get _trimmedPdfUrl => widget.pdfUrl.trim();
  bool get _isPreviewMode => widget.isPreview;
  int get _previewPageCount =>
      widget.previewPageLimit < 1 ? 1 : widget.previewPageLimit;

  Widget _buildViewer() {
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
      ),
      body: _isPreviewMode ? _buildPreviewViewer() : _buildViewer(),
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
                        'Buy the eBook to unlock the full PDF inside the app.',
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
