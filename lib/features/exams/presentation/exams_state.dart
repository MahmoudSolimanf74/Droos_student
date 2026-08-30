import 'package:equatable/equatable.dart';
import '../domain/exam_models.dart';

abstract class ExamsState extends Equatable {
  const ExamsState();
  @override
  List<Object?> get props => [];
}

class ExamsInitial extends ExamsState {}

class ExamsLoading extends ExamsState {}

class ExamsLoaded extends ExamsState {
  final List<ExamModel> exams;
  final List<ExamModel> offlineExams;
  final List<Map<String, dynamic>> attempts;
  final Set<String> downloadedExamIds;
  final bool isOffline;

  const ExamsLoaded({
    required this.exams,
    this.offlineExams = const [],
    required this.attempts,
    this.downloadedExamIds = const {},
    this.isOffline = false,
  });

  @override
  List<Object?> get props => [exams, offlineExams, attempts, downloadedExamIds, isOffline];
}

class ExamTakingLoaded extends ExamsState {
  final ExamModel exam;
  final List<ExamQuestionModel> questions;

  const ExamTakingLoaded({required this.exam, required this.questions});

  @override
  List<Object?> get props => [exam, questions];
}

class ExamSubmitting extends ExamsState {}

class ExamCompletedState extends ExamsState {
  final ExamResultModel result;
  const ExamCompletedState(this.result);
  @override
  List<Object?> get props => [result];
}

class ExamsError extends ExamsState {
  final String message;
  const ExamsError(this.message);
  @override
  List<Object?> get props => [message];
}
