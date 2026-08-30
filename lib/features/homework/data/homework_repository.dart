import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';

class HomeworkRecordModel {
  final String id;
  final String homeworkId;
  final String homeworkTitle;
  final DateTime? dueDate;
  final String status; // done, submitted, pending, missing
  final String? teacherNotes;

  const HomeworkRecordModel({
    required this.id,
    required this.homeworkId,
    required this.homeworkTitle,
    this.dueDate,
    required this.status,
    this.teacherNotes,
  });

  factory HomeworkRecordModel.fromJson(Map<String, dynamic> json) {
    final hw = json['homeworks'] as Map<String, dynamic>?;
    final hTitle = json['homework_title'] as String? ?? 
        (hw != null ? (hw['title'] ?? hw['homework_title']) as String? : null) ?? 
        json['title'] as String? ?? 
        'واجب دراسي';
    final dDate = json['due_date'] != null
        ? DateTime.tryParse(json['due_date'].toString())
        : (hw != null && hw['due_date'] != null ? DateTime.tryParse(hw['due_date'].toString()) : null);

    return HomeworkRecordModel(
      id: json['id'] as String? ?? '',
      homeworkId: json['homework_id'] as String? ?? (json['id'] as String? ?? ''),
      homeworkTitle: hTitle,
      dueDate: dDate,
      status: json['status'] as String? ?? 'pending',
      teacherNotes: json['teacher_notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'homework_id': homeworkId,
        'homework_title': homeworkTitle,
        'due_date': dueDate?.toIso8601String(),
        'status': status,
        'teacher_notes': teacherNotes,
      };
}

abstract class HomeworkRepository {
  Future<List<HomeworkRecordModel>> getMyHomework(String studentId, {String? gradeId});
  Future<Set<String>> getSolvedHomeworks(String studentId);
  Future<void> toggleSolvedHomework(String studentId, String homeworkId);
}

class HomeworkRepositoryImpl implements HomeworkRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<List<HomeworkRecordModel>> getMyHomework(String studentId, {String? gradeId}) async {
    try {
      // 1. Fetch all assignments for the grade (or all assignments)
      List<dynamic> homeworks = [];
      try {
        var query = _client.from('homeworks').select('*');
        if (gradeId != null && gradeId.isNotEmpty) {
          query = query.eq('grade_id', gradeId);
        }
        homeworks = await query.order('created_at', ascending: false) as List<dynamic>;
      } catch (e) {
        debugPrint('[getMyHomework] homeworks fetch error: $e');
      }

      // 2. Fetch student's homework submission records
      Map<String, Map<String, dynamic>> recordsByHwId = {};
      try {
        final res = await _client
            .from('homework_records')
            .select('*')
            .eq('student_id', studentId);
        for (final r in (res as List<dynamic>)) {
          final hwId = r['homework_id']?.toString() ?? '';
          if (hwId.isNotEmpty) {
            recordsByHwId[hwId] = Map<String, dynamic>.from(r as Map);
          }
        }
      } catch (e) {
        debugPrint('[getMyHomework] homework_records fetch error: $e');
      }

      final List<HomeworkRecordModel> combined = [];

      // If assignments exist from teacher, build full list matching student records
      if (homeworks.isNotEmpty) {
        for (final h in homeworks) {
          final hwId = h['id'].toString();
          final hTitle = h['title']?.toString() ?? 'واجب دراسي';
          final dDate = h['due_date'] != null ? DateTime.tryParse(h['due_date'].toString()) : null;

          final record = recordsByHwId[hwId];
          final status = record?['status']?.toString() ?? 'pending';

          combined.add(HomeworkRecordModel(
            id: record?['id']?.toString() ?? hwId,
            homeworkId: hwId,
            homeworkTitle: hTitle,
            dueDate: dDate,
            status: status,
            teacherNotes: record?['teacher_notes']?.toString(),
          ));
        }
      } else {
        // Fallback to direct records query
        for (final r in recordsByHwId.values) {
          combined.add(HomeworkRecordModel.fromJson(r));
        }
      }

      // Cache the list
      try {
        final prefs = await SharedPreferences.getInstance();
        final encoded = combined.map((h) => jsonEncode(h.toJson())).toList();
        await prefs.setStringList('cached_homework_$studentId', encoded);
      } catch (_) {}

      return combined;
    } catch (e) {
      debugPrint('[getMyHomework] Network error: $e, checking offline cache...');
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getStringList('cached_homework_$studentId');
        if (cached != null && cached.isNotEmpty) {
          return cached.map((s) => HomeworkRecordModel.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
      return [];
    }
  }

  @override
  Future<Set<String>> getSolvedHomeworks(String studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('solved_homeworks_$studentId') ?? [];
      return list.toSet();
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> toggleSolvedHomework(String studentId, String homeworkId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = (prefs.getStringList('solved_homeworks_$studentId') ?? []).toSet();
      if (list.contains(homeworkId)) {
        list.remove(homeworkId);
      } else {
        list.add(homeworkId);
      }
      await prefs.setStringList('solved_homeworks_$studentId', list.toList());
    } catch (_) {}
  }
}
