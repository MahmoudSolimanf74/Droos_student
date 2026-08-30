import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_cubit.dart';
import '../../features/auth/presentation/auth_state.dart';
import '../../features/auth/presentation/complete_profile_screen.dart';
import '../../features/auth/presentation/join_group_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/curriculum/presentation/curriculum_screen.dart';
import '../../features/curriculum/presentation/pdf_viewer_screen.dart';
import '../../features/exams/domain/exam_models.dart';
import '../../features/exams/presentation/exams_list_screen.dart';
import '../../features/exams/presentation/take_exam_screen.dart';
import '../../features/exams/presentation/exam_result_screen.dart';
import '../../features/attendance/presentation/attendance_screen.dart';
import '../../features/homework/presentation/homework_screen.dart';

class AppRouter {
  static GoRouter createRouter(AuthCubit authCubit) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: _AuthRefreshListenable(authCubit),
      redirect: (context, state) {
        final authState = authCubit.state;
        final isLoggingIn = state.matchedLocation == '/login';
        final isCompletingProfile = state.matchedLocation == '/complete-profile';
        final isJoiningGroup = state.matchedLocation == '/join-group';

        if (authState is AuthInitial || authState is AuthLoading) {
          return null; // Don't redirect while loading
        }

        if (authState is Unauthenticated || authState is AuthError) {
          return isLoggingIn ? null : '/login';
        }

        if (authState is ProfileIncomplete) {
          return isCompletingProfile ? null : '/complete-profile';
        }

        if (authState is Authenticated) {
          final profile = authState.profile;
          if (!profile.isProfileComplete) {
            return isCompletingProfile ? null : '/complete-profile';
          }
          if (!profile.isEnrolledInGroup) {
            return isJoiningGroup ? null : '/join-group';
          }
          if (isLoggingIn || isCompletingProfile || state.matchedLocation == '/') {
            return '/dashboard';
          }
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/complete-profile',
          builder: (context, state) => const CompleteProfileScreen(),
        ),
        GoRoute(
          path: '/join-group',
          builder: (context, state) => const JoinGroupScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/curriculum',
          builder: (context, state) => const CurriculumScreen(),
        ),
        GoRoute(
          path: '/pdf-viewer',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return PdfViewerScreen(
              title: extra['title'] as String? ?? 'ملف دراسي',
              url: extra['url'] as String? ?? '',
            );
          },
        ),
        GoRoute(
          path: '/exams',
          builder: (context, state) => const ExamsListScreen(),
        ),
        GoRoute(
          path: '/take-exam',
          builder: (context, state) {
            final exam = state.extra as ExamModel;
            return TakeExamScreen(exam: exam);
          },
        ),
        GoRoute(
          path: '/exam-result',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>;
            return ExamResultScreen(
              exam: extra['exam'] as ExamModel,
              result: extra['result'] as ExamResultModel,
            );
          },
        ),
        GoRoute(
          path: '/attendance',
          builder: (context, state) => const AttendanceScreen(),
        ),
        GoRoute(
          path: '/homework',
          builder: (context, state) => const HomeworkScreen(),
        ),
      ],
    );
  }
}

class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(AuthCubit cubit) {
    cubit.stream.listen((_) => notifyListeners());
  }
}
