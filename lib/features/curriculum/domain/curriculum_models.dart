import 'package:equatable/equatable.dart';

class UnitModel extends Equatable {
  final String id;
  final String curriculumId;
  final String title;
  final String? description;

  const UnitModel({
    required this.id,
    required this.curriculumId,
    required this.title,
    this.description,
  });

  factory UnitModel.fromJson(Map<String, dynamic> json) => UnitModel(
        id: json['id'] as String,
        curriculumId: json['curriculum_id'] as String? ?? '',
        title: json['title'] as String,
        description: json['description'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'curriculum_id': curriculumId,
        'title': title,
        'description': description,
      };

  @override
  List<Object?> get props => [id, curriculumId, title, description];
}

class LessonModel extends Equatable {
  final String id;
  final String unitId;
  final String title;
  final String? description;

  const LessonModel({
    required this.id,
    required this.unitId,
    required this.title,
    this.description,
  });

  factory LessonModel.fromJson(Map<String, dynamic> json) => LessonModel(
        id: json['id'] as String,
        unitId: json['unit_id'] as String? ?? '',
        title: json['title'] as String,
        description: json['description'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'unit_id': unitId,
        'title': title,
        'description': description,
      };

  @override
  List<Object?> get props => [id, unitId, title, description];
}

class LessonFileModel extends Equatable {
  final String id;
  final String lessonId;
  final String title;
  final String filePath;
  final String fileType;
  final int fileSize;

  const LessonFileModel({
    required this.id,
    required this.lessonId,
    required this.title,
    required this.filePath,
    required this.fileType,
    required this.fileSize,
  });

  factory LessonFileModel.fromJson(Map<String, dynamic> json) => LessonFileModel(
        id: json['id'] as String,
        lessonId: json['lesson_id'] as String? ?? '',
        title: json['title'] as String? ?? json['file_name'] as String? ?? 'ملف دراسي',
        filePath: json['file_path'] as String? ?? '',
        fileType: json['file_type'] as String? ?? 'pdf',
        fileSize: json['file_size'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'lesson_id': lessonId,
        'title': title,
        'file_path': filePath,
        'file_type': fileType,
        'file_size': fileSize,
      };

  @override
  List<Object?> get props => [id, lessonId, title, filePath, fileType, fileSize];
}
