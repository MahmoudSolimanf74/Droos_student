import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/loading_view.dart';
import 'curriculum_cubit.dart';

class PdfViewerScreen extends StatefulWidget {
  final String title;
  final String url;

  const PdfViewerScreen({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final PdfViewerController _controller = PdfViewerController();
  String? _localFilePath;
  bool _isLoading = true;
  String? _errorMessage;
  int _totalPages = 0;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _initPdf();
  }

  Future<void> _initPdf() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // If Web, we can directly load via URL or let pdfrx load URI
    if (kIsWeb) {
      setState(() {
        _localFilePath = null;
        _isLoading = false;
      });
      return;
    }

    // On Native (Mobile / Desktop): Check local file or cache
    final cubit = context.read<CurriculumCubit>();
    final fileName = widget.title.endsWith('.pdf') ? widget.title : '${widget.title}.pdf';

    try {
      String? rawPath;

      // 1. Direct local path passed in url
      if (!widget.url.startsWith('http://') && !widget.url.startsWith('https://')) {
        final localF = File(widget.url);
        if (await localF.exists() && await localF.length() > 0) {
          rawPath = widget.url;
        }
      }

      // 2. Check local offline cache
      if (rawPath == null) {
        final cached = await cubit.getLocalFilePath(fileName);
        if (cached != null && await File(cached).exists() && (await File(cached).length() > 0)) {
          rawPath = cached;
        }
      }

      // 3. Download if online URL
      if (rawPath == null &&
          (widget.url.startsWith('http://') || widget.url.startsWith('https://'))) {
        rawPath = await cubit.downloadFile(widget.url, fileName);
      }

      if (rawPath != null && mounted) {
        final sourceFile = File(rawPath);
        final tempDir = await getTemporaryDirectory();
        final safeName = 'doc_${fileName.hashCode.abs()}.pdf';
        final safeFile = File('${tempDir.path}/$safeName');

        if (!await safeFile.exists() || (await safeFile.length()) != (await sourceFile.length())) {
          await sourceFile.copy(safeFile.path);
        }

        setState(() {
          _localFilePath = safeFile.path;
          _isLoading = false;
        });
      } else if (widget.url.startsWith('http://') || widget.url.startsWith('https://')) {
        // Fallback: Use direct remote URI if local copy failed
        setState(() {
          _localFilePath = null;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _errorMessage = 'تعذر العثور على ملف الـ PDF أو تحميله.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ أثناء إعداد الملف: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.title, style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          if (_totalPages > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '$_currentPage / $_totalPages',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingView(message: 'جاري تحميل وتجهيز ملف الـ PDF...');
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 48),
              const SizedBox(height: 12),
              Text(_errorMessage!, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _initPdf,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final params = PdfViewerParams(
      margin: 8,
      backgroundColor: AppColors.background,
      onDocumentChanged: (document) {
        if (mounted && document != null) {
          setState(() {
            _totalPages = document.pages.length;
          });
        }
      },
      onPageChanged: (pageNumber) {
        if (mounted && pageNumber != null) {
          setState(() {
            _currentPage = pageNumber;
          });
        }
      },
      loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
        return const Center(
          child: LoadingView(message: 'جاري عرض صفحات الـ PDF...'),
        );
      },
      errorBannerBuilder: (context, error, stackTrace, documentRef) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image_outlined, color: AppColors.red, size: 40),
                const SizedBox(height: 10),
                Text('تعذر عرض الـ PDF: $error', style: const TextStyle(color: AppColors.red), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _initPdf,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        );
      },
    );

    // If we have a local file path (Mobile / Desktop)
    if (_localFilePath != null) {
      return PdfViewer.file(
        _localFilePath!,
        controller: _controller,
        params: params,
      );
    }

    // Direct Uri fallback (Web / Online)
    return PdfViewer.uri(
      Uri.parse(widget.url),
      controller: _controller,
      params: params,
    );
  }
}

