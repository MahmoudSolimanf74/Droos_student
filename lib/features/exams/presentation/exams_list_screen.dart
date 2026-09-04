import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../auth/presentation/auth_state.dart';
import '../domain/exam_models.dart';
import 'exams_cubit.dart';
import 'exams_state.dart';

class ExamsListScreen extends StatefulWidget {
  const ExamsListScreen({super.key});

  @override
  State<ExamsListScreen> createState() => _ExamsListScreenState();
}

class _ExamsListScreenState extends State<ExamsListScreen> {
  int _selectedTab = 0; // 0: Exams, 1: History

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final auth = context.read<AuthCubit>().state;
    if (auth is Authenticated) {
      context.read<ExamsCubit>().loadExams(
            gradeId: auth.profile.gradeId ?? '',
            studentId: auth.profile.id,
          );
    }
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return '';
    final dt = DateTime.tryParse(dateVal.toString());
    if (dt == null) return dateVal.toString();
    try {
      return DateFormat('yyyy/MM/dd – hh:mm a', 'ar').format(dt.toLocal());
    } catch (_) {
      return dt.toString().split('.').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الامتحانات والاختبارات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _loadData,
          ),
        ],
      ),
      body: BlocBuilder<ExamsCubit, ExamsState>(
        builder: (context, state) {
          if (state is ExamsLoading) {
            return const LoadingView(message: 'جاري تحميل الامتحانات والسجل...');
          }

          if (state is ExamsError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 48),
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

          if (state is ExamsLoaded) {
            final exams = state.exams;
            final offlineExams = state.offlineExams;
            final attempts = state.attempts;
            final downloadedExamIds = state.downloadedExamIds;
            final isOfflineMode = state.isOffline;

            return Column(
              children: [
                // Offline Banner Notice (Shown only when disconnected)
                if (isOfflineMode)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade900.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off_rounded, color: Colors.amber, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'وضع أوفلاين (بدون إنترنت) - يتم عرض الامتحانات المحفوظة على جهازك',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.amber.shade200,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Top Tab Switcher (2 Tabs: Available Exams, History)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      // Tab 0: All Available Exams
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedTab == 0 ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.quiz_outlined,
                                  size: 15,
                                  color: _selectedTab == 0 ? Colors.black : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'الامتحانات المتاحة (${exams.length})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.normal,
                                      color: _selectedTab == 0 ? Colors.black : AppColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Tab 1: History / Attempts
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTab = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedTab == 1 ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  size: 15,
                                  color: _selectedTab == 1 ? Colors.black : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'سجل المحاولات (${attempts.length})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.normal,
                                      color: _selectedTab == 1 ? Colors.black : AppColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab Content
                Expanded(
                  child: _buildCurrentTabContent(
                    context,
                    exams: exams,
                    offlineExams: offlineExams,
                    attempts: attempts,
                    downloadedExamIds: downloadedExamIds,
                  ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildCurrentTabContent(
    BuildContext context, {
    required List<ExamModel> exams,
    required List<ExamModel> offlineExams,
    required List<Map<String, dynamic>> attempts,
    required Set<String> downloadedExamIds,
  }) {
    switch (_selectedTab) {
      case 0:
        return _buildExamsTab(context, exams, attempts, downloadedExamIds);
      case 1:
        return _buildHistoryTab(context, attempts, exams, offlineExams);
      default:
        return _buildExamsTab(context, exams, attempts, downloadedExamIds);
    }
  }

  Widget _buildExamsTab(
    BuildContext context,
    List<ExamModel> exams,
    List<Map<String, dynamic>> attempts,
    Set<String> downloadedExamIds,
  ) {
    if (exams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.quiz_outlined, color: AppColors.textFaint, size: 54),
            const SizedBox(height: 14),
            Text(
              'لا توجد امتحانات متاحة لمجموعتك حالياً',
              style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: exams.length,
      separatorBuilder: (context, i) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final exam = exams[i];
        final isDownloaded = downloadedExamIds.contains(exam.id);
        return _buildExamCard(context, exam, attempts, isDownloaded: isDownloaded);
      },
    );
  }

  void _confirmDeleteAttempt(BuildContext context, Map<String, dynamic> attempt, String examTitle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.red, size: 22),
            SizedBox(width: 8),
            Text('حذف سجل المحاولة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف سجل هذه المحاولة لامتحان "$examTitle"؟',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<ExamsCubit>().deleteAttempt(attempt);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم حذف سجل المحاولة بنجاح'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(
    BuildContext context,
    List<Map<String, dynamic>> attempts,
    List<ExamModel> exams,
    List<ExamModel> offlineExams,
  ) {
    if (attempts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.history_edu_rounded, color: AppColors.textFaint, size: 54),
              const SizedBox(height: 14),
              Text(
                'لم تقم بحل أي امتحانات بعد',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                'عند حل وتسليم أي امتحان، سيتم تسجيل نتيجتك وإجاباتك هنا لمراجعتها في أي وقت.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textFaint),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final allExamsMap = <String, ExamModel>{};
    for (final e in exams) {
      allExamsMap[e.id] = e;
    }
    for (final e in offlineExams) {
      allExamsMap.putIfAbsent(e.id, () => e);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: attempts.length,
      separatorBuilder: (context, i) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final attempt = attempts[i];
        final examId = attempt['exam_id']?.toString() ?? '';
        final matchedExam = allExamsMap[examId];

        String title = matchedExam?.title ?? '';
        if (title.isEmpty && attempt['exams'] is Map) {
          title = attempt['exams']['title']?.toString() ?? '';
        }
        if (title.isEmpty) {
          title = attempt['exam_title']?.toString() ?? 'امتحان تم حله';
        }

        final score = (attempt['score'] as num?)?.toDouble() ?? 0.0;
        final passingScore = matchedExam?.passingScore ??
            (attempt['exams'] is Map ? (attempt['exams']['passing_score'] as num?)?.toDouble() : null) ??
            50.0;
        final isPassed = score >= passingScore;
        final dateStr = attempt['submitted_at'] ?? attempt['started_at'];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPassed ? AppColors.green.withValues(alpha: 0.35) : AppColors.red.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isPassed ? AppColors.green : AppColors.red).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPassed ? Icons.emoji_events_rounded : Icons.highlight_off_rounded,
                      color: isPassed ? AppColors.green : AppColors.red,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        if (dateStr != null) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 12, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(dateStr),
                                style: AppTextStyles.bodySmall.copyWith(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Score & Delete Button Row
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isPassed ? AppColors.green : AppColors.red).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (isPassed ? AppColors.green : AppColors.red).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${score.toInt()}%',
                              style: TextStyle(
                                color: isPassed ? AppColors.green : AppColors.red,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              isPassed ? 'ناجح' : 'راسب',
                              style: TextStyle(
                                color: isPassed ? AppColors.green : AppColors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textSecondary, size: 20),
                        tooltip: 'حذف السجل',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () => _confirmDeleteAttempt(context, attempt, title),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 10),
              Row(
                children: [
                  // Button: Review Answers Breakdown Only
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.fact_check_rounded, size: 16),
                      label: const Text(
                        'مراجعة الإجابات والدرجات',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: () {
                        context.push('/attempt-details', extra: {
                          'attempt': attempt,
                          'exam': matchedExam,
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExamCard(
    BuildContext context,
    ExamModel exam,
    List<Map<String, dynamic>> attempts, {
    required bool isDownloaded,
  }) {
    // Chronologically first attempt is official
    final examAttempts = attempts.where((a) => a['exam_id'] == exam.id).toList();
    final firstAttempt = examAttempts.isNotEmpty ? examAttempts.last : null;

    final hasAttempted = firstAttempt != null;
    final score = hasAttempted ? (firstAttempt['score'] as num?)?.toDouble() ?? 0.0 : null;
    final isPassed = score != null && score >= exam.passingScore;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasAttempted
              ? (isPassed ? AppColors.green.withValues(alpha: 0.35) : AppColors.red.withValues(alpha: 0.35))
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.quiz_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.title,
                      style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    if (exam.description != null && exam.description!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(exam.description!, style: AppTextStyles.bodySmall.copyWith(fontSize: 11)),
                    ],
                  ],
                ),
              ),
              if (hasAttempted)
                InkWell(
                  onTap: () {
                    context.push('/attempt-details', extra: {
                      'attempt': firstAttempt,
                      'exam': exam,
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isPassed ? AppColors.green : AppColors.red).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: (isPassed ? AppColors.green : AppColors.red).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isPassed ? Icons.check_circle : Icons.cancel, size: 12, color: isPassed ? AppColors.green : AppColors.red),
                        const SizedBox(width: 4),
                        Text(
                          'النتيجة: ${score!.toInt()}%',
                          style: TextStyle(
                            color: isPassed ? AppColors.green : AppColors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Meta info badges & Offline status
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('${exam.durationMinutes} دقيقة', style: AppTextStyles.bodySmall.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.format_list_numbered_rounded, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('${exam.totalQuestions} أسئلة', style: AppTextStyles.bodySmall.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              if (hasAttempted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${examAttempts.length} محاولات',
                    style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              // Simple offline saved badge or save action
              if (isDownloaded)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.offline_pin_rounded, size: 13, color: AppColors.green),
                      const SizedBox(width: 4),
                      const Text(
                        'محفوظ أوفلاين',
                        style: TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () async {
                          await context.read<ExamsCubit>().deleteOfflineExam(exam);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم حذف النسخة المحفوظة أوفلاين')),
                            );
                          }
                        },
                        child: const Icon(Icons.close_rounded, size: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              else
                InkWell(
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('جاري تحميل وتجهيز أسئلة الامتحان للأوفلاين...'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                    try {
                      await context.read<ExamsCubit>().downloadExam(exam);
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('تم حفظ الامتحان بنجاح للحل بدون إنترنت! 📥'),
                          backgroundColor: AppColors.green,
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('فشل حفظ الامتحان: $e'),
                          backgroundColor: AppColors.red,
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download_rounded, size: 13, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'حفظ أوفلاين',
                          style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),

          // Action Buttons: View Exam (only if attempted) & Start / Retake Exam
          Row(
            children: [
              if (hasAttempted) ...[
                // Button 1: View / Preview Exam (Only for attempted exams)
                Expanded(
                  flex: 4,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 16, color: AppColors.primary),
                    label: const Text(
                      'عرض الامتحان',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    onPressed: () {
                      context.push('/exam-preview', extra: exam);
                    },
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Button 2: Start / Retake Exam
              Expanded(
                flex: hasAttempted ? 6 : 1,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasAttempted ? AppColors.surface : AppColors.primary,
                    foregroundColor: hasAttempted ? AppColors.textPrimary : Colors.black,
                    side: hasAttempted ? const BorderSide(color: AppColors.border) : BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: Icon(hasAttempted ? Icons.replay_rounded : Icons.play_arrow_rounded, size: 18),
                  label: Text(
                    hasAttempted ? 'إعادة للتمرين' : 'بدء الاختبار الآن',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: () {
                    context.read<ExamsCubit>().startExam(exam);
                    context.push('/take-exam', extra: exam);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
