import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';

class AttendanceRecordModel {
  final String id;
  final String sessionId;
  final String lessonTitle;
  final DateTime sessionDate;
  final String status; // present, absent, late, excused, not_recorded
  final String? notes;

  const AttendanceRecordModel({
    required this.id,
    required this.sessionId,
    required this.lessonTitle,
    required this.sessionDate,
    required this.status,
    this.notes,
  });

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) {
    final session = json['attendance_sessions'] as Map<String, dynamic>?;
    final lTitle = json['lesson_title'] as String? ?? 
        (session != null ? (session['lesson_title'] ?? session['title']) as String? : null) ?? 
        json['title'] as String? ?? 
        'حصة دراسية';
    final sDate = json['session_date'] != null
        ? DateTime.tryParse(json['session_date'].toString()) ?? DateTime.now()
        : (session != null && session['session_date'] != null
            ? DateTime.tryParse(session['session_date'].toString()) ?? DateTime.now()
            : DateTime.now());

    return AttendanceRecordModel(
      id: json['id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? (json['id'] as String? ?? ''),
      lessonTitle: lTitle,
      sessionDate: sDate,
      status: json['status'] as String? ?? 'not_recorded',
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'session_id': sessionId,
        'lesson_title': lessonTitle,
        'session_date': sessionDate.toIso8601String(),
        'status': status,
        'notes': notes,
      };
}

abstract class AttendanceRepository {
  Future<List<AttendanceRecordModel>> getMyAttendance(String studentId, {String? gradeId});
  Future<Set<String>> getStudiedLessons(String studentId);
  Future<void> toggleStudiedLesson(String studentId, String sessionId);
}

class AttendanceRepositoryImpl implements AttendanceRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<List<AttendanceRecordModel>> getMyAttendance(String studentId, {String? gradeId}) async {
    try {
      // 1. Fetch all attendance sessions for the grade (or all sessions)
      List<dynamic> sessions = [];
      try {
        var query = _client.from('attendance_sessions').select('*');
        if (gradeId != null && gradeId.isNotEmpty) {
          query = query.eq('grade_id', gradeId);
        }
        sessions = await query.order('session_date', ascending: false) as List<dynamic>;
      } catch (e) {
        debugPrint('[getMyAttendance] attendance_sessions fetch error: $e');
      }

      // 2. Fetch student's attendance records
      Map<String, Map<String, dynamic>> recordsBySessionId = {};
      try {
        final res = await _client
            .from('attendance_records')
            .select('*')
            .eq('student_id', studentId);
        for (final r in (res as List<dynamic>)) {
          final sId = r['session_id']?.toString() ?? '';
          if (sId.isNotEmpty) {
            recordsBySessionId[sId] = Map<String, dynamic>.from(r as Map);
          }
        }
      } catch (e) {
        debugPrint('[getMyAttendance] attendance_records fetch error: $e');
      }

      final List<AttendanceRecordModel> combined = [];

      // If sessions exist from teacher, build full list matching student records
      if (sessions.isNotEmpty) {
        for (final s in sessions) {
          final sId = s['id'].toString();
          final sTitle = s['title']?.toString() ?? s['lesson_title']?.toString() ?? 'حصة دراسية';
          final sDate = DateTime.tryParse(s['session_date']?.toString() ?? '') ?? DateTime.now();

          final record = recordsBySessionId[sId];
          final status = record?['status']?.toString() ?? 'not_recorded';

          combined.add(AttendanceRecordModel(
            id: record?['id']?.toString() ?? sId,
            sessionId: sId,
            lessonTitle: sTitle,
            sessionDate: sDate,
            status: status,
            notes: record?['notes']?.toString(),
          ));
        }
      } else {
        // Fallback to direct attendance_records query if sessions table was not used
        for (final r in recordsBySessionId.values) {
          combined.add(AttendanceRecordModel.fromJson(r));
        }
      }

      // Cache the result
      try {
        final prefs = await SharedPreferences.getInstance();
        final encoded = combined.map((a) => jsonEncode(a.toJson())).toList();
        await prefs.setStringList('cached_attendance_$studentId', encoded);
      } catch (_) {}

      return combined;
    } catch (e) {
      debugPrint('[getMyAttendance] Network error: $e, checking offline cache...');
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getStringList('cached_attendance_$studentId');
        if (cached != null && cached.isNotEmpty) {
          return cached.map((s) => AttendanceRecordModel.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
      return [];
    }
  }

  @override
  Future<Set<String>> getStudiedLessons(String studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('studied_lessons_$studentId') ?? [];
      return list.toSet();
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> toggleStudiedLesson(String studentId, String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = (prefs.getStringList('studied_lessons_$studentId') ?? []).toSet();
      if (list.contains(sessionId)) {
        list.remove(sessionId);
      } else {
        list.add(sessionId);
      }
      await prefs.setStringList('studied_lessons_$studentId', list.toList());
    } catch (_) {}
  }
}
