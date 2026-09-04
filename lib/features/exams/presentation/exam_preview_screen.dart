import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/exams_repository.dart';
import '../domain/exam_models.dart';
import 'exams_cubit.dart';

class ExamPreviewScreen extends StatefulWidget {
  final ExamModel exam;

  const ExamPreviewScreen({super.key, required this.exam});

  @override
  State<ExamPreviewScreen> createState() => _ExamPreviewScreenState();
}

class _ExamPreviewScreenState extends State<ExamPreviewScreen> {
  late Future<List<ExamQuestionModel>> _questionsFuture;
  bool _showCorrectAnswers = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  void _loadQuestions() {
    final repo = context.read<ExamsRepository>();
    setState(() {
      _questionsFuture = repo.getExamQuestions(widget.exam.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exam.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _loadQuestions,
          ),
        ],
      ),
      body: FutureBuilder<List<ExamQuestionModel>>(
        future: _questionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'جاري تحميل أسئلة الامتحان بالترتيب...');
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 52),
                    const SizedBox(height: 14),
                    Text(
                      snapshot.error.toString().replaceAll('Exception:', '').trim(),
                      style: AppTextStyles.titleSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة المحاولة'),
                      onPressed: _loadQuestions,
                    ),
                  ],
                ),
              ),
            );
          }

          final questions = snapshot.data ?? [];
          if (questions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.quiz_outlined, color: AppColors.textFaint, size: 54),
                  const SizedBox(height: 12),
                  Text(
                    'لا توجد أسئلة مضافة لهذا الامتحان حالياً',
                    style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Top Sticky Banner for Exam Info & Answers Toggle Switch
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppColors.card,
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.visibility_rounded, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'معاينة واستعراض الامتحان (مرتب)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                '${questions.length} أسئلة مرتبة حسب تسلسل المعلم',
                                style: AppTextStyles.bodySmall.copyWith(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        // Show / Hide Correct Answers Switch
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _showCorrectAnswers
                                ? AppColors.green.withValues(alpha: 0.15)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _showCorrectAnswers ? AppColors.green : AppColors.border,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _showCorrectAnswers ? Icons.check_circle_rounded : Icons.lightbulb_outline_rounded,
                                size: 16,
                                color: _showCorrectAnswers ? AppColors.green : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _showCorrectAnswers ? 'إخفاء الإجابات' : 'عرض الإجابات',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _showCorrectAnswers ? AppColors.green : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Switch(
                                value: _showCorrectAnswers,
                                activeThumbColor: AppColors.green,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onChanged: (val) {
                                  setState(() => _showCorrectAnswers = val);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (widget.exam.description != null && widget.exam.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.exam.description!.trim(),
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),

              // Questions List (Strictly in original order)
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                  itemCount: questions.length,
                  separatorBuilder: (context, i) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final q = questions[index];
                    return _buildQuestionCard(index + 1, q);
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text(
                    'بدء حل الامتحان الآن',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: () {
                    context.read<ExamsCubit>().startExam(widget.exam);
                    context.push('/take-exam', extra: widget.exam);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int questionNumber, ExamQuestionModel q) {
    // Keep options strictly in original order (shuffle = false)
    final options = q.getMappedOptions(shuffle: false);
    final correctLetter = q.correctLetter;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Question number & Points
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'السؤال $questionNumber',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '${q.points} درجة',
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Question Text
          Text(
            q.questionText,
            style: AppTextStyles.titleSmall.copyWith(
              height: 1.5,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 14),

          // Options List (strictly in original order A, B, C, D)
          ...options.map((opt) {
            final isCorrect = _showCorrectAnswers &&
                (opt.originalLetter == correctLetter ||
                    opt.text.trim().toLowerCase() == (q.correctAnswer ?? '').trim().toLowerCase());

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isCorrect ? AppColors.green.withValues(alpha: 0.15) : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCorrect ? AppColors.green : AppColors.border,
                  width: isCorrect ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCorrect ? AppColors.green : AppColors.card,
                      border: Border.all(
                        color: isCorrect ? AppColors.green : AppColors.border,
                      ),
                    ),
                    child: Center(
                      child: isCorrect
                          ? const Icon(Icons.check_rounded, color: Colors.black, size: 16)
                          : Text(
                              opt.originalLetter,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      opt.text,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isCorrect ? AppColors.green : AppColors.textPrimary,
                        fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (isCorrect) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'الإجابة الصحيحة',
                        style: TextStyle(
                          color: AppColors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
