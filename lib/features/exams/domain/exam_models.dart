import 'dart:convert';
import 'package:equatable/equatable.dart';

class ExamModel extends Equatable {
  final String id;
  final String gradeId;
  final String title;
  final String? description;
  final int durationMinutes;
  final double passingScore;
  final int totalQuestions;
  final DateTime createdAt;

  const ExamModel({
    required this.id,
    required this.gradeId,
    required this.title,
    this.description,
    required this.durationMinutes,
    required this.passingScore,
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
      id: json['id'] as String,
      gradeId: json['grade_id'] as String? ?? '',
      title: json['title'] as String? ?? 'امتحان',
      description: json['description'] as String?,
      durationMinutes: json['duration_minutes'] as int? ?? 30,
      passingScore: (json['passing_score'] as num?)?.toDouble() ?? 50.0,
      totalQuestions: totalQuestions,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'grade_id': gradeId,
        'title': title,
        'description': description,
        'duration_minutes': durationMinutes,
        'passing_score': passingScore,
        'total_questions': totalQuestions,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, gradeId, title, description, durationMinutes, passingScore, totalQuestions, createdAt];
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
  final List<String> options;
  final double points;
  final String? correctAnswer;

  const ExamQuestionModel({
    required this.id,
    required this.examId,
    required this.questionText,
    required this.options,
    required this.points,
    this.correctAnswer,
  });

  /// Normalizes correct answer to 'A', 'B', 'C', 'D', etc.
  String get correctLetter {
    if (correctAnswer == null || correctAnswer!.trim().isEmpty) return '';
    final raw = correctAnswer!.trim();

    // Check if it's already a letter A-Z or a-z
    const letters = ['A', 'B', 'C', 'D', 'E'];
    final upper = raw.toUpperCase();
    if (letters.contains(upper)) return upper;

    // Check Arabic letters
    const arLetters = ['أ', 'ا', 'ب', 'ج', 'د', 'هـ', 'ه'];
    if (arLetters.contains(raw)) {
      if (raw == 'أ' || raw == 'ا') return 'A';
      if (raw == 'ب') return 'B';
      if (raw == 'ج') return 'C';
      if (raw == 'د') return 'D';
      if (raw == 'هـ' || raw == 'ه') return 'E';
    }

    // Check if numeric (0-based or 1-based)
    final numVal = int.tryParse(raw);
    if (numVal != null) {
      if (numVal >= 0 && numVal < letters.length) {
        return letters[numVal];
      }
      if (numVal >= 1 && numVal <= letters.length) {
        return letters[numVal - 1];
      }
    }

    // Check if it matches option text directly
    final normOpts = options.map((o) => o.trim().toLowerCase()).toList();
    final matchIdx = normOpts.indexOf(raw.toLowerCase());
    if (matchIdx >= 0 && matchIdx < letters.length) {
      return letters[matchIdx];
    }

    return upper;
  }

  /// Helper to get options with original letter mappings and optionally shuffle them
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

    final qText = json['question'] as String? ?? json['question_text'] as String? ?? '';
    final cAns = json['correct_answer'] as String? ?? json['answer'] as String? ?? json['correct_option'] as String?;

    return ExamQuestionModel(
      id: json['id']?.toString() ?? '',
      examId: json['exam_id']?.toString() ?? '',
      questionText: qText,
      options: parsedOpts,
      points: (json['points'] as num?)?.toDouble() ?? 1.0,
      correctAnswer: cAns,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'exam_id': examId,
        'question': questionText,
        'options': options,
        'points': points,
        if (correctAnswer != null) 'correct_answer': correctAnswer,
      };

  @override
  List<Object?> get props => [id, examId, questionText, options, points, correctAnswer];
}

class ExamResultModel extends Equatable {
  final String attemptId;
  final double earnedPoints;
  final double totalPoints;
  final double scorePercentage;
  final bool passed;
  final double passingScore;
  final List<Map<String, dynamic>> breakdown;

  const ExamResultModel({
    required this.attemptId,
    required this.earnedPoints,
    required this.totalPoints,
    required this.scorePercentage,
    required this.passed,
    required this.passingScore,
    required this.breakdown,
  });

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
      breakdown: parsedList,
    );
  }

  @override
  List<Object?> get props => [attemptId, earnedPoints, totalPoints, scorePercentage, passed, passingScore, breakdown];
}
