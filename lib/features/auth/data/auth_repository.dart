import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/errors/exceptions.dart';
import '../domain/student_profile_model.dart';

abstract class AuthRepository {
  Future<User?> getCurrentUser();
  Future<StudentProfileModel?> getStudentProfile({String? activeGradeId});
  Future<StudentProfileModel> signInWithGoogle();
  Future<StudentProfileModel> signInWithEmail({required String email, required String password});
  Future<StudentProfileModel> signUpWithEmail({required String email, required String password});
  Future<StudentProfileModel> completeProfile({required String fullName, required String phone, required String parentPhone});
  Future<StudentProfileModel> updateProfileName(String newName);
  Future<StudentProfileModel> updateProfile({required String fullName, required String phone, required String parentPhone});
  Future<Map<String, dynamic>> joinGroupByCode(String code);
  Future<void> setActiveGrade(String gradeId);
  Future<void> signOut();
}

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _client = SupabaseConfig.client;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  @override
  Future<User?> getCurrentUser() async {
    return _client.auth.currentUser;
  }

  @override
  Future<void> setActiveGrade(String gradeId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_grade_id_${user.id}', gradeId);
    } catch (_) {}
  }

  String _cleanPhone(String? phone) {
    if (phone == null) return '';
    var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0020')) {
      digits = digits.substring(4);
    } else if (digits.startsWith('20') && digits.length > 10) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('0') && digits.length > 9) {
      digits = digits.substring(1);
    }
    return digits;
  }

  Future<List<Map<String, dynamic>>> _fetchStudentRowsForUser(
    User user, {
    String? studentPhone,
    String? studentEmail,
    String? studentName,
    String? targetGradeId,
  }) async {
    final List<Map<String, dynamic>> results = [];
    final Set<String> seenIds = {};

    void addRows(List<dynamic> rows) {
      for (final r in rows) {
        final map = Map<String, dynamic>.from(r as Map);
        final id = map['id']?.toString() ?? '';
        if (id.isNotEmpty && !seenIds.contains(id)) {
          seenIds.add(id);
          results.add(map);
        }
      }
    }

    // 1. Try by profile_id
    try {
      final res = await _client.from('students').select('*').eq('profile_id', user.id).order('created_at', ascending: false);
      addRows(res as List<dynamic>);
    } catch (_) {}

    // 2. Try by user_id
    try {
      final res = await _client.from('students').select('*').eq('user_id', user.id).order('created_at', ascending: false);
      addRows(res as List<dynamic>);
    } catch (_) {}

    // 3. Try by email
    final email = (studentEmail ?? user.email ?? '').trim();
    if (email.isNotEmpty) {
      try {
        final res = await _client.from('students').select('*').ilike('email', email).order('created_at', ascending: false);
        addRows(res as List<dynamic>);
      } catch (_) {}
    }

    // 4. Try by phone
    final phone = (studentPhone != null && studentPhone.isNotEmpty)
        ? studentPhone
        : (user.userMetadata?['phone'] as String? ?? '');
    final cleanPhone = _cleanPhone(phone);
    if (phone.isNotEmpty) {
      try {
        final res = await _client.from('students').select('*').eq('phone', phone).order('created_at', ascending: false);
        addRows(res as List<dynamic>);
      } catch (_) {}
      if (cleanPhone.isNotEmpty && cleanPhone != phone) {
        try {
          final res = await _client.from('students').select('*').ilike('phone', '%$cleanPhone%').order('created_at', ascending: false);
          addRows(res as List<dynamic>);
        } catch (_) {}
      }
    }

    // 5. Try matching within targetGradeId (if specified) by phone, email, or name
    if (targetGradeId != null && targetGradeId.isNotEmpty) {
      try {
        final res = await _client.from('students').select('*').eq('grade_id', targetGradeId);
        for (final item in (res as List<dynamic>)) {
          final map = Map<String, dynamic>.from(item as Map);
          final rPhone = map['phone']?.toString() ?? '';
          final rCleanPhone = _cleanPhone(rPhone);
          final rEmail = (map['email']?.toString() ?? '').trim().toLowerCase();
          final rName = (map['name']?.toString() ?? '').trim().toLowerCase();
          final rProfId = map['profile_id']?.toString() ?? '';
          final rUserId = map['user_id']?.toString() ?? '';

          bool isMatch = false;
          if (rProfId == user.id || rUserId == user.id) isMatch = true;
          if (!isMatch && email.isNotEmpty && rEmail.isNotEmpty && rEmail == email.toLowerCase()) isMatch = true;
          if (!isMatch && cleanPhone.isNotEmpty && rCleanPhone.isNotEmpty && rCleanPhone == cleanPhone) isMatch = true;
          if (!isMatch && studentName != null && studentName.isNotEmpty && rName.isNotEmpty && rName == studentName.trim().toLowerCase()) {
            isMatch = true;
          }

          if (isMatch) {
            final id = map['id']?.toString() ?? '';
            if (id.isNotEmpty && !seenIds.contains(id)) {
              seenIds.add(id);
              results.add(map);
            }
          }
        }
      } catch (_) {}
    }

    // 6. Try by cached student record ID in SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStudentId = prefs.getString('cached_student_record_id_${user.id}');
      if (cachedStudentId != null && cachedStudentId.isNotEmpty && !seenIds.contains(cachedStudentId)) {
        final res = await _client.from('students').select('*').eq('id', cachedStudentId).maybeSingle();
        if (res != null) {
          addRows([res]);
        }
      }
    } catch (_) {}

    return results;
  }

  @override
  Future<StudentProfileModel?> getStudentProfile({String? activeGradeId}) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      // 1. Get profile name from auth metadata or profiles table
      String fullNameFromProfile = user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? '';
      String phoneFromProfile = user.userMetadata?['phone'] as String? ?? '';
      String parentPhoneFromProfile = user.userMetadata?['parent_phone'] as String? ?? '';

      try {
        final profileRow = await _client
            .from('profiles')
            .select('name, phone, parent_phone')
            .eq('id', user.id)
            .maybeSingle();

        if (profileRow != null) {
          if (profileRow['name'] != null && (profileRow['name'] as String).isNotEmpty) {
            fullNameFromProfile = profileRow['name'] as String;
          }
          if (profileRow['phone'] != null && (profileRow['phone'] as String).isNotEmpty) {
            phoneFromProfile = profileRow['phone'] as String;
          }
          if (profileRow['parent_phone'] != null && (profileRow['parent_phone'] as String).isNotEmpty) {
            parentPhoneFromProfile = profileRow['parent_phone'] as String;
          }
        }
      } catch (_) {}

      // 2. Fetch ALL student records matching profile_id, user_id, email, phone, or cached ID
      final studentRows = await _fetchStudentRowsForUser(
        user,
        studentPhone: phoneFromProfile,
        studentEmail: user.email,
      );

      final prefs = await SharedPreferences.getInstance();
      final savedActiveGrade = activeGradeId ?? prefs.getString('active_grade_id_${user.id}');

      if (studentRows.isEmpty) {
        String? gName;
        String? tName;
        String? tId;
        if (savedActiveGrade != null && savedActiveGrade.isNotEmpty) {
          try {
            final gRow = await _client.from('grades').select('name, teacher_id').eq('id', savedActiveGrade).maybeSingle();
            if (gRow != null) {
              gName = gRow['name'] as String?;
              tId = gRow['teacher_id'] as String?;
              if (tId != null && tId.isNotEmpty) {
                final tRow = await _client.from('profiles').select('name').eq('id', tId).maybeSingle();
                if (tRow != null) tName = tRow['name'] as String?;
              }
            }
          } catch (_) {}
        }

        final fallback = StudentProfileModel(
          id: prefs.getString('cached_student_record_id_${user.id}') ?? '',
          userId: user.id,
          fullName: fullNameFromProfile,
          phone: phoneFromProfile,
          parentPhone: parentPhoneFromProfile,
          gradeId: savedActiveGrade,
          gradeName: gName,
          teacherId: tId,
          teacherName: tName,
          enrollments: (savedActiveGrade != null && savedActiveGrade.isNotEmpty)
              ? [
                  StudentGroupEnrollment(
                    studentRecordId: prefs.getString('cached_student_record_id_${user.id}') ?? '',
                    gradeId: savedActiveGrade,
                    gradeName: gName ?? 'المجموعة الدراسية',
                    teacherId: tId ?? '',
                    teacherName: tName ?? 'المعلم',
                  )
                ]
              : const [],
        );

        try {
          await prefs.setString('cached_student_profile_${user.id}', jsonEncode(fallback.toJson()));
        } catch (_) {}

        return fallback;
      }

      // 3. Build group enrollments list (1 group per teacher)
      final Map<String, StudentGroupEnrollment> enrollmentsByTeacher = {};
      final List<StudentGroupEnrollment> allEnrollments = [];

      for (final row in studentRows) {
        final gId = row['grade_id']?.toString() ?? '';
        var tId = row['teacher_id']?.toString() ?? '';
        String gName = 'المجموعة الدراسية';
        String tName = 'المعلم';

        if (gId.isNotEmpty) {
          try {
            final gRow = await _client.from('grades').select('name, teacher_id').eq('id', gId).maybeSingle();
            if (gRow != null) {
              gName = gRow['name'] as String? ?? gName;
              final gTeacherId = gRow['teacher_id'] as String?;
              if (tId.isEmpty && gTeacherId != null) tId = gTeacherId;
            }
          } catch (_) {}
        }

        if (tId.isNotEmpty) {
          try {
            final tRow = await _client.from('profiles').select('name').eq('id', tId).maybeSingle();
            if (tRow != null && tRow['name'] != null) {
              tName = tRow['name'] as String;
            }
          } catch (_) {}
        }

        final enrollment = StudentGroupEnrollment(
          studentRecordId: row['id']?.toString() ?? '',
          gradeId: gId,
          gradeName: gName,
          teacherId: tId,
          teacherName: tName,
        );

        // Keep 1 latest group per teacher
        final teacherKey = tId.isNotEmpty ? tId : gId;
        if (!enrollmentsByTeacher.containsKey(teacherKey)) {
          enrollmentsByTeacher[teacherKey] = enrollment;
          allEnrollments.add(enrollment);
        }
      }

      // 4. Determine Active Enrollment
      StudentGroupEnrollment? activeEnrollment;
      if (savedActiveGrade != null && savedActiveGrade.isNotEmpty) {
        for (final e in allEnrollments) {
          if (e.gradeId == savedActiveGrade) {
            activeEnrollment = e;
            break;
          }
        }
      }

      activeEnrollment ??= allEnrollments.isNotEmpty ? allEnrollments.first : null;

      final firstRow = studentRows.first;
      final studentName = (firstRow['name'] as String? ?? '').isNotEmpty
          ? (firstRow['name'] as String)
          : fullNameFromProfile;
      final studentPhone = (firstRow['phone'] as String? ?? '').isNotEmpty
          ? (firstRow['phone'] as String)
          : phoneFromProfile;
      final parentPhone = (firstRow['parent_phone'] as String? ?? '').isNotEmpty
          ? (firstRow['parent_phone'] as String)
          : parentPhoneFromProfile;

      final model = StudentProfileModel(
        id: activeEnrollment?.studentRecordId ?? firstRow['id']?.toString() ?? '',
        userId: user.id,
        fullName: studentName,
        phone: studentPhone,
        parentPhone: parentPhone,
        gradeId: activeEnrollment?.gradeId ?? savedActiveGrade,
        gradeName: activeEnrollment?.gradeName,
        teacherId: activeEnrollment?.teacherId,
        teacherName: activeEnrollment?.teacherName,
        enrollments: allEnrollments,
      );

      try {
        await prefs.setString('cached_student_profile_${user.id}', jsonEncode(model.toJson()));
      } catch (_) {}

      return model;
    } catch (e) {
      debugPrint('[getStudentProfile] Network/query error: $e, checking offline cache...');
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cached_student_profile_${user.id}');
        if (cached != null) {
          final decoded = jsonDecode(cached) as Map<String, dynamic>;
          return StudentProfileModel.fromJson(decoded);
        }
      } catch (_) {}
      return null;
    }
  }

  String _formatEmail(String input) {
    final trimmed = input.trim();
    if (trimmed.contains('@')) return trimmed.toLowerCase();
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    return 'student_$digits@classpilot.app';
  }

  @override
  Future<StudentProfileModel> signInWithEmail({required String email, required String password}) async {
    try {
      final formattedEmail = _formatEmail(email);
      final res = await _client.auth.signInWithPassword(email: formattedEmail, password: password);
      if (res.user == null) throw const AppAuthException('فشل تسجيل الدخول');

      final profile = await getStudentProfile();
      if (profile != null) return profile;

      return StudentProfileModel(
        id: '',
        userId: res.user!.id,
        fullName: '',
        phone: !email.contains('@') ? email.trim() : '',
        parentPhone: '',
      );
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('invalid login credentials') || msg.contains('invalid_grant')) {
        throw const ServerException('بيانات الدخول غير صحيحة. يرجى التأكد من رقم الهاتف أو البريد وكلمة المرور.');
      }
      throw ServerException('خطأ في تسجيل الدخول: $e');
    }
  }

  @override
  Future<StudentProfileModel> signInWithGoogle() async {
    try {
      bool nativeSuccess = false;
      String? googleDisplayName;
      String? googleEmail;

      // 1. Try native Google Sign-in on Mobile / Desktop
      if (!kIsWeb) {
        try {
          final googleUser = await _googleSignIn.signIn();
          if (googleUser != null) {
            googleDisplayName = googleUser.displayName;
            googleEmail = googleUser.email;
            final googleAuth = await googleUser.authentication;
            final accessToken = googleAuth.accessToken;
            final idToken = googleAuth.idToken;

            if (idToken != null && idToken.isNotEmpty) {
              final res = await _client.auth.signInWithIdToken(
                provider: OAuthProvider.google,
                idToken: idToken,
                accessToken: accessToken,
              );
              if (res.user != null) {
                nativeSuccess = true;
              }
            }
          }
        } catch (nativeErr) {
          debugPrint('[signInWithGoogle] Native sign-in note: $nativeErr, trying OAuth browser flow...');
        }
      }

      // 2. Supabase OAuth (Web / Desktop fallback)
      if (!nativeSuccess && _client.auth.currentUser == null) {
        final origin = kIsWeb ? Uri.base.origin.toLowerCase() : '';
        final redirectUrl = kIsWeb
            ? (origin.contains('localhost')
                ? origin
                : '$origin/Droos_student/')
            : 'io.supabase.student://login-callback';

        debugPrint('[signInWithGoogle] Web redirectUrl: $redirectUrl');

        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: redirectUrl,
          authScreenLaunchMode: LaunchMode.platformDefault,
        );
      }

      final user = _client.auth.currentUser;
      if (user == null) {
        throw const AppAuthException('تم إلغاء أو تعذر تسجيل الدخول بحساب Google');
      }

      final effectiveName = googleDisplayName ??
          user.userMetadata?['full_name'] ??
          user.userMetadata?['name'] ??
          user.email?.split('@').first ??
          'طالب';
      final effectiveEmail = googleEmail ?? user.email ?? '';

      // 3. Auto-create / Upsert in profiles table if new account
      try {
        await _client.from('profiles').upsert({
          'id': user.id,
          'name': effectiveName,
          'email': effectiveEmail,
          'role': 'student',
        });
      } catch (profileErr) {
        debugPrint('[signInWithGoogle] upsert profiles error: $profileErr');
      }

      // 4. Check if student already has a complete profile & enrollments
      final profile = await getStudentProfile();
      if (profile != null && profile.fullName.isNotEmpty) {
        return profile;
      }

      // 5. New student: return profile with Google name pre-filled
      return StudentProfileModel(
        id: '',
        userId: user.id,
        fullName: effectiveName,
        phone: user.userMetadata?['phone'] ?? '',
        parentPhone: user.userMetadata?['parent_phone'] ?? '',
      );
    } catch (e) {
      debugPrint('[signInWithGoogle] Fatal error: $e');
      throw ServerException('خطأ في تسجيل الدخول عبر Google: $e');
    }
  }

  @override
  Future<StudentProfileModel> signUpWithEmail({required String email, required String password}) async {
    try {
      final formattedEmail = _formatEmail(email);
      final res = await _client.auth.signUp(email: formattedEmail, password: password);
      if (res.user == null) throw const AppAuthException('فشل إنشاء الحساب');

      final profile = await getStudentProfile();
      return profile ??
          StudentProfileModel(
            id: '',
            userId: res.user!.id,
            fullName: '',
            phone: !email.contains('@') ? email.trim() : '',
            parentPhone: '',
          );
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('already registered') || msg.contains('user already exists')) {
        throw const ServerException('هذا الحساب مسجل بالفعل. اضغط "تسجيل الدخول" وسجل دخولك.');
      }
      throw ServerException('خطأ في إنشاء الحساب: $e');
    }
  }

  @override
  Future<StudentProfileModel> completeProfile({
    required String fullName,
    required String phone,
    required String parentPhone,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppAuthException('المستخدم غير مسجل');

    try {
      try {
        await _client.auth.updateUser(
          UserAttributes(
            data: {
              'name': fullName,
              'full_name': fullName,
              'phone': phone,
              'parent_phone': parentPhone,
            },
          ),
        );
      } catch (_) {}

      try {
        await _client.from('profiles').upsert({
          'id': user.id,
          'name': fullName,
          'email': user.email,
          'role': 'student',
        });
      } catch (_) {}

      try {
        final existingStudents = await _client
            .from('students')
            .select('id')
            .or('profile_id.eq.${user.id},user_id.eq.${user.id}');

        for (final s in (existingStudents as List<dynamic>)) {
          await _client.from('students').update({
            'name': fullName,
            'phone': phone,
            'parent_phone': parentPhone,
            'status': 'active',
          }).eq('id', s['id']);
        }
      } catch (_) {}

      final updated = await getStudentProfile();
      return updated ??
          StudentProfileModel(
            id: '',
            userId: user.id,
            fullName: fullName,
            phone: phone,
            parentPhone: parentPhone,
          );
    } catch (e) {
      throw ServerException('فشل حفظ البيانات الشخصية ($e)');
    }
  }

  String _normalizeCode(String s) => s.replaceAll(RegExp(r'[\s\-_]+'), '').toLowerCase();

  @override
  Future<Map<String, dynamic>> joinGroupByCode(String code) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppAuthException('المستخدم غير مسجل');

    var cleanCode = code.trim();
    String? tokenParam;
    if (cleanCode.contains('join?') || cleanCode.contains('code=') || cleanCode.contains('token=')) {
      try {
        final uri = Uri.tryParse(cleanCode);
        if (uri != null) {
          if (uri.queryParameters.containsKey('code')) {
            cleanCode = uri.queryParameters['code']!;
          }
          if (uri.queryParameters.containsKey('token')) {
            tokenParam = uri.queryParameters['token'];
          }
        }
      } catch (_) {}
    }

    if (cleanCode.isEmpty && (tokenParam == null || tokenParam.isEmpty)) {
      return {'success': false, 'message': 'يرجى إدخال كود المجموعة'};
    }

    final normalizedInput = _normalizeCode(cleanCode);
    final normalizedToken = tokenParam != null ? _normalizeCode(tokenParam) : null;

    try {
      // 1. Fetch all grades to match
      List<dynamic> gradesList = [];
      try {
        final res = await _client.from('grades').select('*');
        gradesList = res as List<dynamic>;
      } catch (_) {}

      Map<String, dynamic>? matchedGrade;

      for (final item in gradesList) {
        final g = Map<String, dynamic>.from(item as Map);
        final gCode = g['code']?.toString() ?? '';
        final gJoinCode = g['join_code']?.toString() ?? '';
        final gInviteToken = g['invite_token']?.toString() ?? '';
        final gName = g['name']?.toString() ?? '';
        final gId = g['id']?.toString() ?? '';

        if (cleanCode.toLowerCase() == gCode.toLowerCase() ||
            cleanCode.toLowerCase() == gJoinCode.toLowerCase() ||
            cleanCode.toLowerCase() == gName.toLowerCase() ||
            cleanCode == gId ||
            _normalizeCode(gCode) == normalizedInput ||
            _normalizeCode(gJoinCode) == normalizedInput ||
            (normalizedToken != null && _normalizeCode(gInviteToken) == normalizedToken) ||
            _normalizeCode(gName) == normalizedInput) {
          matchedGrade = g;
          break;
        }
      }

      // If not in grades, try groups table
      if (matchedGrade == null) {
        try {
          final res = await _client.from('groups').select('*');
          for (final item in (res as List<dynamic>)) {
            final g = Map<String, dynamic>.from(item as Map);
            final gCode = g['code']?.toString() ?? '';
            final gJoinCode = g['join_code']?.toString() ?? '';
            final gName = g['name']?.toString() ?? '';
            final gId = g['id']?.toString() ?? '';

            if (cleanCode.toLowerCase() == gCode.toLowerCase() ||
                cleanCode.toLowerCase() == gJoinCode.toLowerCase() ||
                cleanCode.toLowerCase() == gName.toLowerCase() ||
                cleanCode == gId ||
                _normalizeCode(gCode) == normalizedInput ||
                _normalizeCode(gJoinCode) == normalizedInput ||
                _normalizeCode(gName) == normalizedInput) {
              matchedGrade = g;
              break;
            }
          }
        } catch (_) {}
      }

      if (matchedGrade == null) {
        return {
          'success': false,
          'message': 'كود المجموعة ($cleanCode) غير موجود. يرجى التأكد من كود المجموعة من المعلم.',
        };
      }

      final grade = matchedGrade;
      final targetGradeId = grade['id'].toString();
      final targetGradeName = grade['name']?.toString() ?? 'المجموعة';
      final teacherId = grade['teacher_id']?.toString();

      String teacherName = 'المعلم';
      if (teacherId != null && teacherId.isNotEmpty) {
        try {
          final teacherProfile = await _client
              .from('profiles')
              .select('name')
              .eq('id', teacherId)
              .maybeSingle();
          if (teacherProfile != null && teacherProfile['name'] != null) {
            teacherName = teacherProfile['name'] as String;
          }
        } catch (_) {}
      }

      String fullNameFromProfile = user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? '';
      String phoneFromProfile = user.userMetadata?['phone'] as String? ?? '';
      String parentPhoneFromProfile = user.userMetadata?['parent_phone'] as String? ?? '';

      try {
        final profileRow = await _client
            .from('profiles')
            .select('name, phone, parent_phone')
            .eq('id', user.id)
            .maybeSingle();

        if (profileRow != null) {
          if (profileRow['name'] != null && (profileRow['name'] as String).isNotEmpty) {
            fullNameFromProfile = profileRow['name'] as String;
          }
          if (profileRow['phone'] != null && (profileRow['phone'] as String).isNotEmpty) {
            phoneFromProfile = profileRow['phone'] as String;
          }
          if (profileRow['parent_phone'] != null && (profileRow['parent_phone'] as String).isNotEmpty) {
            parentPhoneFromProfile = profileRow['parent_phone'] as String;
          }
        }
      } catch (_) {}

      final studentName = fullNameFromProfile.isNotEmpty
          ? fullNameFromProfile
          : (user.userMetadata?['name'] ?? user.userMetadata?['full_name'] ?? 'طالب');
      final studentPhone = phoneFromProfile.isNotEmpty ? phoneFromProfile : (user.userMetadata?['phone'] ?? '');
      final parentPhone = parentPhoneFromProfile.isNotEmpty ? parentPhoneFromProfile : (user.userMetadata?['parent_phone'] ?? '');
      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      final rand = Random();
      final randomSuffix = List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
      final studentCode = 'STU-$randomSuffix';

      // 2. Query ALL existing student enrollments for this user (including within targetGradeId)
      final existingRows = await _fetchStudentRowsForUser(
        user,
        studentPhone: studentPhone,
        studentEmail: user.email,
        studentName: studentName,
        targetGradeId: targetGradeId,
      );

      // Check if student is already enrolled in this exact group or with THIS SAME TEACHER
      Map<String, dynamic>? recordWithSameTeacher;
      for (final r in existingRows) {
        final rTeacherId = r['teacher_id']?.toString();
        final rGradeId = r['grade_id']?.toString();
        if (rGradeId == targetGradeId) {
          recordWithSameTeacher = Map<String, dynamic>.from(r);
          break;
        }
        if (teacherId != null && teacherId.isNotEmpty && rTeacherId != null && rTeacherId == teacherId) {
          recordWithSameTeacher = Map<String, dynamic>.from(r);
          break;
        }
      }

      String successMessage = '';
      String? savedStudentRecordId;

      if (recordWithSameTeacher != null) {
        savedStudentRecordId = recordWithSameTeacher['id']?.toString();
        final currentGradeId = recordWithSameTeacher['grade_id']?.toString();
        
        final updatePayload = <String, dynamic>{
          'grade_id': targetGradeId,
          'status': 'active',
          'name': studentName,
        };
        if (studentPhone.isNotEmpty) updatePayload['phone'] = studentPhone;
        if (parentPhone.isNotEmpty) updatePayload['parent_phone'] = parentPhone;
        if (user.email != null && user.email!.isNotEmpty) updatePayload['email'] = user.email!;

        // Attempt update with profile_id/user_id link
        try {
          final u = Map<String, dynamic>.from(updatePayload);
          u['profile_id'] = user.id;
          if (teacherId != null && teacherId.isNotEmpty) u['teacher_id'] = teacherId;
          await _client.from('students').update(u).eq('id', recordWithSameTeacher['id']);
        } catch (_) {
          try {
            final u = Map<String, dynamic>.from(updatePayload);
            u['user_id'] = user.id;
            await _client.from('students').update(u).eq('id', recordWithSameTeacher['id']);
          } catch (_) {
            try {
              await _client.from('students').update(updatePayload).eq('id', recordWithSameTeacher['id']);
            } catch (_) {}
          }
        }

        // Clean up any other duplicate rows in the database for this student in targetGradeId
        for (final r in existingRows) {
          final otherId = r['id']?.toString();
          if (otherId != null && otherId.isNotEmpty && otherId != savedStudentRecordId && r['grade_id']?.toString() == targetGradeId) {
            try {
              await _client.from('students').delete().eq('id', otherId);
            } catch (_) {}
          }
        }

        if (currentGradeId == targetGradeId) {
          successMessage = 'أنت مسجل بالفعل في مجموعة "$targetGradeName" مع $teacherName ✅';
        } else {
          successMessage = 'تم نقلك وتحديث مجموعتك مع $teacherName إلى "$targetGradeName" بنجاح! 🔄';
        }
      } else {
        // CASE 2: New enrollment -> Robust Cascading Insert
        final insertPayload = <String, dynamic>{
          'grade_id': targetGradeId,
          'name': studentName,
          'student_code': studentCode,
          'status': 'active',
          'created_at': DateTime.now().toIso8601String(),
        };
        if (studentPhone.isNotEmpty) insertPayload['phone'] = studentPhone;
        if (parentPhone.isNotEmpty) insertPayload['parent_phone'] = parentPhone;
        if (user.email != null && user.email!.isNotEmpty) insertPayload['email'] = user.email!;

        Map<String, dynamic>? insertedRow;

        // Try 1: with profile_id and teacher_id
        try {
          final p = Map<String, dynamic>.from(insertPayload);
          p['profile_id'] = user.id;
          if (teacherId != null && teacherId.isNotEmpty) p['teacher_id'] = teacherId;
          final res = await _client.from('students').insert(p).select().single();
          insertedRow = Map<String, dynamic>.from(res);
        } catch (err1) {
          // Try 2: with user_id and teacher_id
          try {
            final p = Map<String, dynamic>.from(insertPayload);
            p['user_id'] = user.id;
            if (teacherId != null && teacherId.isNotEmpty) p['teacher_id'] = teacherId;
            final res = await _client.from('students').insert(p).select().single();
            insertedRow = Map<String, dynamic>.from(res);
          } catch (err2) {
            // Try 3: with profile_id only
            try {
              final p = Map<String, dynamic>.from(insertPayload);
              p['profile_id'] = user.id;
              final res = await _client.from('students').insert(p).select().single();
              insertedRow = Map<String, dynamic>.from(res);
            } catch (err3) {
              // Try 4: with user_id only
              try {
                final p = Map<String, dynamic>.from(insertPayload);
                p['user_id'] = user.id;
                final res = await _client.from('students').insert(p).select().single();
                insertedRow = Map<String, dynamic>.from(res);
              } catch (err4) {
                // Try 5: base payload (grade_id, name, email, phone, parent_phone, student_code, status)
                try {
                  final res = await _client.from('students').insert(insertPayload).select().single();
                  insertedRow = Map<String, dynamic>.from(res);
                } catch (err5) {
                  debugPrint('[joinGroupByCode] All insert attempts failed: $err5');
                  throw ServerException('فشل تسجيل الطالب في المجموعة: $err5');
                }
              }
            }
          }
        }

        savedStudentRecordId = insertedRow['id']?.toString();
        successMessage = 'تم انضمامك بنجاح إلى مجموعة "$targetGradeName" مع $teacherName! 🎉';
      }

      // Save as active grade and cached student id in SharedPreferences
      await setActiveGrade(targetGradeId);
      final prefs = await SharedPreferences.getInstance();
      if (savedStudentRecordId != null && savedStudentRecordId.isNotEmpty) {
        await prefs.setString('cached_student_record_id_${user.id}', savedStudentRecordId);
      }

      return {
        'success': true,
        'student_record_id': savedStudentRecordId,
        'grade_id': targetGradeId,
        'grade_name': targetGradeName,
        'teacher_name': teacherName,
        'message': successMessage,
      };
    } catch (e) {
      debugPrint('[joinGroupByCode] Fatal error: $e');
      throw ServerException('فشل الانضمام للمجموعة: $e');
    }
  }

  @override
  Future<StudentProfileModel> updateProfileName(String newName) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppAuthException('المستخدم غير مسجل');

    final cleanName = newName.trim();
    if (cleanName.isEmpty) throw const ServerException('يرجى إدخال اسم صحيح');

    try {
      try {
        await _client.from('profiles').update({'name': cleanName}).eq('id', user.id);
      } catch (_) {}

      try {
        final existingStudents = await _client
            .from('students')
            .select('id')
            .or('profile_id.eq.${user.id},user_id.eq.${user.id}');

        for (final s in (existingStudents as List<dynamic>)) {
          await _client.from('students').update({'name': cleanName}).eq('id', s['id']);
        }
      } catch (_) {}

      try {
        await _client.auth.updateUser(UserAttributes(data: {'full_name': cleanName, 'name': cleanName}));
      } catch (_) {}

      final updated = await getStudentProfile();
      return updated ??
          StudentProfileModel(
            id: '',
            userId: user.id,
            fullName: cleanName,
            phone: '',
            parentPhone: '',
          );
    } catch (e) {
      throw ServerException('فشل تعديل الاسم: $e');
    }
  }

  @override
  Future<StudentProfileModel> updateProfile({
    required String fullName,
    required String phone,
    required String parentPhone,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppAuthException('المستخدم غير مسجل');

    final cleanName = fullName.trim();
    final cleanPhoneStr = phone.trim();
    final cleanParentPhoneStr = parentPhone.trim();

    if (cleanName.isEmpty) throw const ServerException('يرجى إدخال اسم الطالب');
    if (cleanPhoneStr.isEmpty) throw const ServerException('يرجى إدخال رقم هاتف الطالب');
    if (cleanParentPhoneStr.isEmpty) throw const ServerException('يرجى إدخال رقم هاتف ولي الأمر');

    try {
      // 1. Update auth.users metadata
      try {
        await _client.auth.updateUser(
          UserAttributes(
            data: {
              'name': cleanName,
              'full_name': cleanName,
              'phone': cleanPhoneStr,
              'parent_phone': cleanParentPhoneStr,
            },
          ),
        );
      } catch (authErr) {
        debugPrint('[updateProfile] auth.updateUser note: $authErr');
      }

      // 2. Update profiles table
      try {
        await _client.from('profiles').upsert({
          'id': user.id,
          'name': cleanName,
          'phone': cleanPhoneStr,
          'parent_phone': cleanParentPhoneStr,
          'email': user.email,
          'role': 'student',
        });
      } catch (profileErr) {
        debugPrint('[updateProfile] profiles upsert note: $profileErr');
      }

      // 3. Update all student rows in students table
      try {
        final existingStudents = await _client
            .from('students')
            .select('id')
            .or('profile_id.eq.${user.id},user_id.eq.${user.id}');

        for (final s in (existingStudents as List<dynamic>)) {
          await _client.from('students').update({
            'name': cleanName,
            'phone': cleanPhoneStr,
            'parent_phone': cleanParentPhoneStr,
            'status': 'active',
          }).eq('id', s['id']);
        }
      } catch (studentErr) {
        debugPrint('[updateProfile] students update note: $studentErr');
      }

      // 4. Invalidate and refresh cached profile
      final updated = await getStudentProfile();
      if (updated != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_student_profile_${user.id}', jsonEncode(updated.toJson()));
        return updated;
      }

      return StudentProfileModel(
        id: '',
        userId: user.id,
        fullName: cleanName,
        phone: cleanPhoneStr,
        parentPhone: cleanParentPhoneStr,
      );
    } catch (e) {
      debugPrint('[updateProfile] Error: $e');
      throw ServerException('فشل حفظ وتحديث البيانات: $e');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _client.auth.signOut();
  }
}
