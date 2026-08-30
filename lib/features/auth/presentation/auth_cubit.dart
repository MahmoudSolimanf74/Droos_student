import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../../core/config/supabase_config.dart';
import '../data/auth_repository.dart';
import '../domain/student_profile_model.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  StreamSubscription<sb.AuthState>? _authSubscription;
  static const String _kOfflineProfileKey = 'cached_last_active_student_profile';

  AuthCubit({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(AuthInitial()) {
    _authSubscription = SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      if (data.event == sb.AuthChangeEvent.signedIn || data.event == sb.AuthChangeEvent.tokenRefreshed) {
        checkAuth();
      } else if (data.event == sb.AuthChangeEvent.signedOut) {
        emit(Unauthenticated());
      }
    });
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }

  Future<void> _saveOfflineProfile(StudentProfileModel profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kOfflineProfileKey, jsonEncode(profile.toJson()));
    } catch (_) {}
  }

  Future<StudentProfileModel?> _loadOfflineProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kOfflineProfileKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return StudentProfileModel.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }

  Future<void> checkAuth() async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.getCurrentUser();
      if (user == null) {
        final offlineProfile = await _loadOfflineProfile();
        if (offlineProfile != null && offlineProfile.isProfileComplete) {
          debugPrint('[AuthCubit] Offline startup: loaded cached profile for ${offlineProfile.fullName}');
          emit(Authenticated(offlineProfile));
          return;
        }
        emit(Unauthenticated());
        return;
      }

      final profile = await _authRepository.getStudentProfile();
      if (profile != null && profile.isProfileComplete) {
        await _saveOfflineProfile(profile);
        emit(Authenticated(profile));
      } else {
        final offlineProfile = await _loadOfflineProfile();
        if (offlineProfile != null && offlineProfile.isProfileComplete) {
          emit(Authenticated(offlineProfile));
        } else if (profile != null) {
          emit(ProfileIncomplete(profile));
        } else {
          emit(ProfileIncomplete(StudentProfileModel(id: '', userId: user.id, fullName: '', phone: '', parentPhone: '')));
        }
      }
    } catch (e) {
      debugPrint('[AuthCubit] checkAuth network exception: $e. Checking offline cache...');
      final offlineProfile = await _loadOfflineProfile();
      if (offlineProfile != null && offlineProfile.isProfileComplete) {
        emit(Authenticated(offlineProfile));
      } else {
        emit(Unauthenticated());
      }
    }
  }

  Future<void> signInWithGoogle() async {
    emit(AuthLoading());
    try {
      final profile = await _authRepository.signInWithGoogle();
      if (profile.isProfileComplete) {
        await _saveOfflineProfile(profile);
        emit(Authenticated(profile));
      } else {
        emit(ProfileIncomplete(profile));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    emit(AuthLoading());
    try {
      final profile = await _authRepository.signInWithEmail(email: email, password: password);
      if (profile.isProfileComplete) {
        await _saveOfflineProfile(profile);
        emit(Authenticated(profile));
      } else {
        emit(ProfileIncomplete(profile));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    emit(AuthLoading());
    try {
      final profile = await _authRepository.signUpWithEmail(email: email, password: password);
      emit(ProfileIncomplete(profile));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> completeProfile({
    required String fullName,
    required String phone,
    required String parentPhone,
  }) async {
    emit(AuthLoading());
    try {
      final profile = await _authRepository.completeProfile(
        fullName: fullName,
        phone: phone,
        parentPhone: parentPhone,
      );
      if (profile.isProfileComplete) {
        await _saveOfflineProfile(profile);
      }
      emit(Authenticated(profile));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> updateProfileName(String newName) async {
    final previousState = state;
    emit(AuthLoading());
    try {
      final updatedProfile = await _authRepository.updateProfileName(newName);
      if (updatedProfile.isProfileComplete) {
        await _saveOfflineProfile(updatedProfile);
      }
      emit(Authenticated(updatedProfile));
    } catch (e) {
      emit(AuthError(e.toString()));
      if (previousState is Authenticated) {
        emit(previousState);
      }
    }
  }

  Future<Map<String, dynamic>> joinGroup(String code) async {
    try {
      final res = await _authRepository.joinGroupByCode(code);
      if (res['success'] == true) {
        final targetGradeId = res['grade_id'] as String?;
        final targetGradeName = res['grade_name'] as String?;
        final teacherName = res['teacher_name'] as String?;
        final studentRecordId = res['student_record_id'] as String? ?? '';

        var profile = await _authRepository.getStudentProfile(activeGradeId: targetGradeId);
        if (profile != null) {
          if ((profile.gradeId == null || profile.gradeId!.isEmpty) && targetGradeId != null && targetGradeId.isNotEmpty) {
            final enrollment = StudentGroupEnrollment(
              studentRecordId: studentRecordId.isNotEmpty ? studentRecordId : profile.id,
              gradeId: targetGradeId,
              gradeName: targetGradeName ?? 'المجموعة الدراسية',
              teacherId: profile.teacherId ?? '',
              teacherName: teacherName ?? 'المعلم',
            );
            profile = profile.copyWith(
              id: studentRecordId.isNotEmpty ? studentRecordId : profile.id,
              gradeId: targetGradeId,
              gradeName: targetGradeName,
              teacherName: teacherName,
              enrollments: [enrollment, ...profile.enrollments],
            );
          }
          if (profile.isProfileComplete) {
            await _saveOfflineProfile(profile);
          }
          emit(Authenticated(profile));
        }
        return {
          'success': true,
          'message': res['message'] ?? 'تم الانضمام للمجموعة بنجاح! 🎉',
        };
      }
      return {
        'success': false,
        'message': res['message'] as String? ?? 'كود المجموعة غير صحيح أو غير موجود',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', '').replaceAll('ServerException: ', ''),
      };
    }
  }

  Future<void> switchActiveGroup(StudentGroupEnrollment enrollment) async {
    try {
      await _authRepository.setActiveGrade(enrollment.gradeId);
      final profile = await _authRepository.getStudentProfile(activeGradeId: enrollment.gradeId);
      if (profile != null) {
        if (profile.isProfileComplete) {
          await _saveOfflineProfile(profile);
        }
        emit(Authenticated(profile));
      }
    } catch (_) {
      if (state is Authenticated) {
        final current = (state as Authenticated).profile;
        final updated = current.copyWith(
          id: enrollment.studentRecordId,
          gradeId: enrollment.gradeId,
          gradeName: enrollment.gradeName,
          teacherId: enrollment.teacherId,
          teacherName: enrollment.teacherName,
        );
        await _saveOfflineProfile(updated);
        emit(Authenticated(updated));
      }
    }
  }

  Future<void> signOut() async {
    emit(AuthLoading());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kOfflineProfileKey);
    } catch (_) {}
    await _authRepository.signOut();
    emit(Unauthenticated());
  }
}
