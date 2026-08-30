import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/loading_view.dart';
import '../domain/exam_models.dart';
import 'exams_cubit.dart';
import 'exams_state.dart';

class TakeExamScreen extends StatefulWidget {
  final ExamModel exam;
  const TakeExamScreen({super.key, required this.exam});

  @override
  State<TakeExamScreen> createState() => _TakeExamScreenState();
}

class _TakeExamScreenState extends State<TakeExamScreen> {
  final Map<String, ShuffledOption> _selectedOptions = {}; // question_id -> ShuffledOption
  final Map<String, List<ShuffledOption>> _shuffledOptionsMap = {}; // question_id -> List<ShuffledOption>
  int _currentQuestionIndex = 0;
  Timer? _timer;
  late int _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.exam.durationMinutes * 60;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
        _submitExam(isAutoSubmit: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _submitExam({bool isAutoSubmit = false}) {
    _timer?.cancel();
    final List<Map<String, dynamic>> answersPayload = _selectedOptions.entries
        .map<Map<String, dynamic>>((e) => <String, dynamic>{
              'question_id': e.key,
              'selected_letter': e.value.originalLetter,
              'selected_option': e.value.text,
              'selected_index': e.value.originalIndex,
            })
        .toList();

    context.read<ExamsCubit>().submitExam(
          examId: widget.exam.id,
          answers: answersPayload,
        );
  }

  void _showSubmitConfirmation(int totalQuestions) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('تسليم الامتحان'),
        content: Text(
          'أجبت على ${_selectedOptions.length} من أصل $totalQuestions سؤال. هل أنت متأكد من تسليم الإجابات الآن؟',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('متابعة الحل'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.black),
            onPressed: () {
              Navigator.pop(ctx);
              _submitExam();
            },
            child: const Text('تأكيد التسليم'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExamsCubit, ExamsState>(
      listener: (context, state) {
        if (state is ExamCompletedState) {
          context.pushReplacement('/exam-result', extra: {
            'exam': widget.exam,
            'result': state.result,
          });
        }
      },
      builder: (context, state) {
        if (state is ExamsLoading || state is ExamSubmitting) {
          return Scaffold(
            body: LoadingView(
              message: state is ExamSubmitting ? 'جاري تصحيح وتسليم الإجابات...' : 'جاري فتح الامتحان...',
            ),
          );
        }

        if (state is ExamsError) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.exam.title)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: AppColors.red, size: 54),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      style: AppTextStyles.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة المحاولة'),
                      onPressed: () {
                        context.read<ExamsCubit>().startExam(widget.exam);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      child: const Text('العودة لقائمة الامتحانات'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (state is! ExamTakingLoaded) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.exam.title)),
            body: const Center(child: Text('عفواً، يرجى الاتصال بالإنترنت لبدء الامتحان')),
          );
        }

        final questions = state.questions;
        if (questions.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.exam.title)),
            body: const Center(child: Text('لا توجد أسئلة مسجلة في هذا الامتحان')),
          );
        }

        final currentQ = questions[_currentQuestionIndex];
        final isLast = _currentQuestionIndex == questions.length - 1;

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.exam.title, style: AppTextStyles.titleMedium),
            automaticallyImplyLeading: false,
            actions: [
              // Timer Display
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _remainingSeconds < 300 ? AppColors.red.withValues(alpha: 0.2) : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _remainingSeconds < 300 ? AppColors.red : AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 16, color: _remainingSeconds < 300 ? AppColors.red : AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      _formatTime(_remainingSeconds),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _remainingSeconds < 300 ? AppColors.red : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Progress indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'السؤال ${_currentQuestionIndex + 1} من ${questions.length}',
                        style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'درجات السؤال: ${currentQ.points}',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (_currentQuestionIndex + 1) / questions.length,
                    backgroundColor: AppColors.surface,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                  const SizedBox(height: 24),

                  // Question Card
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              currentQ.questionText,
                              style: AppTextStyles.titleMedium.copyWith(height: 1.5),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Options with A, B, C, D badges
                          ...(() {
                            final shuffledOpts = _shuffledOptionsMap.putIfAbsent(
                              currentQ.id,
                              () => currentQ.getMappedOptions(shuffle: true),
                            );

                            return shuffledOpts.asMap().entries.map((entry) {
                              final displayIdx = entry.key;
                              final shuffledOpt = entry.value;
                              const displayLetters = ['A', 'B', 'C', 'D', 'E', 'F'];
                              final displayLetter = displayIdx < displayLetters.length ? displayLetters[displayIdx] : '${displayIdx + 1}';
                              final isSelected = _selectedOptions[currentQ.id]?.originalLetter == shuffledOpt.originalLetter;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedOptions[currentQ.id] = shuffledOpt;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? AppColors.primary : AppColors.border,
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected ? AppColors.primary : AppColors.border,
                                              width: 1.5,
                                            ),
                                            color: isSelected ? AppColors.primary : AppColors.card,
                                          ),
                                          child: Center(
                                            child: Text(
                                              displayLetter,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected ? Colors.black : AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            shuffledOpt.text,
                                            style: AppTextStyles.bodyMedium.copyWith(
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(Icons.check_circle_rounded, size: 20, color: AppColors.primary),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            });
                          })(),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Navigation Buttons
                  Row(
                    children: [
                      if (_currentQuestionIndex > 0)
                        Expanded(
                          child: CustomButton(
                            text: 'السابق',
                            isOutlined: true,
                            onPressed: () {
                              setState(() => _currentQuestionIndex--);
                            },
                          ),
                        )
                      else
                        const Spacer(),
                      const SizedBox(width: 14),
                      Expanded(
                        child: CustomButton(
                          text: isLast ? 'تسليم الامتحان' : 'التالي',
                          backgroundColor: isLast ? AppColors.green : AppColors.primary,
                          textColor: Colors.black,
                          onPressed: () {
                            if (isLast) {
                              _showSubmitConfirmation(questions.length);
                            } else {
                              setState(() => _currentQuestionIndex++);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
