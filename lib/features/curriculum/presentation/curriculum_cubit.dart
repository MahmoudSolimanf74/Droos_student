import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/curriculum_repository.dart';
import '../domain/curriculum_models.dart';
import 'curriculum_state.dart';

class CurriculumCubit extends Cubit<CurriculumState> {
  final CurriculumRepository _repository;
  String? _currentGradeId;

  CurriculumCubit({required CurriculumRepository repository})
      : _repository = repository,
        super(CurriculumInitial());

  String? get currentGradeId => _currentGradeId;

  Future<void> loadCurriculum(String gradeId) async {
    _currentGradeId = gradeId;
    emit(CurriculumLoading());
    try {
      final offlineFiles = await _repository.getOfflineDownloadedFiles(gradeId: gradeId);
      final units = await _repository.getUnitsForGrade(gradeId);
      final Map<String, List<LessonModel>> unitLessons = {};
      final Map<String, List<LessonFileModel>> lessonFiles = {};

      for (final u in units) {
        final lessons = await _repository.getLessons(u.id);
        unitLessons[u.id] = lessons;
        for (final l in lessons) {
          final files = await _repository.getLessonFiles(l.id);
          lessonFiles[l.id] = files;
        }
      }

      emit(CurriculumLoaded(
        units: units,
        unitLessons: unitLessons,
        lessonFiles: lessonFiles,
        offlineFiles: offlineFiles,
        isOffline: false,
      ));
    } catch (e) {
      debugPrint('[CurriculumCubit] Network fetch failed ($e), falling back to offline files and cache for grade $gradeId...');
      final offlineFiles = await _repository.getOfflineDownloadedFiles(gradeId: gradeId);
      final cachedUnits = await _repository.getUnitsForGrade(gradeId);
      final Map<String, List<LessonModel>> cachedLessons = {};
      final Map<String, List<LessonFileModel>> cachedFiles = {};

      for (final u in cachedUnits) {
        final lessons = await _repository.getLessons(u.id);
        cachedLessons[u.id] = lessons;
        for (final l in lessons) {
          final files = await _repository.getLessonFiles(l.id);
          cachedFiles[l.id] = files;
        }
      }

      if (offlineFiles.isNotEmpty || cachedUnits.isNotEmpty) {
        emit(CurriculumLoaded(
          units: cachedUnits,
          unitLessons: cachedLessons,
          lessonFiles: cachedFiles,
          offlineFiles: offlineFiles,
          isOffline: true,
        ));
      } else {
        emit(const CurriculumError('عفواً، يرجى الاتصال بالإنترنت لتحميل المناهج والدروس لأول مرة'));
      }
    }
  }

  String getFileUrl(String filePath) => _repository.getPublicUrl(filePath);

  Future<void> refreshOfflineFiles([String? gradeId]) async {
    final targetGrade = gradeId ?? _currentGradeId;
    final offlineFiles = await _repository.getOfflineDownloadedFiles(gradeId: targetGrade);
    if (state is CurriculumLoaded) {
      final current = state as CurriculumLoaded;
      emit(current.copyWith(offlineFiles: offlineFiles));
    }
  }

  Future<String> downloadFile(String url, String fileName, {String? gradeId}) async {
    final targetGrade = gradeId ?? _currentGradeId;
    final path = await _repository.downloadPdf(url, fileName, gradeId: targetGrade);
    await refreshOfflineFiles(targetGrade);
    return path;
  }

  Future<bool> isFileDownloaded(String fileName, {String? gradeId}) =>
      _repository.isFileDownloaded(fileName, gradeId: gradeId ?? _currentGradeId);

  Future<String?> getLocalFilePath(String fileName, {String? gradeId}) =>
      _repository.getLocalFilePath(fileName, gradeId: gradeId ?? _currentGradeId);

  Future<List<LessonFileModel>> getOfflineDownloadedFiles({String? gradeId}) =>
      _repository.getOfflineDownloadedFiles(gradeId: gradeId ?? _currentGradeId);

  Future<String?> getStudentAnnotatedFilePath(String fileName, {String? gradeId}) =>
      _repository.getStudentAnnotatedFilePath(fileName, gradeId: gradeId ?? _currentGradeId);

  Future<bool> hasStudentAnnotations(String fileName, {String? gradeId}) =>
      _repository.hasStudentAnnotations(fileName, gradeId: gradeId ?? _currentGradeId);

  Future<String> saveStudentAnnotatedPdf(String fileName, List<int> bytes, {String? gradeId}) =>
      _repository.saveStudentAnnotatedPdf(fileName, bytes, gradeId: gradeId ?? _currentGradeId);

  Future<bool> deleteStudentAnnotatedPdf(String fileName, {String? gradeId}) =>
      _repository.deleteStudentAnnotatedPdf(fileName, gradeId: gradeId ?? _currentGradeId);

  Future<String?> getStudentNotesJson(String fileName, {String? gradeId}) =>
      _repository.getStudentNotesJson(fileName, gradeId: gradeId ?? _currentGradeId);

  Future<void> saveStudentNotesJson(String fileName, String jsonData, {String? gradeId}) =>
      _repository.saveStudentNotesJson(fileName, jsonData, gradeId: gradeId ?? _currentGradeId);

  Future<bool> deleteStudentNotesJson(String fileName, {String? gradeId}) =>
      _repository.deleteStudentNotesJson(fileName, gradeId: gradeId ?? _currentGradeId);
}
