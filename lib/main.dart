import 'dart:io' show Platform;
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:protocol_handler/protocol_handler.dart';
import 'core/config/supabase_config.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_cubit.dart';
import 'features/curriculum/data/curriculum_repository.dart';
import 'features/curriculum/presentation/curriculum_cubit.dart';
import 'features/exams/data/exams_repository.dart';
import 'features/exams/presentation/exams_cubit.dart';
import 'features/attendance/data/attendance_repository.dart';
import 'features/attendance/presentation/attendance_cubit.dart';
import 'features/homework/data/homework_repository.dart';
import 'features/homework/presentation/homework_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register Windows Desktop URL protocol for Deep Linking
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    try {
      await protocolHandler.register('io.supabase.student');
    } catch (e) {
      debugPrint('ProtocolHandler registration error: $e');
    }
  }

  await SupabaseConfig.initialize();

  final authRepo = AuthRepositoryImpl();
  final curriculumRepo = CurriculumRepositoryImpl();
  final examsRepo = ExamsRepositoryImpl();
  final attendanceRepo = AttendanceRepositoryImpl();
  final homeworkRepo = HomeworkRepositoryImpl();

  final authCubit = AuthCubit(authRepository: authRepo);
  authCubit.checkAuth();

  // Listen to deep links (OAuth callbacks on Windows / Mobile)
  if (!kIsWeb) {
    final appLinks = AppLinks();
    appLinks.uriLinkStream.listen((uri) async {
      debugPrint('[AppLinks] Incoming URI: $uri');
      if (uri.scheme == 'io.supabase.student' || uri.host == 'login-callback') {
        try {
          await SupabaseConfig.client.auth.getSessionFromUrl(uri);
          authCubit.checkAuth();
        } catch (e) {
          debugPrint('[AppLinks] getSessionFromUrl error: $e');
        }
      }
    });

    try {
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null && (initialUri.scheme == 'io.supabase.student' || initialUri.host == 'login-callback')) {
        await SupabaseConfig.client.auth.getSessionFromUrl(initialUri);
        authCubit.checkAuth();
      }
    } catch (_) {}
  }

  runApp(
    StudentApp(
      authRepo: authRepo,
      curriculumRepo: curriculumRepo,
      examsRepo: examsRepo,
      attendanceRepo: attendanceRepo,
      homeworkRepo: homeworkRepo,
      authCubit: authCubit,
    ),
  );
}

class StudentApp extends StatelessWidget {
  final AuthRepository authRepo;
  final CurriculumRepository curriculumRepo;
  final ExamsRepository examsRepo;
  final AttendanceRepository attendanceRepo;
  final HomeworkRepository homeworkRepo;
  final AuthCubit authCubit;

  const StudentApp({
    super.key,
    required this.authRepo,
    required this.curriculumRepo,
    required this.examsRepo,
    required this.attendanceRepo,
    required this.homeworkRepo,
    required this.authCubit,
  });

  @override
  Widget build(BuildContext context) {
    final router = AppRouter.createRouter(authCubit);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: authRepo),
        RepositoryProvider<CurriculumRepository>.value(value: curriculumRepo),
        RepositoryProvider<ExamsRepository>.value(value: examsRepo),
        RepositoryProvider<AttendanceRepository>.value(value: attendanceRepo),
        RepositoryProvider<HomeworkRepository>.value(value: homeworkRepo),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<CurriculumCubit>(
            create: (context) => CurriculumCubit(repository: curriculumRepo),
          ),
          BlocProvider<ExamsCubit>(
            create: (context) => ExamsCubit(repository: examsRepo),
          ),
          BlocProvider<AttendanceCubit>(
            create: (context) => AttendanceCubit(repository: attendanceRepo),
          ),
          BlocProvider<HomeworkCubit>(
            create: (context) => HomeworkCubit(repository: homeworkRepo),
          ),
        ],
        child: MaterialApp.router(
          title: 'منصة الطالب',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          routerConfig: router,
          locale: const Locale('ar'),
          supportedLocales: const [
            Locale('ar'),
            Locale('en'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
  }
}
