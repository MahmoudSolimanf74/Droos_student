import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/exams_repository.dart';
import '../domain/exam_models.dart';
import 'exams_cubit.dart';

class ReviewQuestionItem {
  final int index;
  final String questionId;
  final String questionText;
  final List<ShuffledOption> options;
  final double points;
  final String studentLetter;
  final String studentText;
  final String correctLetter;
  final String correctText;
  final bool? isCorrect;
  final double pointsEarned;
  final bool answered;

  const ReviewQuestionItem({
    required this.index,
    required this.questionId,
    required this.questionText,
    required this.options,
    required this.points,
    required this.studentLetter,
    required this.studentText,
    required this.correctLetter,
    required this.correctText,
    required this.isCorrect,
    required this.pointsEarned,
    required this.answered,
  });
}

class ExamAttemptDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> attempt;
  final ExamModel? exam;

  const ExamAttemptDetailsScreen({
    super.key,
    required this.attempt,
    this.exam,
  });

  @override
  State<ExamAttemptDetailsScreen> createState() => _ExamAttemptDetailsScreenState();
}

class _ExamAttemptDetailsScreenState extends State<ExamAttemptDetailsScreen> {
  late Future<List<ReviewQuestionItem>> _reviewFuture;
  late double _score;
  late double _passingScore;
  late bool _isPassed;
  late String _examTitle;
  late String _examId;
  DateTime? _submittedDate;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    final a = widget.attempt;
    _score = (a['score'] as num?)?.toDouble() ?? 0.0;

    // Exam title resolution
    if (widget.exam != null) {
      _examTitle = widget.exam!.title;
      _passingScore = widget.exam!.passingScore;
      _examId = widget.exam!.id;
    } else if (a['exams'] is Map) {
      final eMap = a['exams'] as Map;
      _examTitle = eMap['title']?.toString() ?? 'امتحان';
      _passingScore = (eMap['passing_score'] as num?)?.toDouble() ?? 50.0;
      _examId = eMap['id']?.toString() ?? a['exam_id']?.toString() ?? '';
    } else {
      _examTitle = a['exam_title']?.toString() ?? 'امتحان';
      _passingScore = (a['passing_score'] as num?)?.toDouble() ?? 50.0;
      _examId = a['exam_id']?.toString() ?? '';
    }

    _isPassed = _score >= _passingScore;

    final dateStr = a['submitted_at']?.toString() ?? a['started_at']?.toString();
    if (dateStr != null) {
      _submittedDate = DateTime.tryParse(dateStr);
    }

    _reviewFuture = _resolveReviewQuestions();
  }

  String _normalize(dynamic val) {
    if (val == null) return '';
    var s = val.toString().trim().toLowerCase();
    s = s.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), ''); // Remove tashkeel
    s = s.replaceAll(RegExp(r'[إأآٱ]'), 'ا'); // Normalize alef
    s = s.replaceAll(RegExp(r'ة'), 'ه'); // Normalize taa marboota
    s = s.replaceAll(RegExp(r'[ىي]'), 'ي'); // Normalize yaa
    s = s.replaceAll(RegExp(r'\s+'), ' '); // Normalize spaces
    return s.trim();
  }

  String _resolveLetter(dynamic raw, List<String> options) {
    if (raw == null) return '';
    final str = raw.toString().trim();
    if (str.isEmpty) return '';

    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    final upper = str.toUpperCase();
    if (letters.contains(upper)) return upper;

    const arLetters = ['أ', 'ا', 'ب', 'ج', 'د', 'هـ', 'ه'];
    if (arLetters.contains(str)) {
      if (str == 'أ' || str == 'ا') return 'A';
      if (str == 'ب') return 'B';
      if (str == 'ج') return 'C';
      if (str == 'د') return 'D';
      if (str == 'هـ' || str == 'ه') return 'E';
    }

    final numVal = int.tryParse(str);
    if (numVal != null) {
      if (numVal >= 0 && numVal < letters.length) return letters[numVal];
      if (numVal >= 1 && numVal <= letters.length) return letters[numVal - 1];
    }

    if (options.isNotEmpty) {
      final normOpts = options.map((o) => _normalize(o)).toList();
      final idx = normOpts.indexOf(_normalize(str));
      if (idx >= 0 && idx < letters.length) {
        return letters[idx];
      }
    }

    return upper;
  }

  Future<List<ReviewQuestionItem>> _resolveReviewQuestions() async {
    final a = widget.attempt;
    var rawAnswers = a['breakdown'] ?? a['answers'];

    if (rawAnswers is String) {
      try {
        rawAnswers = jsonDecode(rawAnswers);
      } catch (_) {}
    }

    List<Map<String, dynamic>> breakdownList = [];
    if (rawAnswers is List) {
      breakdownList = rawAnswers.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    // 1. Fetch exam questions from repository (cached or remote)
    List<ExamQuestionModel> questions = [];
    if (_examId.isNotEmpty) {
      try {
        final repo = context.read<ExamsRepository>();
        questions = await repo.getExamQuestions(_examId);
      } catch (_) {}
    }

    final List<ReviewQuestionItem> result = [];

    if (questions.isNotEmpty) {
      for (int i = 0; i < questions.length; i++) {
        final q = questions[i];
        final qOptions = q.getMappedOptions(shuffle: false);
        final rawOptionsList = q.options;

        // Lookup matching student breakdown item
        Map<String, dynamic>? match;
        for (final b in breakdownList) {
          if (b['question_id']?.toString() == q.id) {
            match = b;
            break;
          }
        }
        if (match == null && i < breakdownList.length) {
          match = breakdownList[i];
        }

        String studentText = match?['selected_option']?.toString() ?? '';
        String studentLetter = match?['selected_letter']?.toString() ?? '';
        if (studentLetter.isEmpty && studentText.isNotEmpty) {
          studentLetter = _resolveLetter(studentText, rawOptionsList);
        }

        final bool answered = studentText.isNotEmpty && studentText != 'لم تتم الإجابة' && studentText != '(لم تتم الإجابة)';
        final correctText = q.correctAnswer ?? match?['correct_answer']?.toString() ?? '';
        final correctLetter = q.correctLetter.isNotEmpty ? q.correctLetter : _resolveLetter(correctText, rawOptionsList);

        bool? isCorrect;
        if (match != null && match['is_correct'] != null) {
          isCorrect = match['is_correct'] == true;
        } else if (answered) {
          if (studentLetter.isNotEmpty && correctLetter.isNotEmpty) {
            isCorrect = studentLetter == correctLetter;
          } else {
            isCorrect = _normalize(studentText) == _normalize(correctText);
          }
        } else {
          isCorrect = false;
        }

        final pointsEarned = match?['points_earned'] != null
            ? (match!['points_earned'] as num).toDouble()
            : (isCorrect == true ? q.points : 0.0);

        result.add(ReviewQuestionItem(
          index: i + 1,
          questionId: q.id,
          questionText: q.questionText,
          options: qOptions,
          points: q.points,
          studentLetter: studentLetter,
          studentText: studentText,
          correctLetter: correctLetter,
          correctText: correctText,
          isCorrect: isCorrect,
          pointsEarned: pointsEarned,
          answered: answered,
        ));
      }
      return result;
    }

    // Fallback: If questions list could not be loaded, build from breakdown
    for (int i = 0; i < breakdownList.length; i++) {
      final b = breakdownList[i];
      final qId = b['question_id']?.toString() ?? 'q_$i';
      final qText = b['question_text']?.toString() ?? 'سؤال ${i + 1}';
      final studentText = b['selected_option']?.toString() ?? '';
      final studentLetter = b['selected_letter']?.toString() ?? '';
      final correctText = b['correct_answer']?.toString() ?? '';
      final correctLetter = b['correct_letter']?.toString() ?? '';
      final isCorrect = b['is_correct'] as bool?;
      final pointsEarned = (b['points_earned'] as num?)?.toDouble() ?? (isCorrect == true ? 1.0 : 0.0);
      final bool answered = studentText.isNotEmpty && studentText != 'لم تتم الإجابة' && studentText != '(لم تتم الإجابة)';

      List<ShuffledOption> mappedOptions = [];
      if (b['options'] is List) {
        final rawOpts = (b['options'] as List).map((e) => e.toString()).toList();
        const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
        for (int optIdx = 0; optIdx < rawOpts.length; optIdx++) {
          final l = optIdx < letters.length ? letters[optIdx] : '${optIdx + 1}';
          mappedOptions.add(ShuffledOption(
            text: rawOpts[optIdx],
            originalLetter: l,
            originalIndex: optIdx,
          ));
        }
      }

      result.add(ReviewQuestionItem(
        index: i + 1,
        questionId: qId,
        questionText: qText,
        options: mappedOptions,
        points: 1.0,
        studentLetter: studentLetter,
        studentText: studentText,
        correctLetter: correctLetter,
        correctText: correctText,
        isCorrect: isCorrect,
        pointsEarned: pointsEarned,
        answered: answered,
      ));
    }

    return result;
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    try {
      final local = dt.toLocal();
      return DateFormat('yyyy/MM/dd – hh:mm a', 'ar').format(local);
    } catch (_) {
      return dt.toString().split('.').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مراجعة الامتحان والإجابات'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Score Banner Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      (_isPassed ? AppColors.green : AppColors.red).withValues(alpha: 0.2),
                      AppColors.surface,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isPassed ? AppColors.green : AppColors.red,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _isPassed ? Icons.emoji_events_rounded : Icons.highlight_off_rounded,
                      color: _isPassed ? AppColors.green : AppColors.red,
                      size: 54,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _examTitle,
                      style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isPassed ? 'تم اجتياز الامتحان بنجاح 🎉' : 'لم يتم اجتياز درجة النجاح ⚠️',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: _isPassed ? AppColors.green : AppColors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_score.toStringAsFixed(1)}%',
                      style: AppTextStyles.displayLarge.copyWith(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: _isPassed ? AppColors.green : AppColors.red,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'درجة النجاح المطلوبة: ${_passingScore.toInt()}%',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                    if (_submittedDate != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.access_time_rounded, size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(_submittedDate),
                            style: AppTextStyles.bodySmall.copyWith(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Breakdown Section Header
              Row(
                children: [
                  const Icon(Icons.quiz_outlined, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'عرض الأسئلة والإجابات',
                    style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Questions List (Exact Exam Format with Color Coding)
              FutureBuilder<List<ReviewQuestionItem>>(
                future: _reviewFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: LoadingView(message: 'جاري تجهيز أسئلة الامتحان والمراجعة...'),
                    );
                  }

                  final questions = snapshot.data ?? [];

                  if (questions.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Center(
                        child: Text(
                          'تم تسجيل نتيجتك بنجاح دون تخزين تفاصيل الأسئلة لهذه المحاولة.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: questions.map((item) => _buildReviewQuestionCard(item)).toList(),
                  );
                },
              ),

              const SizedBox(height: 16),
              // Action Buttons
              if (widget.exam != null)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text(
                    'إعادة الاختبار للتدريب والتمرين',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () {
                    context.read<ExamsCubit>().startExam(widget.exam!);
                    context.push('/take-exam', extra: widget.exam!);
                  },
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('العودة لقائمة الامتحانات'),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewQuestionCard(ReviewQuestionItem item) {
    final bool isCorrect = item.isCorrect == true;
    final bool hasAnswered = item.answered;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isCorrect != null
              ? (isCorrect ? AppColors.green.withValues(alpha: 0.4) : AppColors.red.withValues(alpha: 0.4))
              : AppColors.border,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Question number & Result/Points Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'السؤال ${item.index}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const Spacer(),
              if (item.isCorrect != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isCorrect ? AppColors.green : AppColors.red).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isCorrect ? AppColors.green : AppColors.red).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        size: 13,
                        color: isCorrect ? AppColors.green : AppColors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isCorrect ? 'إجابة صحيحة (+${item.pointsEarned.toInt()} درجة)' : 'إجابة خاطئة (0 درجة)',
                        style: TextStyle(
                          color: isCorrect ? AppColors.green : AppColors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '${item.points.toInt()} درجات',
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Question Text Box (Styled like exam)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            ),
            child: Text(
              item.questionText,
              style: AppTextStyles.titleSmall.copyWith(
                height: 1.5,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Options List (A, B, C, D) with Color Coding
          if (item.options.isNotEmpty)
            ...item.options.map((opt) {
              final optLetter = opt.originalLetter.toUpperCase();
              final optTextNorm = _normalize(opt.text);

              // 1. Is this option the student's chosen answer?
              final bool isStudentChoice = hasAnswered &&
                  (optLetter == item.studentLetter.toUpperCase() ||
                      optTextNorm == _normalize(item.studentText) ||
                      _normalize(item.studentText).startsWith(optTextNorm));

              // 2. Is this option the correct answer?
              final bool isCorrectOption = optLetter == item.correctLetter.toUpperCase() ||
                  optTextNorm == _normalize(item.correctText) ||
                  _normalize(item.correctText).startsWith(optTextNorm) ||
                  _normalize(item.correctText).endsWith(optTextNorm);

              // Styling states
              Color bgColor = AppColors.surface;
              Color borderColor = AppColors.border;
              double borderWidth = 1.0;
              Color textColor = AppColors.textPrimary;
              FontWeight textWeight = FontWeight.normal;
              Widget? statusBadge;
              Color circleBg = AppColors.card;
              Color circleBorder = AppColors.border;
              Widget circleContent = Text(
                opt.originalLetter,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              );

              if (isStudentChoice) {
                if (isCorrect) {
                  // Student choice is correct -> Green
                  bgColor = AppColors.green.withValues(alpha: 0.15);
                  borderColor = AppColors.green;
                  borderWidth = 2.0;
                  textColor = AppColors.green;
                  textWeight = FontWeight.bold;
                  circleBg = AppColors.green;
                  circleBorder = AppColors.green;
                  circleContent = const Icon(Icons.check_rounded, color: Colors.black, size: 16);
                  statusBadge = Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.green.withValues(alpha: 0.5)),
                    ),
                    child: const Text(
                      'إجابتك (صحيحة) ✓',
                      style: TextStyle(color: AppColors.green, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  );
                } else {
                  // Student choice is WRONG -> Red
                  bgColor = AppColors.red.withValues(alpha: 0.15);
                  borderColor = AppColors.red;
                  borderWidth = 2.0;
                  textColor = AppColors.red;
                  textWeight = FontWeight.bold;
                  circleBg = AppColors.red;
                  circleBorder = AppColors.red;
                  circleContent = const Icon(Icons.close_rounded, color: Colors.white, size: 16);
                  statusBadge = Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.red.withValues(alpha: 0.5)),
                    ),
                    child: const Text(
                      'إجابتك (خاطئة) ✗',
                      style: TextStyle(color: AppColors.red, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  );
                }
              } else if (isCorrectOption) {
                // Correct answer marked in Green (when student didn't choose it or got it wrong)
                bgColor = AppColors.green.withValues(alpha: 0.15);
                borderColor = AppColors.green;
                borderWidth = 2.0;
                textColor = AppColors.green;
                textWeight = FontWeight.bold;
                circleBg = AppColors.green;
                circleBorder = AppColors.green;
                circleContent = const Icon(Icons.check_rounded, color: Colors.black, size: 16);
                statusBadge = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.green.withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    'الإجابة الصحيحة ✓',
                    style: TextStyle(color: AppColors.green, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                );
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor, width: borderWidth),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: circleBg,
                        border: Border.all(color: circleBorder),
                      ),
                      child: Center(child: circleContent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        opt.text,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: textColor,
                          fontWeight: textWeight,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (statusBadge != null) ...[
                      const SizedBox(width: 8),
                      statusBadge,
                    ],
                  ],
                ),
              );
            })
          else ...[
            // Fallback if options list was not available
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCorrect ? AppColors.green.withValues(alpha: 0.1) : AppColors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isCorrect ? AppColors.green : AppColors.red),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          size: 16, color: isCorrect ? AppColors.green : AppColors.red),
                      const SizedBox(width: 6),
                      Text('إجابتك: ${hasAnswered ? item.studentText : "(لم تتم الإجابة)"}',
                          style: TextStyle(color: isCorrect ? AppColors.green : AppColors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (!isCorrect && item.correctText.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.green),
                        const SizedBox(width: 6),
                        Text('الإجابة الصحيحة: ${item.correctText}',
                            style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Unanswered notice
          if (!hasAnswered)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded, size: 13, color: AppColors.textSecondary),
                  SizedBox(width: 5),
                  Text(
                    'لم تقم باختيار إجابة لهذا السؤال أثناء الامتحان',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

