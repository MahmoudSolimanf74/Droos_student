import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/errors/exceptions.dart';
import '../domain/curriculum_models.dart';

abstract class CurriculumRepository {
  Future<List<UnitModel>> getUnitsForGrade(String gradeId);
  Future<List<LessonModel>> getLessons(String unitId);
  Future<List<LessonFileModel>> getLessonFiles(String lessonId);
  String getPublicUrl(String filePath);
  Future<String> downloadPdf(String url, String fileName, {String? gradeId});
  Future<bool> isFileDownloaded(String fileName, {String? gradeId});
  Future<String?> getLocalFilePath(String fileName, {String? gradeId});
  Future<List<LessonFileModel>> getOfflineDownloadedFiles({String? gradeId});
}

class CurriculumRepositoryImpl implements CurriculumRepository {
  final SupabaseClient _client = SupabaseConfig.client;
  final Dio _dio = Dio();

  @override
  Future<List<UnitModel>> getUnitsForGrade(String gradeId) async {
    try {
      dynamic curriculumRes;
      try {
        curriculumRes = await _client
            .from('curriculum')
            .select('id')
            .eq('grade_id', gradeId)
            .maybeSingle();
      } catch (e) {
        debugPrint('[Curriculum] getCurriculum error: $e');
      }

      String? curriculumId = curriculumRes?['id']?.toString();

      List<dynamic> units = [];
      if (curriculumId != null) {
        try {
          final res = await _client
              .from('units')
              .select()
              .eq('curriculum_id', curriculumId)
              .order('sort_order', ascending: true);
          units = res as List<dynamic>;
        } catch (_) {
          try {
            final res = await _client
                .from('units')
                .select()
                .eq('curriculum_id', curriculumId);
            units = res as List<dynamic>;
          } catch (_) {}
        }
      } else {
        try {
          final res = await _client
              .from('units')
              .select()
              .eq('grade_id', gradeId);
          units = res as List<dynamic>;
        } catch (_) {}
      }

      final list = units.map((u) => UnitModel.fromJson(u as Map<String, dynamic>)).toList();

      try {
        final prefs = await SharedPreferences.getInstance();
        final encoded = list.map((u) => jsonEncode(u.toJson())).toList();
        await prefs.setStringList('cached_units_$gradeId', encoded);
      } catch (_) {}

      return list;
    } catch (e) {
      debugPrint('[getUnitsForGrade] Network error: $e, checking offline cache...');
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getStringList('cached_units_$gradeId');
        if (cached != null && cached.isNotEmpty) {
          return cached.map((s) => UnitModel.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
      return [];
    }
  }

  @override
  Future<List<LessonModel>> getLessons(String unitId) async {
    try {
      List<dynamic> lessons = [];
      try {
        final res = await _client
            .from('lessons')
            .select()
            .eq('unit_id', unitId)
            .order('sort_order', ascending: true);
        lessons = res as List<dynamic>;
      } catch (_) {
        try {
          final res = await _client
              .from('lessons')
              .select()
              .eq('unit_id', unitId);
          lessons = res as List<dynamic>;
        } catch (_) {}
      }

      final list = lessons.map((l) => LessonModel.fromJson(l as Map<String, dynamic>)).toList();

      try {
        final prefs = await SharedPreferences.getInstance();
        final encoded = list.map((l) => jsonEncode(l.toJson())).toList();
        await prefs.setStringList('cached_lessons_$unitId', encoded);
      } catch (_) {}

      return list;
    } catch (e) {
      debugPrint('[getLessons] Network error: $e, checking offline cache...');
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getStringList('cached_lessons_$unitId');
        if (cached != null && cached.isNotEmpty) {
          return cached.map((s) => LessonModel.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
      return [];
    }
  }

  @override
  Future<List<LessonFileModel>> getLessonFiles(String lessonId) async {
    try {
      dynamic res;
      try {
        res = await _client
            .from('lesson_files')
            .select()
            .eq('lesson_id', lessonId)
            .order('created_at', ascending: true);
      } catch (_) {
        try {
          res = await _client
              .from('lesson_files')
              .select()
              .eq('lesson_id', lessonId);
        } catch (_) {}
      }

      final list = ((res ?? []) as List<dynamic>).map((f) => LessonFileModel.fromJson(f as Map<String, dynamic>)).toList();

      try {
        final prefs = await SharedPreferences.getInstance();
        final encoded = list.map((f) => jsonEncode(f.toJson())).toList();
        await prefs.setStringList('cached_files_$lessonId', encoded);
      } catch (_) {}

      return list;
    } catch (e) {
      debugPrint('[getLessonFiles] Network error: $e, checking offline cache...');
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getStringList('cached_files_$lessonId');
        if (cached != null && cached.isNotEmpty) {
          return cached.map((s) => LessonFileModel.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
      return [];
    }
  }

  @override
  String getPublicUrl(String filePath) {
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return filePath;
    }
    return _client.storage.from('lesson-files').getPublicUrl(filePath);
  }

  Future<String> _getOfflineDirectory([String? gradeId]) async {
    final dir = await getApplicationDocumentsDirectory();
    final cleanGradeId = (gradeId != null && gradeId.isNotEmpty)
        ? gradeId.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        : 'default';
    final offlineDir = Directory('${dir.path}/offline_lessons/$cleanGradeId');
    if (!await offlineDir.exists()) {
      await offlineDir.create(recursive: true);
    }
    return offlineDir.path;
  }

  @override
  Future<bool> isFileDownloaded(String fileName, {String? gradeId}) async {
    try {
      final basePath = await _getOfflineDirectory(gradeId);
      final sanitizedName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final path = '$basePath/$sanitizedName';
      final file = File(path);
      if (await file.exists() && (await file.length() > 0)) return true;

      // Check legacy root folder as fallback
      final dir = await getApplicationDocumentsDirectory();
      final legacyFile = File('${dir.path}/offline_lessons/$sanitizedName');
      return await legacyFile.exists() && (await legacyFile.length() > 0);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> getLocalFilePath(String fileName, {String? gradeId}) async {
    try {
      final basePath = await _getOfflineDirectory(gradeId);
      final sanitizedName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final path = '$basePath/$sanitizedName';
      final file = File(path);
      if (await file.exists() && (await file.length() > 0)) {
        return path;
      }

      // Check legacy root folder as fallback
      final dir = await getApplicationDocumentsDirectory();
      final legacyFile = File('${dir.path}/offline_lessons/$sanitizedName');
      if (await legacyFile.exists() && (await legacyFile.length() > 0)) {
        return legacyFile.path;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> downloadPdf(String url, String fileName, {String? gradeId}) async {
    try {
      final basePath = await _getOfflineDirectory(gradeId);
      final sanitizedName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final savePath = '$basePath/$sanitizedName';

      final file = File(savePath);
      if (await file.exists() && (await file.length() > 0)) {
        debugPrint('[downloadPdf] Found locally cached file in group $gradeId: $savePath');
        return savePath;
      }

      debugPrint('[downloadPdf] Downloading to group $gradeId storage: $savePath from $url');
      await _dio.download(url, savePath);
      return savePath;
    } catch (e) {
      // Fallback check if file exists locally despite network error
      final basePath = await _getOfflineDirectory(gradeId);
      final sanitizedName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final savePath = '$basePath/$sanitizedName';
      final file = File(savePath);
      if (await file.exists() && (await file.length() > 0)) {
        return savePath;
      }
      throw ServerException('فشل تحميل الملف: $e');
    }
  }

  @override
  Future<List<LessonFileModel>> getOfflineDownloadedFiles({String? gradeId}) async {
    try {
      final basePath = await _getOfflineDirectory(gradeId);
      final dir = Directory(basePath);
      if (!await dir.exists()) return [];

      final files = await dir.list().toList();
      final List<LessonFileModel> list = [];

      for (final entity in files) {
        if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
          final stat = await entity.stat();
          if (stat.size > 0) {
            final fileName = entity.path.split(Platform.pathSeparator).last;
            final displayTitle = fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
            list.add(LessonFileModel(
              id: fileName,
              lessonId: 'offline',
              title: displayTitle,
              filePath: entity.path,
              fileType: 'pdf',
              fileSize: stat.size,
            ));
          }
        }
      }
      list.sort((a, b) => a.title.compareTo(b.title));
      return list;
    } catch (e) {
      debugPrint('[getOfflineDownloadedFiles] Error for grade $gradeId: $e');
      return [];
    }
  }
}
