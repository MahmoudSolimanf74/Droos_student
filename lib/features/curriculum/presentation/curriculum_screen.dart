import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../auth/presentation/auth_state.dart';
import '../domain/curriculum_models.dart';
import 'curriculum_cubit.dart';
import 'curriculum_state.dart';

class CurriculumScreen extends StatefulWidget {
  const CurriculumScreen({super.key});

  @override
  State<CurriculumScreen> createState() => _CurriculumScreenState();
}

class _CurriculumScreenState extends State<CurriculumScreen> {
  final Set<String> _expandedUnits = {};
  int _selectedTab = 0; // 0: All online units, 1: Offline downloaded files only

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final authState = context.read<AuthCubit>().state;
    if (authState is Authenticated && authState.profile.gradeId != null) {
      context.read<CurriculumCubit>().loadCurriculum(authState.profile.gradeId!);
    } else {
      context.read<CurriculumCubit>().loadCurriculum('');
    }
  }

  void _toggleUnit(String unitId) {
    setState(() {
      if (_expandedUnits.contains(unitId)) {
        _expandedUnits.remove(unitId);
      } else {
        _expandedUnits.add(unitId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدروس والمذكرات الدراسية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _loadData,
          ),
        ],
      ),
      body: BlocBuilder<CurriculumCubit, CurriculumState>(
        builder: (context, state) {
          if (state is CurriculumLoading) {
            return const LoadingView(message: 'جاري تحميل الدروس والمذكرات...');
          }

          if (state is CurriculumError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off_rounded, color: AppColors.red, size: 48),
                  const SizedBox(height: 12),
                  Text(state.message, style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          if (state is CurriculumLoaded) {
            final isOfflineMode = state.isOffline;
            final offlineFiles = state.offlineFiles;

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                // Offline Notice Banner
                if (isOfflineMode) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off_rounded, color: Colors.amber, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'وضع أوفلاين (بدون إنترنت) - يتم عرض المذكرات المحفوظة على جهازك فقط',
                            style: AppTextStyles.bodySmall.copyWith(color: Colors.amber.shade200, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Online Tabs Filter: All vs Offline Only
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _selectedTab = 0),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedTab == 0 ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  'جميع المناهج (${state.units.length})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedTab == 0 ? Colors.black : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _selectedTab = 1),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedTab == 1 ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  'المحفوظة أوفلاين (${offlineFiles.length})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedTab == 1 ? Colors.black : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Display offline files when in offline mode OR tab 1 is selected
                if (isOfflineMode || _selectedTab == 1) ...[
                  if (offlineFiles.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            const Icon(Icons.cloud_off_rounded, color: AppColors.textFaint, size: 54),
                            const SizedBox(height: 14),
                            Text(
                              'لا توجد مذكرات محفوظة أوفلاين على هذا الجهاز بعد',
                              style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'اتصل بالإنترنت واضغط على زر التنزيل 📥 بجانب أي مذكرة لحفظها للمذاكرة أوفلاين.',
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textFaint),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...offlineFiles.map((file) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: _LessonFileTile(file: file),
                        )),
                ] else ...[
                  // Display standard units and lessons (Online tab 0)
                  if (state.units.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            const Icon(Icons.menu_book_rounded, color: AppColors.textFaint, size: 54),
                            const SizedBox(height: 14),
                            Text('لا توجد مذكرات أو دروس مضافة لمجموعتك بعد', style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    // Auto-expand all units initially if not yet initialized
                    Builder(
                      builder: (context) {
                        if (_expandedUnits.isEmpty && state.units.isNotEmpty) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && _expandedUnits.isEmpty) {
                              setState(() {
                                _expandedUnits.addAll(state.units.map((u) => u.id));
                              });
                            }
                          });
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    ...state.units.asMap().entries.map((entry) {
                      final unitIndex = entry.key;
                      final unit = entry.value;
                      final lessons = state.unitLessons[unit.id] ?? [];
                      final isExpanded = _expandedUnits.contains(unit.id);
                      final totalUnitFiles = lessons.fold<int>(0, (sum, l) => sum + (state.lessonFiles[l.id]?.length ?? 0));

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            // Unit Header
                            InkWell(
                              onTap: () => _toggleUnit(unit.id),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'الوحدة ${unitIndex + 1}',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            unit.title,
                                            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${lessons.length} دروس • $totalUnitFiles مذكرات وملفات',
                                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                      color: AppColors.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Lessons & Files List
                            if (isExpanded) ...[
                              const Divider(height: 1, color: AppColors.border),
                              if (lessons.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text('لا توجد دروس مضافة في هذه الوحدة بعد', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textFaint)),
                                )
                              else
                                ...lessons.asMap().entries.map((lessonEntry) {
                                  final lessonIndex = lessonEntry.key;
                                  final lesson = lessonEntry.value;
                                  final files = state.lessonFiles[lesson.id] ?? [];

                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'الدرس ${lessonIndex + 1}',
                                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  lesson.title,
                                                  style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                              if (files.isNotEmpty)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    '${files.length} ملفات',
                                                    style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (files.isEmpty)
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                                            child: Text('لا توجد ملفات مرفقة بهذا الدرس', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textFaint, fontSize: 10)),
                                          )
                                        else
                                          ...files.map((file) => _LessonFileTile(file: file)),
                                      ],
                                    ),
                                  );
                                }),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _LessonFileTile extends StatefulWidget {
  final LessonFileModel file;
  const _LessonFileTile({required this.file});

  @override
  State<_LessonFileTile> createState() => _LessonFileTileState();
}

class _LessonFileTileState extends State<_LessonFileTile> {
  bool _isDownloaded = false;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final fileName = widget.file.title.endsWith('.pdf') ? widget.file.title : '${widget.file.title}.pdf';
    final downloaded = await context.read<CurriculumCubit>().isFileDownloaded(fileName);
    if (mounted) {
      setState(() => _isDownloaded = downloaded);
    }
  }

  Future<void> _download() async {
    final cubit = context.read<CurriculumCubit>();
    final url = cubit.getFileUrl(widget.file.filePath);
    final fileName = widget.file.title.endsWith('.pdf') ? widget.file.title : '${widget.file.title}.pdf';

    setState(() => _isDownloading = true);
    try {
      await cubit.downloadFile(url, fileName);
      if (mounted) {
        setState(() {
          _isDownloaded = true;
          _isDownloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ "${widget.file.title}" بنجاح للاستخدام أوفلاين! 💾'),
            backgroundColor: AppColors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل التنزيل: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CurriculumCubit>();
    final url = cubit.getFileUrl(widget.file.filePath);

    return InkWell(
      onTap: () async {
        await context.push('/pdf-viewer', extra: {
          'title': widget.file.title,
          'url': url,
        });
        _checkStatus();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf_rounded, color: AppColors.red, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.file.title,
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '${(widget.file.fileSize / 1024).round()} KB',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
                      ),
                      if (_isDownloaded) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, color: AppColors.green, size: 12),
                              SizedBox(width: 3),
                              Text(
                                'محفوظ أوفلاين',
                                style: TextStyle(color: AppColors.green, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (_isDownloading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              )
            else if (!_isDownloaded)
              IconButton(
                icon: const Icon(Icons.file_download_outlined, color: AppColors.primary, size: 22),
                tooltip: 'تنزيل للمذاكرة بدون إنترنت',
                onPressed: _download,
              )
            else
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }
}
