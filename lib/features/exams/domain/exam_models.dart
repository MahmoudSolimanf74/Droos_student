import 'dart:convert';
import 'package:equatable/equatable.dart';

enum QuestionType {
  mcq('mcq', 'اختيار من متعدد', true),
  trueFalse('true_false', 'صح أو خطأ', true),
  matching('matching', 'توصيل', true),
  fillBlank('fill_blank', 'أكمل الفراغ', true),
  essay('essay', 'سؤال مقالي', false),
  shortAnswer('short_answer', 'إجابة قصيرة', false);

  final String value;
  final String label;
  final bool isAutoGraded;

  const QuestionType(this.value, this.label, this.isAutoGraded);

  static QuestionType fromString(String? val) {
    if (val == null) return QuestionType.mcq;
    final normalized = val.trim().toLowerCase();
    switch (normalized) {
      case 'true_false':
      case 'truefalse':
      case 'boolean':
      case 'tf':
        return QuestionType.trueFalse;
      case 'matching':
      case 'match':
        return QuestionType.matching;
      case 'fill_blank':
      case 'fill_in_the_blank':
      case 'complete':
        return QuestionType.fillBlank;
      case 'essay':
      case 'written':
        return QuestionType.essay;
      case 'short_answer':
      case 'short':
        return QuestionType.shortAnswer;
      case 'mcq':
      case 'multiple_choice':
      default:
        return QuestionType.mcq;
    }
  }
}

class MatchingPair extends Equatable {
  final String left;
  final String right;

  const MatchingPair({required this.left, required this.right});

  factory MatchingPair.fromJson(Map<String, dynamic> json) {
    return MatchingPair(
      left: json['left']?.toString() ?? '',
      right: json['right']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'left': left,
        'right': right,
      };

  @override
  List<Object?> get props => [left, right];
}

class ExamModel extends Equatable {
  final String id;
  final String gradeId;
  final String title;
  final String? description;
  final int durationMinutes;
  final double passingScore;
  final double totalPoints;
  final bool isPublished;
  final DateTime? publishedAt;
  final int totalQuestions;
  final DateTime createdAt;

  const ExamModel({
    required this.id,
    required this.gradeId,
    required this.title,
    this.description,
    required this.durationMinutes,
    required this.passingScore,
    this.totalPoints = 100.0,
    this.isPublished = false,
    this.publishedAt,
    required this.totalQuestions,
    required this.createdAt,
  });

  factory ExamModel.fromJson(Map<String, dynamic> json) {
    int totalQuestions = 0;
    if (json['exam_questions'] is List) {
      totalQuestions = (json['exam_questions'] as List).length;
    } else if (json['questions'] is List) {
      totalQuestions = (json['questions'] as List).length;
    } else if (json['total_questions'] != null) {
      totalQuestions = (json['total_questions'] as num).toInt();
    } else if (json['questions_count'] != null) {
      totalQuestions = (json['questions_count'] as num).toInt();
    }

    return ExamModel(
      id: json['id']?.toString() ?? '',
      gradeId: json['grade_id'] as String? ?? '',
      title: json['title'] as String? ?? 'امتحان',
      description: json['description'] as String?,
      durationMinutes: json['duration_minutes'] as int? ?? 30,
      passingScore: (json['passing_score'] as num?)?.toDouble() ?? 50.0,
      totalPoints: (json['total_points'] as num?)?.toDouble() ?? 100.0,
      isPublished: json['is_published'] as bool? ?? false,
      publishedAt: json['published_at'] != null ? DateTime.tryParse(json['published_at'].toString()) : null,
      totalQuestions: totalQuestions,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'grade_id': gradeId,
        'title': title,
        'description': description,
        'duration_minutes': durationMinutes,
        'passing_score': passingScore,
        'total_points': totalPoints,
        'is_published': isPublished,
        'published_at': publishedAt?.toIso8601String(),
        'total_questions': totalQuestions,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id,
        gradeId,
        title,
        description,
        durationMinutes,
        passingScore,
        totalPoints,
        isPublished,
        publishedAt,
        totalQuestions,
        createdAt,
      ];
}

class ShuffledOption extends Equatable {
  final String text;
  final String originalLetter; // 'A', 'B', 'C', 'D'
  final int originalIndex; // 0, 1, 2, 3

  const ShuffledOption({
    required this.text,
    required this.originalLetter,
    required this.originalIndex,
  });

  @override
  List<Object?> get props => [text, originalLetter, originalIndex];
}

class ExamQuestionModel extends Equatable {
  final String id;
  final String examId;
  final String questionText;
  final QuestionType type;
  final List<String> options;
  final double points;
  final String? correctAnswer;
  final String? modelAnswer;
  final List<MatchingPair> matchingPairs;
  final List<String> acceptedAnswers;

  const ExamQuestionModel({
    required this.id,
    required this.examId,
    required this.questionText,
    this.type = QuestionType.mcq,
    required this.options,
    required this.points,
    this.correctAnswer,
    this.modelAnswer,
    this.matchingPairs = const [],
    this.acceptedAnswers = const [],
  });

  bool get isAutoGraded => type.isAutoGraded;

  /// Normalizes correct answer to 'A', 'B', 'C', 'D', etc.
  String get correctLetter {
    if (correctAnswer == null || correctAnswer!.trim().isEmpty) return '';
    final raw = correctAnswer!.trim();

    const letters = ['A', 'B', 'C', 'D', 'E'];
    final upper = raw.toUpperCase();
    if (letters.contains(upper)) return upper;

    const arLetters = ['أ', 'ا', 'ب', 'ج', 'د', 'هـ', 'ه'];
    if (arLetters.contains(raw)) {
      if (raw == 'أ' || raw == 'ا') return 'A';
      if (raw == 'ب') return 'B';
      if (raw == 'ج') return 'C';
      if (raw == 'د') return 'D';
      if (raw == 'هـ' || raw == 'ه') return 'E';
    }

    final numVal = int.tryParse(raw);
    if (numVal != null) {
      if (numVal >= 0 && numVal < letters.length) {
        return letters[numVal];
      }
      if (numVal >= 1 && numVal <= letters.length) {
        return letters[numVal - 1];
      }
    }

    final normOpts = options.map((o) => o.trim().toLowerCase()).toList();
    final matchIdx = normOpts.indexOf(raw.toLowerCase());
    if (matchIdx >= 0 && matchIdx < letters.length) {
      return letters[matchIdx];
    }

    return upper;
  }

  List<ShuffledOption> getMappedOptions({bool shuffle = false}) {
    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    final list = <ShuffledOption>[];
    for (int i = 0; i < options.length; i++) {
      final letter = i < letters.length ? letters[i] : '${i + 1}';
      list.add(ShuffledOption(
        text: options[i],
        originalLetter: letter,
        originalIndex: i,
      ));
    }
    if (shuffle) {
      list.shuffle();
    }
    return list;
  }

  factory ExamQuestionModel.fromJson(Map<String, dynamic> json) {
    var rawOpts = json['options'];
    List<String> parsedOpts = [];
    if (rawOpts is List) {
      parsedOpts = rawOpts.map((e) => e.toString()).toList();
    } else if (rawOpts is String) {
      try {
        final decoded = jsonDecode(rawOpts);
        if (decoded is List) {
          parsedOpts = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    List<MatchingPair> pairs = [];
    final rawPairs = json['matching_pairs'];
    if (rawPairs is List) {
      pairs = rawPairs.map((e) {
        if (e is Map) return MatchingPair.fromJson(Map<String, dynamic>.from(e));
        return const MatchingPair(left: '', right: '');
      }).where((p) => p.left.isNotEmpty || p.right.isNotEmpty).toList();
    }

    List<String> parsedAccepted = [];
    final rawAccepted = json['accepted_answers'];
    if (rawAccepted is List) {
      parsedAccepted = rawAccepted.map((e) => e.toString().trim()).toList();
    }

    final qType = QuestionType.fromString(json['type']?.toString());
    final qText = json['question'] as String? ?? json['question_text'] as String? ?? '';
    final cAns = json['correct_answer'] as String? ?? json['answer'] as String? ?? json['correct_option'] as String?;

    final rawId = json['id']?.toString() ?? json['question_id']?.toString() ?? '';
    final validId = rawId.trim().isNotEmpty
        ? rawId.trim()
        : 'q_${qText.trim().hashCode.abs()}_${parsedOpts.length}';

    return ExamQuestionModel(
      id: validId,
      examId: json['exam_id']?.toString() ?? '',
      questionText: qText,
      type: qType,
      options: parsedOpts,
      points: (json['points'] as num?)?.toDouble() ?? 1.0,
      correctAnswer: cAns,
      modelAnswer: json['model_answer'] as String?,
      matchingPairs: pairs,
      acceptedAnswers: parsedAccepted,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'exam_id': examId,
        'question': questionText,
        'type': type.value,
        'options': options,
        'points': points,
        if (correctAnswer != null) 'correct_answer': correctAnswer,
        if (modelAnswer != null) 'model_answer': modelAnswer,
        'matching_pairs': matchingPairs.map((p) => p.toJson()).toList(),
        'accepted_answers': acceptedAnswers,
      };

  @override
  List<Object?> get props => [
        id,
        examId,
        questionText,
        type,
        options,
        points,
        correctAnswer,
        modelAnswer,
        matchingPairs,
        acceptedAnswers,
      ];
}

class ExamResultModel extends Equatable {
  final String attemptId;
  final double earnedPoints;
  final double totalPoints;
  final double scorePercentage;
  final bool passed;
  final double passingScore;
  final bool isPublished;
  final String status; // 'submitted_pending_review', 'graded'
  final List<Map<String, dynamic>> breakdown;

  const ExamResultModel({
    required this.attemptId,
    required this.earnedPoints,
    required this.totalPoints,
    required this.scorePercentage,
    required this.passed,
    required this.passingScore,
    this.isPublished = false,
    this.status = 'submitted_pending_review',
    required this.breakdown,
  });

  bool get isPendingReview => !isPublished || status == 'submitted_pending_review';

  factory ExamResultModel.fromJson(Map<String, dynamic> json) {
    var rawBreakdown = json['breakdown'];
    List<Map<String, dynamic>> parsedList = [];
    if (rawBreakdown is List) {
      parsedList = rawBreakdown.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    return ExamResultModel(
      attemptId: json['attempt_id'] as String? ?? '',
      earnedPoints: (json['earned_points'] as num?)?.toDouble() ?? 0.0,
      totalPoints: (json['total_points'] as num?)?.toDouble() ?? 0.0,
      scorePercentage: (json['score_percentage'] as num?)?.toDouble() ?? 0.0,
      passed: json['passed'] as bool? ?? false,
      passingScore: (json['passing_score'] as num?)?.toDouble() ?? 50.0,
      isPublished: json['is_published'] as bool? ?? false,
      status: json['status'] as String? ?? 'submitted_pending_review',
      breakdown: parsedList,
    );
  }

  @override
  List<Object?> get props => [
        attemptId,
        earnedPoints,
        totalPoints,
        scorePercentage,
        passed,
        passingScore,
        isPublished,
        status,
        breakdown,
      ];
}
