import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
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
  String? _localFilePath;
  bool _isLoading = true;
  String? _errorMessage;
  int _totalPages = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _downloadAndOpen();
  }

  Future<void> _downloadAndOpen() async {
    final cubit = context.read<CurriculumCubit>();
    final fileName = widget.title.endsWith('.pdf') ? widget.title : '${widget.title}.pdf';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. If already a direct local file path
      if (!widget.url.startsWith('http://') && !widget.url.startsWith('https://')) {
        final localF = File(widget.url);
        if (await localF.exists() && await localF.length() > 0) {
          if (mounted) {
            setState(() {
              _localFilePath = widget.url;
              _isLoading = false;
            });
            return;
          }
        }
      }

      // 2. Check if already cached in offline directory
      final cachedPath = await cubit.getLocalFilePath(fileName);
      if (cachedPath != null) {
        final cachedF = File(cachedPath);
        if (await cachedF.exists() && await cachedF.length() > 0) {
          if (mounted) {
            setState(() {
              _localFilePath = cachedPath;
              _isLoading = false;
            });
            return;
          }
        }
      }

      // 3. If online, download from network
      final path = await cubit.downloadFile(widget.url, fileName);
      if (mounted) {
        setState(() {
          _localFilePath = path;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'عفواً، يرجى الاتصال بالإنترنت لتحميل هذا الملف لأول مرة';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: AppTextStyles.titleMedium),
        actions: [
          if (!_isLoading && _errorMessage == null)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.offline_pin_rounded, color: AppColors.green, size: 16),
                  SizedBox(width: 4),
                  Text('محفوظ أوفلاين', style: TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          if (_totalPages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '${_currentPage + 1} / $_totalPages',
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
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
      return const LoadingView(message: 'جاري فتح وتحميل ملف الـ PDF...');
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 48),
            const SizedBox(height: 12),
            Text(_errorMessage!, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _downloadAndOpen,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (_localFilePath == null) {
      return const Center(child: Text('تعذر تحميل الملف'));
    }

    return PDFView(
      filePath: _localFilePath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      pageSnap: true,
      backgroundColor: AppColors.background,
      onRender: (pages) {
        setState(() => _totalPages = pages ?? 0);
      },
      onPageChanged: (page, total) {
        setState(() {
          _currentPage = page ?? 0;
          _totalPages = total ?? 0;
        });
      },
      onError: (error) {
        setState(() => _errorMessage = error.toString());
      },
    );
  }
}
