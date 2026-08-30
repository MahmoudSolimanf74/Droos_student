import 'package:equatable/equatable.dart';
import '../domain/curriculum_models.dart';

abstract class CurriculumState extends Equatable {
  const CurriculumState();
  @override
  List<Object?> get props => [];
}

class CurriculumInitial extends CurriculumState {}

class CurriculumLoading extends CurriculumState {}

class CurriculumLoaded extends CurriculumState {
  final List<UnitModel> units;
  final Map<String, List<LessonModel>> unitLessons;
  final Map<String, List<LessonFileModel>> lessonFiles;
  final List<LessonFileModel> offlineFiles;
  final bool isOffline;

  const CurriculumLoaded({
    required this.units,
    required this.unitLessons,
    required this.lessonFiles,
    this.offlineFiles = const [],
    this.isOffline = false,
  });

  CurriculumLoaded copyWith({
    List<UnitModel>? units,
    Map<String, List<LessonModel>>? unitLessons,
    Map<String, List<LessonFileModel>>? lessonFiles,
    List<LessonFileModel>? offlineFiles,
    bool? isOffline,
  }) {
    return CurriculumLoaded(
      units: units ?? this.units,
      unitLessons: unitLessons ?? this.unitLessons,
      lessonFiles: lessonFiles ?? this.lessonFiles,
      offlineFiles: offlineFiles ?? this.offlineFiles,
      isOffline: isOffline ?? this.isOffline,
    );
  }

  @override
  List<Object?> get props => [units, unitLessons, lessonFiles, offlineFiles, isOffline];
}

class CurriculumError extends CurriculumState {
  final String message;
  const CurriculumError(this.message);
  @override
  List<Object?> get props => [message];
}
