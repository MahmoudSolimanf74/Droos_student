import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/errors/exceptions.dart';
import '../domain/exam_models.dart';

abstract class ExamsRepository {
  Future<List<ExamModel>> getExamsForGrade(String gradeId);
  Future<List<ExamQuestionModel>> getExamQuestions(String examId);
  Future<ExamResultModel> submitExamAttempt({required String examId, required List<Map<String, dynamic>> answers});
  Future<List<Map<String, dynamic>>> getMyAttempts(String studentId);
  Future<List<ExamModel>> getOfflineExams(String gradeId);
  Future<bool> isExamDownloaded(String examId);
  Future<void> downloadExamForOffline(ExamModel exam);
  Future<void> deleteOfflineExam(String examId, String gradeId);
}

class ExamsRepositoryImpl implements ExamsRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<List<ExamModel>> getExamsForGrade(String gradeId) async {
    try {
      List<dynamic> res;
      try {
        res = await _client
            .from('exams')
            .select('*, exam_questions(id)')
            .eq('grade_id', gradeId)
            .eq('is_active', true)
            .order('created_at', ascending: false);
      } catch (_) {
        res = await _client
            .from('exams')
            .select()
            .eq('grade_id', gradeId)
            .eq('is_active', true)
            .order('created_at', ascending: false);
      }

      final list = res.map((e) => ExamModel.fromJson(e)).toList();

      // Cache exams list for offline access (grade-specific)
      try {
        final prefs = await SharedPreferences.getInstance();
        final encodedList = list.map((e) => jsonEncode(e.toJson())).toList();
        if (gradeId.isNotEmpty) {
          await prefs.setStringList('cached_exams_$gradeId', encodedList);
        }
      } catch (_) {}

      return list;
    } catch (e) {
      debugPrint('[getExamsForGrade] Network error: $e, checking offline cached exams for grade $gradeId...');
      try {
        final prefs = await SharedPreferences.getInstance();
        List<String>? cached;
        if (gradeId.isNotEmpty) {
          cached = prefs.getStringList('cached_exams_$gradeId');
        }

        if (cached != null && cached.isNotEmpty) {
          return cached.map((s) => ExamModel.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
      return [];
    }
  }

  @override
  Future<List<ExamQuestionModel>> getExamQuestions(String examId) async {
    try {
      List<dynamic> res;
      try {
        res = await _client
            .from('exam_questions')
            .select('id, exam_id, question, options, sort_order, correct_answer')
            .eq('exam_id', examId)
            .order('sort_order', ascending: true);
      } catch (_) {
        res = await _client
            .from('exam_questions')
            .select('*')
            .eq('exam_id', examId)
            .order('sort_order', ascending: true);
      }

      final list = res.map((q) => ExamQuestionModel.fromJson(Map<String, dynamic>.from(q as Map))).toList();

      // Cache questions (including correct answers) for offline exam access & offline grading
      try {
        final prefs = await SharedPreferences.getInstance();
        final encodedList = list.map((q) => jsonEncode(q.toJson())).toList();
        await prefs.setStringList('cached_exam_questions_$examId', encodedList);
      } catch (_) {}

      return list;
    } catch (e) {
      debugPrint('[getExamQuestions] Network error: $e, checking offline cached questions...');
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getStringList('cached_exam_questions_$examId');
        if (cached != null && cached.isNotEmpty) {
          return cached.map((s) => ExamQuestionModel.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
      throw const ServerException('عفواً، يرجى الاتصال بالإنترنت لتحميل أسئلة هذا الامتحان');
    }
  }

  String _normalize(dynamic val) {
    if (val == null) return '';
    var s = val.toString().trim().toLowerCase();
    s = s.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), ''); // Remove tashkeel
    s = s.replaceAll(RegExp(r'[إأآٱ]'), 'ا'); // Normalize alef
    s = s.replaceAll(RegExp(r'ة'), 'ه'); // Normalize taa marboota
    s = s.replaceAll(RegExp(r'[ىي]'), 'ي'); // Normalize yaa
    s = s.replaceAll(RegExp(r'\s+'), ' '); // Normalize spaces
    return s.trim();
  }

  String _resolveLetter(dynamic raw, List<String> options) {
    if (raw == null) return '';
    final str = raw.toString().trim();
    if (str.isEmpty) return '';

    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    final upper = str.toUpperCase();
    if (letters.contains(upper)) return upper;

    const arLetters = ['أ', 'ا', 'ب', 'ج', 'د', 'هـ', 'ه'];
    if (arLetters.contains(str)) {
      if (str == 'أ' || str == 'ا') return 'A';
      if (str == 'ب') return 'B';
      if (str == 'ج') return 'C';
      if (str == 'د') return 'D';
      if (str == 'هـ' || str == 'ه') return 'E';
    }

    final numVal = int.tryParse(str);
    if (numVal != null) {
      if (numVal >= 0 && numVal < letters.length) return letters[numVal];
      if (numVal >= 1 && numVal <= letters.length) return letters[numVal - 1];
    }

    if (options.isNotEmpty) {
      final normOpts = options.map((o) => _normalize(o)).toList();
      final idx = normOpts.indexOf(_normalize(str));
      if (idx >= 0 && idx < letters.length) {
        return letters[idx];
      }
    }

    return upper;
  }

  bool _checkAnswerMatch({
    required dynamic correctRaw,
    required String? studentLetter,
    required dynamic studentRaw,
    required dynamic optionsRaw,
  }) {
    if (correctRaw == null) return false;

    // Parse options list
    List<String> options = [];
    if (optionsRaw is List) {
      options = optionsRaw.map((e) => e.toString().trim()).toList();
    } else if (optionsRaw is String) {
      try {
        final decoded = jsonDecode(optionsRaw);
        if (decoded is List) {
          options = decoded.map((e) => e.toString().trim()).toList();
        }
      } catch (_) {}
    }

    final cLetter = _resolveLetter(correctRaw, options);
    final sLetter = (studentLetter != null && studentLetter.isNotEmpty)
        ? _resolveLetter(studentLetter, options)
        : _resolveLetter(studentRaw, options);

    // 1. Direct letter-based comparison (A == A, B == B, etc.)
    if (cLetter.isNotEmpty && sLetter.isNotEmpty) {
      if (cLetter == sLetter) return true;
    }

    // 2. Direct string comparison
    final cNorm = _normalize(correctRaw);
    final sNorm = _normalize(studentRaw);
    if (cNorm.isNotEmpty && sNorm.isNotEmpty && cNorm == sNorm) return true;

    // 3. Option index resolution against text
    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    if (letters.contains(cLetter)) {
      final cIdx = letters.indexOf(cLetter);
      if (cIdx >= 0 && cIdx < options.length) {
        if (_normalize(options[cIdx]) == sNorm) return true;
      }
    }

    return false;
  }

  @override
  Future<ExamResultModel> submitExamAttempt({
    required String examId,
    required List<Map<String, dynamic>> answers,
  }) async {
    final user = _client.auth.currentUser;
    debugPrint('[submitExamAttempt] Submitting exam: $examId with ${answers.length} answers: $answers');

    try {
      // 1. Load questions: First check local cache (guarantees questions & correct answers exist)
      List<Map<String, dynamic>> qList = [];
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getStringList('cached_exam_questions_$examId');
        if (cached != null && cached.isNotEmpty) {
          qList = cached.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
          debugPrint('[submitExamAttempt] Loaded ${qList.length} questions from local cache');
        }
      } catch (cacheErr) {
        debugPrint('[submitExamAttempt] local cache read note: $cacheErr');
      }

      // If online, fetch from DB to get the most up-to-date questions
      try {
        final questions = await _client
            .from('exam_questions')
            .select('*')
            .eq('exam_id', examId);
        final list = questions as List<dynamic>;
        if (list.isNotEmpty) {
          qList = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          debugPrint('[submitExamAttempt] Loaded ${qList.length} questions from Supabase DB');
        }
      } catch (qErr) {
        debugPrint('[submitExamAttempt] load questions from DB note: $qErr');
      }

      // Fallback: search by question IDs
      if (qList.isEmpty && answers.isNotEmpty) {
        try {
          final qIds = answers
              .map((a) => a['question_id']?.toString())
              .where((id) => id != null && id.isNotEmpty)
              .toList();
          if (qIds.isNotEmpty) {
            final res = await _client.from('exam_questions').select('*').inFilter('id', qIds);
            final list = res as List<dynamic>;
            if (list.isNotEmpty) {
              qList = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            }
          }
        } catch (qIdsErr) {
          debugPrint('[submitExamAttempt] fallback inFilter error: $qIdsErr');
        }
      }

      int correctCount = 0;
      final total = qList.isNotEmpty ? qList.length : answers.length;
      final List<Map<String, dynamic>> breakdown = [];

      String studentFullName = user?.userMetadata?['name'] ?? user?.userMetadata?['full_name'] ?? '';
      if (studentFullName.isEmpty && user?.email != null) {
        studentFullName = user!.email!.split('@').first;
      }
      try {
        if (user != null) {
          final pRow = await _client.from('profiles').select('name').eq('id', user.id).maybeSingle();
          if (pRow != null && pRow['name'] != null && pRow['name'].toString().isNotEmpty) {
            studentFullName = pRow['name'].toString();
          }
        }
      } catch (_) {}

      for (final q in qList) {
        final qId = q['id']?.toString() ?? '';
        final qText = q['question']?.toString() ?? q['question_text']?.toString() ?? 'سؤال';
        final correctRaw = q['correct_answer'] ?? q['answer'] ?? q['correct_option'];
        final optionsRaw = q['options'];

        // Parse options list for display
        List<String> options = [];
        if (optionsRaw is List) {
          options = optionsRaw.map((e) => e.toString().trim()).toList();
        } else if (optionsRaw is String) {
          try {
            final d = jsonDecode(optionsRaw);
            if (d is List) options = d.map((e) => e.toString().trim()).toList();
          } catch (_) {}
        }

        // Lookup student answer
        dynamic studentRaw;
        String? studentLetter;
        for (final a in answers) {
          if (a['question_id']?.toString() == qId) {
            studentRaw = a['selected_option'];
            studentLetter = a['selected_letter']?.toString();
            break;
          }
        }

        final isMatch = _checkAnswerMatch(
          correctRaw: correctRaw,
          studentLetter: studentLetter,
          studentRaw: studentRaw,
          optionsRaw: optionsRaw,
        );

        debugPrint('[submitExamAttempt] Q: "$qText" | Correct: "$correctRaw" vs StudentLetter: "$studentLetter", StudentText: "$studentRaw" => Match: $isMatch');

        if (isMatch) {
          correctCount++;
        }

        // Determine human-friendly display for the correct answer
        String correctDisplay = correctRaw?.toString() ?? '';
        final cLetter = _resolveLetter(correctRaw, options);
        const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
        if (letters.contains(cLetter)) {
          final cIdx = letters.indexOf(cLetter);
          if (cIdx >= 0 && cIdx < options.length) {
            correctDisplay = '$cLetter - ${options[cIdx]}';
          } else {
            correctDisplay = cLetter;
          }
        }

        String studentDisplay = studentRaw?.toString() ?? '';
        if (studentDisplay.isEmpty && studentLetter != null && studentLetter.isNotEmpty) {
          studentDisplay = studentLetter;
        }
        if (studentDisplay.isEmpty) {
          studentDisplay = 'لم تتم الإجابة';
        }

        breakdown.add({
          'question_id': qId,
          'question_text': qText,
          'selected_option': studentDisplay,
          'selected_letter': studentLetter ?? '',
          'correct_answer': correctDisplay,
          'correct_letter': cLetter,
          'is_correct': isMatch,
          'points_earned': isMatch ? 1 : 0,
          'student_name': studentFullName,
        });
      }

      final score = total > 0 ? (correctCount / total) * 100 : 0.0;
      final passed = score >= 50.0;

      debugPrint('[submitExamAttempt] Final result: $correctCount / $total ($score%) - Passed: $passed');

      final nowIso = DateTime.now().toIso8601String();

      // 2. Save attempt locally in SharedPreferences immediately (Guarantees local student history & review)
      try {
        final prefs = await SharedPreferences.getInstance();
        final localAttempt = {
          'id': 'local_${DateTime.now().millisecondsSinceEpoch}',
          'exam_id': examId,
          'student_id': user?.id ?? '',
          'student_name': studentFullName,
          'score': score,
          'total_score': 100.0,
          'started_at': nowIso,
          'submitted_at': nowIso,
          'breakdown': breakdown,
          'answers': breakdown,
        };
        final rawHistory = prefs.getStringList('local_student_exam_attempts') ?? [];
        rawHistory.insert(0, jsonEncode(localAttempt));
        await prefs.setStringList('local_student_exam_attempts', rawHistory);
        debugPrint('[submitExamAttempt] Saved local attempt with ${breakdown.length} questions in SharedPreferences successfully!');
      } catch (localErr) {
        debugPrint('[submitExamAttempt] Local cache error: $localErr');
      }

      // 3. Save attempt to Supabase exam_attempts table
      if (user != null) {
        String? studentRowId;
        String? gradeId;
        String? teacherId;

        // Ensure profile has correct name
        if (studentFullName.isNotEmpty) {
          try {
            await _client.from('profiles').upsert({
              'id': user.id,
              'name': studentFullName,
              'email': user.email,
              'role': 'student',
            });
          } catch (_) {}
        }

        // Fetch exam info for grade_id and teacher_id
        try {
          final examRow = await _client.from('exams').select('grade_id, teacher_id').eq('id', examId).maybeSingle();
          if (examRow != null) {
            gradeId = examRow['grade_id']?.toString();
            teacherId = examRow['teacher_id']?.toString();
          }
        } catch (_) {}

        try {
          var studentRow = await _client.from('students').select('id, grade_id').eq('profile_id', user.id).maybeSingle();
          studentRow ??= await _client.from('students').select('id, grade_id').eq('user_id', user.id).maybeSingle();
          
          if (studentRow == null && user.email != null && user.email!.isNotEmpty) {
            studentRow = await _client.from('students').select('id, grade_id').eq('email', user.email!).maybeSingle();
          }

          if (studentRow != null) {
            studentRowId = studentRow['id']?.toString();
            if (studentRow['grade_id'] != null) gradeId = studentRow['grade_id'].toString();
            if (studentFullName.isNotEmpty) {
              try {
                await _client.from('students').update({'name': studentFullName}).eq('id', studentRowId!);
              } catch (_) {}
            }
          } else if (gradeId != null && teacherId != null) {
            // Auto-create student row in students table to satisfy foreign key constraint
            final studentCode = 'STU-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase().substring(0, 6)}';
            final sInsert = await _client.from('students').insert({
              'teacher_id': teacherId,
              'grade_id': gradeId,
              'profile_id': user.id,
              'name': studentFullName,
              'email': user.email,
              'student_code': studentCode,
              'status': 'active',
            }).select('id').single();
            studentRowId = sInsert['id']?.toString();
            debugPrint('[submitExamAttempt] Auto-created student record with ID: $studentRowId');
          }
        } catch (e) {
          debugPrint('[submitExamAttempt] Student record lookup/create note: $e');
        }

        final candidateStudentIds = <String>[
          if (studentRowId != null && studentRowId.isNotEmpty) studentRowId,
          user.id,
        ];

        bool inserted = false;

        // Strategy A: Try RPC if available
        try {
          debugPrint('[submitExamAttempt] Trying RPC submit_exam_attempt...');
          final rpcRes = await _client.rpc('submit_exam_attempt', params: {
            'p_exam_id': examId,
            'p_answers': answers,
          });
          debugPrint('[submitExamAttempt] RPC submit_exam_attempt SUCCESS: $rpcRes');
          inserted = true;
        } catch (rpcErr) {
          debugPrint('[submitExamAttempt] RPC submit_exam_attempt note: $rpcErr');
        }

        // Strategy B: Direct table inserts across candidate student IDs
        if (!inserted) {
          for (final sId in candidateStudentIds) {
            // Attempt with answers json
            try {
              final attemptPayload = <String, dynamic>{
                'exam_id': examId,
                'student_id': sId,
                'score': score,
                'total_score': 100.0,
                'answers': breakdown,
                'started_at': nowIso,
                'submitted_at': nowIso,
              };
              debugPrint('[submitExamAttempt] Inserting to Supabase exam_attempts (with answers) for student_id: $sId');
              await _client.from('exam_attempts').insert(attemptPayload);
              debugPrint('[submitExamAttempt] Supabase insert SUCCESS with student_id: $sId');
              inserted = true;
              break;
            } catch (insertErrWithAnswers) {
              debugPrint('[submitExamAttempt] Insert with answers failed for $sId: $insertErrWithAnswers. Trying minimal payload...');
              
              // Fallback: minimal payload without answers column
              try {
                final minimalPayload = <String, dynamic>{
                  'exam_id': examId,
                  'student_id': sId,
                  'score': score,
                  'total_score': 100.0,
                  'started_at': nowIso,
                  'submitted_at': nowIso,
                };
                await _client.from('exam_attempts').insert(minimalPayload);
                debugPrint('[submitExamAttempt] Minimal Supabase insert SUCCESS with student_id: $sId');
                inserted = true;
                break;
              } catch (minimalErr) {
                debugPrint('[submitExamAttempt] Minimal insert failed for student_id $sId: $minimalErr');
              }
            }
          }
        }

        if (!inserted) {
          debugPrint('[submitExamAttempt] WARNING: Could not insert attempt into Supabase.');
        }
      }

      return ExamResultModel(
        attemptId: examId,
        earnedPoints: correctCount.toDouble(),
        totalPoints: total.toDouble(),
        scorePercentage: score,
        passed: passed,
        passingScore: 50.0,
        breakdown: breakdown,
      );
    } catch (e) {
      debugPrint('[submitExamAttempt] Total evaluation error: $e');
      return ExamResultModel(
        attemptId: examId,
        earnedPoints: 0.0,
        totalPoints: answers.length.toDouble(),
        scorePercentage: 0.0,
        passed: false,
        passingScore: 50.0,
        breakdown: const [],
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getMyAttempts(String studentId) async {
    final List<Map<String, dynamic>> combined = [];
    final Set<String> seenKeys = {};

    // 1. Fetch remote attempts from Supabase
    try {
      final user = _client.auth.currentUser;
      final idsToSearch = <String>{};
      if (studentId.isNotEmpty) idsToSearch.add(studentId);
      if (user != null) {
        idsToSearch.add(user.id);
        try {
          var sRow = await _client.from('students').select('id').eq('profile_id', user.id).maybeSingle();
          sRow ??= await _client.from('students').select('id').eq('user_id', user.id).maybeSingle();
          if (sRow != null && sRow['id'] != null) {
            idsToSearch.add(sRow['id'].toString());
          }
        } catch (_) {}
      }

      List<dynamic> res = [];
      try {
        final r = await _client
            .from('exam_attempts')
            .select('*, exams(id, title, passing_score, duration_minutes)')
            .inFilter('student_id', idsToSearch.toList())
            .order('submitted_at', ascending: false);
        res = r as List<dynamic>;
      } catch (relErr) {
        debugPrint('[getMyAttempts] Relational query note: $relErr. Falling back to direct query...');
        final r = await _client
            .from('exam_attempts')
            .select('*')
            .inFilter('student_id', idsToSearch.toList())
            .order('submitted_at', ascending: false);
        res = r as List<dynamic>;
      }

      for (final item in res) {
        final map = Map<String, dynamic>.from(item as Map);
        final key = '${map['exam_id']}_${map['submitted_at'] ?? map['started_at']}';
        seenKeys.add(key);
        combined.add(map);
      }
    } catch (e) {
      debugPrint('[getMyAttempts] Supabase remote query error: $e');
    }

    // 2. Merge local cached attempts
    try {
      final prefs = await SharedPreferences.getInstance();
      final localList = prefs.getStringList('local_student_exam_attempts') ?? [];
      for (final raw in localList) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          final key = '${map['exam_id']}_${map['submitted_at'] ?? map['started_at']}';
          if (!seenKeys.contains(key)) {
            seenKeys.add(key);
            combined.add(map);
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[getMyAttempts] Local cache read error: $e');
    }

    // Sort by submitted_at descending
    combined.sort((a, b) {
      final aTime = DateTime.tryParse(a['submitted_at']?.toString() ?? a['started_at']?.toString() ?? '') ?? DateTime.now();
      final bTime = DateTime.tryParse(b['submitted_at']?.toString() ?? b['started_at']?.toString() ?? '') ?? DateTime.now();
      return bTime.compareTo(aTime);
    });

    return combined;
  }

  @override
  Future<List<ExamModel>> getOfflineExams(String gradeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = gradeId.isNotEmpty ? 'offline_exams_$gradeId' : 'offline_exams_default';
      final list = prefs.getStringList(key) ?? [];
      return list.map((s) => ExamModel.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[getOfflineExams] error: $e');
      return [];
    }
  }

  @override
  Future<bool> isExamDownloaded(String examId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final questions = prefs.getStringList('cached_exam_questions_$examId');
      return questions != null && questions.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> downloadExamForOffline(ExamModel exam) async {
    try {
      // 1. Fetch & cache questions
      final questions = await getExamQuestions(exam.id);
      final prefs = await SharedPreferences.getInstance();
      final encodedQ = questions.map((q) => jsonEncode(q.toJson())).toList();
      await prefs.setStringList('cached_exam_questions_${exam.id}', encodedQ);

      // 2. Add exam to offline_exams_<gradeId>
      final key = exam.gradeId.isNotEmpty ? 'offline_exams_${exam.gradeId}' : 'offline_exams_default';
      final currentList = prefs.getStringList(key) ?? [];
      final exists = currentList.any((s) {
        try {
          final m = jsonDecode(s) as Map<String, dynamic>;
          return m['id']?.toString() == exam.id;
        } catch (_) {
          return false;
        }
      });

      if (!exists) {
        currentList.add(jsonEncode(exam.toJson()));
        await prefs.setStringList(key, currentList);
      }
      debugPrint('[downloadExamForOffline] Successfully saved exam ${exam.id} for offline use.');
    } catch (e) {
      debugPrint('[downloadExamForOffline] error: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteOfflineExam(String examId, String gradeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_exam_questions_$examId');

      final key = gradeId.isNotEmpty ? 'offline_exams_$gradeId' : 'offline_exams_default';
      final currentList = prefs.getStringList(key) ?? [];
      final updatedList = currentList.where((s) {
        try {
          final m = jsonDecode(s) as Map<String, dynamic>;
          return m['id']?.toString() != examId;
        } catch (_) {
          return false;
        }
      }).toList();

      await prefs.setStringList(key, updatedList);
      debugPrint('[deleteOfflineExam] Deleted offline exam $examId for grade $gradeId.');
    } catch (e) {
      debugPrint('[deleteOfflineExam] error: $e');
    }
  }
}
