import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/exams_repository.dart';
import '../domain/exam_models.dart';
import 'exams_state.dart';

class ExamsCubit extends Cubit<ExamsState> {
  final ExamsRepository _repository;

  ExamsCubit({required ExamsRepository repository})
      : _repository = repository,
        super(ExamsInitial());

  String? _currentGradeId;

  Future<void> loadExams({required String gradeId, required String studentId}) async {
    _currentGradeId = gradeId;
    emit(ExamsLoading());

    List<ExamModel> exams = [];
    List<ExamModel> offlineExams = [];
    List<Map<String, dynamic>> attempts = [];
    Set<String> downloadedExamIds = {};
    bool isOffline = false;

    try {
      offlineExams = await _repository.getOfflineExams(gradeId);
      downloadedExamIds = offlineExams.map((e) => e.id).toSet();
    } catch (_) {}

    try {
      exams = await _repository.getExamsForGrade(gradeId);
    } catch (_) {
      isOffline = true;
      exams = offlineExams;
    }

    if (exams.isEmpty && offlineExams.isNotEmpty) {
      isOffline = true;
    }

    try {
      attempts = await _repository.getMyAttempts(studentId);
    } catch (_) {}

    emit(ExamsLoaded(
      exams: exams,
      offlineExams: offlineExams,
      attempts: attempts,
      downloadedExamIds: downloadedExamIds,
      isOffline: isOffline,
    ));
  }

  Future<void> downloadExam(ExamModel exam) async {
    try {
      await _repository.downloadExamForOffline(exam);
      final gradeId = _currentGradeId ?? exam.gradeId;
      final offline = await _repository.getOfflineExams(gradeId);
      final downloaded = offline.map((e) => e.id).toSet();

      if (state is ExamsLoaded) {
        final current = state as ExamsLoaded;
        emit(ExamsLoaded(
          exams: current.exams,
          offlineExams: offline,
          attempts: current.attempts,
          downloadedExamIds: downloaded,
          isOffline: current.isOffline,
        ));
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteOfflineExam(ExamModel exam) async {
    try {
      final gradeId = _currentGradeId ?? exam.gradeId;
      await _repository.deleteOfflineExam(exam.id, gradeId);
      final offline = await _repository.getOfflineExams(gradeId);
      final downloaded = offline.map((e) => e.id).toSet();

      if (state is ExamsLoaded) {
        final current = state as ExamsLoaded;
        emit(ExamsLoaded(
          exams: current.exams,
          offlineExams: offline,
          attempts: current.attempts,
          downloadedExamIds: downloaded,
          isOffline: current.isOffline,
        ));
      }
    } catch (_) {}
  }

  Future<void> startExam(ExamModel exam) async {
    emit(ExamsLoading());
    try {
      final rawQuestions = await _repository.getExamQuestions(exam.id);
      
      // 1. Shuffle questions list randomly
      final questions = List<ExamQuestionModel>.from(rawQuestions)..shuffle();

      emit(ExamTakingLoaded(exam: exam, questions: questions));
    } catch (e) {
      emit(ExamsError(e.toString()));
    }
  }

  Future<void> submitExam({
    required String examId,
    required List<Map<String, dynamic>> answers,
  }) async {
    emit(ExamSubmitting());
    try {
      final result = await _repository.submitExamAttempt(
        examId: examId,
        answers: answers,
      );
      emit(ExamCompletedState(result));
    } catch (e) {
      emit(ExamsError(e.toString()));
    }
  }
}
