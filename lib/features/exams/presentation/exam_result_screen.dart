import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_button.dart';
import '../domain/exam_models.dart';

class ExamResultScreen extends StatelessWidget {
  final ExamModel exam;
  final ExamResultModel result;

  const ExamResultScreen({
    super.key,
    required this.exam,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final isPassed = result.passed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('نتيجة الامتحان'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Score Banner Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      (isPassed ? AppColors.green : AppColors.red).withValues(alpha: 0.2),
                      AppColors.surface,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isPassed ? AppColors.green : AppColors.red,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      isPassed ? Icons.emoji_events_rounded : Icons.highlight_off_rounded,
                      color: isPassed ? AppColors.green : AppColors.red,
                      size: 64,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isPassed ? 'مبروك! اجتزت الامتحان بنجاح 🎉' : 'للأسف لم تجتز الامتحان ⚠️',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: isPassed ? AppColors.green : AppColors.red,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'الدرجة: ${result.scorePercentage.toStringAsFixed(1)}%',
                      style: AppTextStyles.displayLarge.copyWith(fontSize: 32, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'حصلت على ${result.earnedPoints} من أصل ${result.totalPoints} نقطة (درجة النجاح: ${result.passingScore}%)',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Breakdown Header
              Text('مراجعة الإجابات النموذجية', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),

              // Answers Breakdown List
              ...result.breakdown.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final b = entry.value;
                final isCorrect = b['is_correct'] == true;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCorrect ? AppColors.green.withValues(alpha: 0.5) : AppColors.red.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            color: isCorrect ? AppColors.green : AppColors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text('السؤال $idx', style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text(
                            isCorrect ? '+${b['points_earned']} نقطة' : '0 نقطة',
                            style: TextStyle(
                              color: isCorrect ? AppColors.green : AppColors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text('إجابتك: ', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              b['selected_option'] != null && b['selected_option'].toString().isNotEmpty
                                  ? b['selected_option']
                                  : '(لم تتم الإجابة)',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: isCorrect ? AppColors.green : AppColors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!isCorrect) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('الإجابة الصحيحة: ', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.green)),
                            Expanded(
                              child: Text(
                                b['correct_answer'] ?? '',
                                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.green, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              }),
              CustomButton(
                text: 'العودة لقائمة الامتحانات والسجل',
                icon: Icons.quiz_outlined,
                onPressed: () => context.go('/exams'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.home_rounded, size: 18),
                label: const Text('الرئيسية'),
                onPressed: () => context.go('/dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
