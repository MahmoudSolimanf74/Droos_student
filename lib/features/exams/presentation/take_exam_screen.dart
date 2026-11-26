import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  // Answers states per question key
  final Map<String, ShuffledOption> _selectedOptions = {}; // For MCQ
  final Map<String, String> _textAnswers = {}; // For True/False, FillBlank, Essay, ShortAnswer
  final Map<String, Map<String, String>> _matchingAnswers = {}; // For Matching: qKey -> { left: right }
  final Map<String, String?> _selectedLeftItem = {}; // Temporary selection for matching

  final Map<String, List<ShuffledOption>> _shuffledOptionsMap = {};
  final Map<String, TextEditingController> _textControllers = {};

  int _currentQuestionIndex = 0;
  Timer? _timer;
  late int _remainingSeconds;
  bool _draftLoaded = false;
  List<ExamQuestionModel> _lastQuestions = [];

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
        if (_lastQuestions.isNotEmpty) {
          _submitExam(questions: _lastQuestions, isAutoSubmit: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getTextController(String key, {String initialText = ''}) {
    return _textControllers.putIfAbsent(key, () {
      final ctrl = TextEditingController(text: initialText);
      ctrl.addListener(() {
        _textAnswers[key] = ctrl.text;
        _saveDraftAnswers();
      });
      return ctrl;
    });
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _getQuestionKey(ExamQuestionModel q, int index) {
    if (q.id.trim().isNotEmpty) return q.id.trim();
    return 'q_${index}_${q.questionText.trim().hashCode.abs()}';
  }

  bool _isQuestionAnswered(ExamQuestionModel q, int index) {
    final key = _getQuestionKey(q, index);
    switch (q.type) {
      case QuestionType.mcq:
        return _selectedOptions.containsKey(key) || (q.id.isNotEmpty && _selectedOptions.containsKey(q.id));
      case QuestionType.trueFalse:
      case QuestionType.fillBlank:
      case QuestionType.essay:
      case QuestionType.shortAnswer:
        final txt = _textAnswers[key] ?? (q.id.isNotEmpty ? _textAnswers[q.id] : null);
        return txt != null && txt.trim().isNotEmpty;
      case QuestionType.matching:
        final pairs = _matchingAnswers[key] ?? (q.id.isNotEmpty ? _matchingAnswers[q.id] : null);
        return pairs != null && pairs.length == q.matchingPairs.length && pairs.isNotEmpty;
    }
  }

  Future<void> _saveDraftAnswers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftMap = <String, dynamic>{
        'mcq': {},
        'text': _textAnswers,
        'matching': _matchingAnswers,
      };

      for (final entry in _selectedOptions.entries) {
        (draftMap['mcq'] as Map)[entry.key] = {
          'text': entry.value.text,
          'originalLetter': entry.value.originalLetter,
          'originalIndex': entry.value.originalIndex,
        };
      }
      await prefs.setString('exam_draft_answers_v2_${widget.exam.id}', jsonEncode(draftMap));
    } catch (_) {}
  }

  Future<void> _loadDraftAnswers(List<ExamQuestionModel> questions) async {
    if (_draftLoaded) return;
    _draftLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('exam_draft_answers_v2_${widget.exam.id}');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        bool hasChanges = false;

        // Restore MCQ
        final mcqData = decoded['mcq'];
        if (mcqData is Map) {
          for (int i = 0; i < questions.length; i++) {
            final q = questions[i];
            final key = _getQuestionKey(q, i);
            dynamic optData = mcqData[key] ?? (q.id.isNotEmpty ? mcqData[q.id] : null);
            if (optData is Map) {
              final opt = ShuffledOption(
                text: optData['text']?.toString() ?? '',
                originalLetter: optData['originalLetter']?.toString() ?? 'A',
                originalIndex: (optData['originalIndex'] as num?)?.toInt() ?? 0,
              );
              _selectedOptions[key] = opt;
              if (q.id.isNotEmpty) _selectedOptions[q.id] = opt;
              hasChanges = true;
            }
          }
        }

        // Restore Text (True/False, FillBlank, Essay, ShortAnswer)
        final txtData = decoded['text'];
        if (txtData is Map) {
          for (final entry in txtData.entries) {
            _textAnswers[entry.key] = entry.value.toString();
            final ctrl = _textControllers[entry.key];
            if (ctrl != null) ctrl.text = entry.value.toString();
          }
          hasChanges = true;
        }

        // Restore Matching
        final matchData = decoded['matching'];
        if (matchData is Map) {
          for (final entry in matchData.entries) {
            if (entry.value is Map) {
              _matchingAnswers[entry.key] = Map<String, String>.from(entry.value as Map);
            }
          }
          hasChanges = true;
        }

        if (hasChanges && mounted) {
          setState(() {});
        }
      }
    } catch (_) {}
  }

  Future<void> _clearDraftAnswers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('exam_draft_answers_v2_${widget.exam.id}');
      await prefs.remove('exam_draft_answers_${widget.exam.id}');
    } catch (_) {}
  }

  void _submitExam({required List<ExamQuestionModel> questions, bool isAutoSubmit = false}) {
    _timer?.cancel();
    _clearDraftAnswers();

    final List<Map<String, dynamic>> answersPayload = [];
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final key = _getQuestionKey(q, i);

      switch (q.type) {
        case QuestionType.mcq:
          final opt = _selectedOptions[key] ?? (q.id.isNotEmpty ? _selectedOptions[q.id] : null);
          if (opt != null) {
            answersPayload.add({
              'question_id': q.id,
              'question_key': key,
              'question_text': q.questionText,
              'question_index': i,
              'type': 'mcq',
              'options': q.options,
              'selected_letter': opt.originalLetter,
              'selected_option': opt.text,
              'selected_index': opt.originalIndex,
            });
          }
          break;

        case QuestionType.trueFalse:
          final ans = _textAnswers[key] ?? (q.id.isNotEmpty ? _textAnswers[q.id] : null);
          if (ans != null && ans.isNotEmpty) {
            answersPayload.add({
              'question_id': q.id,
              'question_key': key,
              'question_text': q.questionText,
              'question_index': i,
              'type': 'true_false',
              'selected_option': ans,
            });
          }
          break;

        case QuestionType.matching:
          final matched = _matchingAnswers[key] ?? (q.id.isNotEmpty ? _matchingAnswers[q.id] : null);
          if (matched != null && matched.isNotEmpty) {
            final pairsList = matched.entries.map((e) => {'left': e.key, 'right': e.value}).toList();
            answersPayload.add({
              'question_id': q.id,
              'question_key': key,
              'question_text': q.questionText,
              'question_index': i,
              'type': 'matching',
              'matched_pairs': pairsList,
              'selected_option': pairsList.map((p) => '${p['left']} ➔ ${p['right']}').join(', '),
            });
          }
          break;

        case QuestionType.fillBlank:
        case QuestionType.essay:
        case QuestionType.shortAnswer:
          final txt = _textAnswers[key] ?? (q.id.isNotEmpty ? _textAnswers[q.id] : null);
          if (txt != null && txt.trim().isNotEmpty) {
            answersPayload.add({
              'question_id': q.id,
              'question_key': key,
              'question_text': q.questionText,
              'question_index': i,
              'type': q.type.value,
              'student_text': txt.trim(),
              'selected_option': txt.trim(),
            });
          }
          break;
      }
    }

    context.read<ExamsCubit>().submitExam(
          examId: widget.exam.id,
          answers: answersPayload,
        );
  }

  void _showSubmitConfirmation(List<ExamQuestionModel> questions) {
    final unansweredIndices = <int>[];
    for (int i = 0; i < questions.length; i++) {
      if (!_isQuestionAnswered(questions[i], i)) {
        unansweredIndices.add(i + 1);
      }
    }

    final int answeredCount = questions.length - unansweredIndices.length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.assignment_turned_in_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text('تسليم الامتحان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'أجبت على $answeredCount من أصل ${questions.length} سؤال.',
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              if (unansweredIndices.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'تنبيه: لديك ${unansweredIndices.length} أسئلة لم تُجب عليها!',
                            style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: unansweredIndices.map((qNum) {
                          return InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              setState(() => _currentQuestionIndex = qNum - 1);
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                'السؤال $qNum 👈',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'اضغط على رقم أي سؤال للانتقال إليه مباشرة وحله.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.green, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'ممتاز! قمت بالإجابة على جميع الأسئلة.',
                        style: TextStyle(color: AppColors.green, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                'هل أنت متأكد من رغبتك في تسليم الإجابات الآن؟',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('متابعة الحل'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: unansweredIndices.isNotEmpty ? Colors.amber.shade700 : AppColors.green,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _submitExam(questions: questions);
            },
            child: Text(unansweredIndices.isNotEmpty ? 'تسليم رغم النقص' : 'تأكيد التسليم'),
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
              message: state is ExamSubmitting ? 'جاري تسليم وتأكيد الإجابات...' : 'جاري فتح الامتحان...',
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
                  ],
                ),
              ),
            ),
          );
        }

        final questions = (state is ExamTakingLoaded) ? state.questions : <ExamQuestionModel>[];
        if (questions.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.exam.title)),
            body: const Center(child: Text('لا توجد أسئلة متاحة لهذا الامتحان')),
          );
        }

        _lastQuestions = questions;
        _loadDraftAnswers(questions);

        final currentQ = questions[_currentQuestionIndex];
        final qKey = _getQuestionKey(currentQ, _currentQuestionIndex);

        int answeredCount = 0;
        for (int i = 0; i < questions.length; i++) {
          if (_isQuestionAnswered(questions[i], i)) {
            answeredCount++;
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.exam.title, style: AppTextStyles.titleMedium),
            automaticallyImplyLeading: false,
            actions: [
              // Answered progress badge
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: answeredCount == questions.length
                      ? AppColors.green.withValues(alpha: 0.15)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: answeredCount == questions.length ? AppColors.green : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      answeredCount == questions.length
                          ? Icons.check_circle_rounded
                          : Icons.edit_note_rounded,
                      size: 16,
                      color: answeredCount == questions.length ? AppColors.green : AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$answeredCount/${questions.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: answeredCount == questions.length ? AppColors.green : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Timer Display
              Container(
                margin: const EdgeInsets.only(left: 14, right: 4, top: 8, bottom: 8),
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
                      Row(
                        children: [
                          Text(
                            'السؤال ${_currentQuestionIndex + 1} من ${questions.length}',
                            style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              currentQ.type.label,
                              style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
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
                  const SizedBox(height: 20),

                  // Question Text Card
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
                              style: AppTextStyles.titleMedium.copyWith(height: 1.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Dynamic Question Answer Widget by Type
                          _buildQuestionInputWidget(currentQ, qKey),
                        ],
                      ),
                    ),
                  ),

                  // Navigation Controls
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (_currentQuestionIndex > 0)
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => setState(() => _currentQuestionIndex--),
                            child: const Text('السابق'),
                          ),
                        ),
                      if (_currentQuestionIndex > 0) const SizedBox(width: 12),
                      Expanded(
                        child: CustomButton(
                          text: _currentQuestionIndex < questions.length - 1 ? 'التالي' : 'مراجعة وتسليم',
                          icon: _currentQuestionIndex < questions.length - 1 ? Icons.arrow_back : Icons.check_circle_outline,
                          onPressed: () {
                            if (_currentQuestionIndex < questions.length - 1) {
                              setState(() => _currentQuestionIndex++);
                            } else {
                              _showSubmitConfirmation(questions);
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

  Widget _buildQuestionInputWidget(ExamQuestionModel currentQ, String qKey) {
    switch (currentQ.type) {
      case QuestionType.mcq:
        return _buildMcqOptions(currentQ, qKey);
      case QuestionType.trueFalse:
        return _buildTrueFalseOptions(currentQ, qKey);
      case QuestionType.matching:
        return _buildMatchingOptions(currentQ, qKey);
      case QuestionType.fillBlank:
        return _buildFillBlankInput(currentQ, qKey);
      case QuestionType.essay:
        return _buildEssayInput(currentQ, qKey);
      case QuestionType.shortAnswer:
        return _buildShortAnswerInput(currentQ, qKey);
    }
  }

  Widget _buildMcqOptions(ExamQuestionModel currentQ, String qKey) {
    final shuffledOpts = _shuffledOptionsMap.putIfAbsent(
      qKey,
      () => currentQ.getMappedOptions(shuffle: true),
    );

    return Column(
      children: shuffledOpts.asMap().entries.map((entry) {
        final displayIdx = entry.key;
        final shuffledOpt = entry.value;
        const displayLetters = ['A', 'B', 'C', 'D', 'E', 'F'];
        final displayLetter = displayIdx < displayLetters.length ? displayLetters[displayIdx] : '${displayIdx + 1}';

        final selectedOpt = _selectedOptions[qKey] ?? (currentQ.id.isNotEmpty ? _selectedOptions[currentQ.id] : null);
        final isSelected = selectedOpt?.originalLetter == shuffledOpt.originalLetter || selectedOpt?.text == shuffledOpt.text;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedOptions[qKey] = shuffledOpt;
                if (currentQ.id.isNotEmpty) _selectedOptions[currentQ.id] = shuffledOpt;
              });
              _saveDraftAnswers();
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
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTrueFalseOptions(ExamQuestionModel currentQ, String qKey) {
    final currentVal = _textAnswers[qKey] ?? (currentQ.id.isNotEmpty ? _textAnswers[currentQ.id] : null);

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () {
              setState(() {
                _textAnswers[qKey] = 'صح';
                if (currentQ.id.isNotEmpty) _textAnswers[currentQ.id] = 'صح';
              });
              _saveDraftAnswers();
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: currentVal == 'صح' ? AppColors.green.withValues(alpha: 0.15) : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: currentVal == 'صح' ? AppColors.green : AppColors.border,
                  width: currentVal == 'صح' ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline, color: currentVal == 'صح' ? AppColors.green : AppColors.textSecondary, size: 36),
                  const SizedBox(height: 8),
                  Text('صح', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: currentVal == 'صح' ? AppColors.green : AppColors.textPrimary)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: InkWell(
            onTap: () {
              setState(() {
                _textAnswers[qKey] = 'خطأ';
                if (currentQ.id.isNotEmpty) _textAnswers[currentQ.id] = 'خطأ';
              });
              _saveDraftAnswers();
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: currentVal == 'خطأ' ? AppColors.red.withValues(alpha: 0.15) : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: currentVal == 'خطأ' ? AppColors.red : AppColors.border,
                  width: currentVal == 'خطأ' ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.cancel_outlined, color: currentVal == 'خطأ' ? AppColors.red : AppColors.textSecondary, size: 36),
                  const SizedBox(height: 8),
                  Text('خطأ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: currentVal == 'خطأ' ? AppColors.red : AppColors.textPrimary)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchingOptions(ExamQuestionModel currentQ, String qKey) {
    final pairs = currentQ.matchingPairs;
    final currentMatches = _matchingAnswers.putIfAbsent(qKey, () => {});
    final selectedLeft = _selectedLeftItem[qKey];

    // Left items and shuffled right items
    final leftItems = pairs.map((p) => p.left).toList();
    final rightItems = pairs.map((p) => p.right).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.touch_app_outlined, size: 20, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'اضغط على عنصر من العمود الأول ثم اضغط على ما يناسبه من العمود المقابل لتوصيلهما.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: leftItems.map((leftText) {
                  final isPaired = currentMatches.containsKey(leftText);
                  final isSelected = selectedLeft == leftText;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedLeftItem[qKey] = leftText;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : (isPaired ? AppColors.green.withValues(alpha: 0.1) : AppColors.surface),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : (isPaired ? AppColors.green : AppColors.border),
                            width: isSelected || isPaired ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(leftText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            if (isPaired) ...[
                              const SizedBox(height: 4),
                              Text('موصول بـ: ${currentMatches[leftText]}', style: const TextStyle(fontSize: 11, color: AppColors.green)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 12),

            // Right Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rightItems.map((rightText) {
                  final pairedWith = currentMatches.entries.firstWhere(
                    (e) => e.value == rightText,
                    orElse: () => const MapEntry('', ''),
                  );
                  final isClaimed = pairedWith.key.isNotEmpty;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: selectedLeft != null
                          ? () {
                              setState(() {
                                currentMatches[selectedLeft] = rightText;
                                _selectedLeftItem[qKey] = null;
                              });
                              _saveDraftAnswers();
                            }
                          : null,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isClaimed ? AppColors.green.withValues(alpha: 0.1) : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isClaimed ? AppColors.green : AppColors.border,
                            width: isClaimed ? 1.5 : 1,
                          ),
                        ),
                        child: Text(rightText, style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),

        if (currentMatches.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.refresh, size: 16, color: AppColors.red),
              label: const Text('إعادة ضبط التوصيل', style: TextStyle(color: AppColors.red, fontSize: 12)),
              onPressed: () {
                setState(() {
                  currentMatches.clear();
                  _selectedLeftItem[qKey] = null;
                });
                _saveDraftAnswers();
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFillBlankInput(ExamQuestionModel currentQ, String qKey) {
    final ctrl = _getTextController(qKey, initialText: _textAnswers[qKey] ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('اكتب الكلمة أو العبارة المناسبة لإكمال الفراغ:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: 'اكتب الإجابة هنا...',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            prefixIcon: const Icon(Icons.edit_note_rounded, color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildEssayInput(ExamQuestionModel currentQ, String qKey) {
    final ctrl = _getTextController(qKey, initialText: _textAnswers[qKey] ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('اكتب إجابتك المقالية بالتفصيل:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        TextField(
          controller: ctrl,
          maxLines: 7,
          decoration: InputDecoration(
            hintText: 'اكتب شرحك أو إجابتك هنا...',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
          ),
        ),
      ],
    );
  }

  Widget _buildShortAnswerInput(ExamQuestionModel currentQ, String qKey) {
    final ctrl = _getTextController(qKey, initialText: _textAnswers[qKey] ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('اكتب إجابتك القصيرة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        TextField(
          controller: ctrl,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'اكتب إجابتك هنا...',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
          ),
        ),
      ],
    );
  }
}
