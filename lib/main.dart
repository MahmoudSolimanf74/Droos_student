import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
  await SupabaseConfig.initialize();

  final authRepo = AuthRepositoryImpl();
  final curriculumRepo = CurriculumRepositoryImpl();
  final examsRepo = ExamsRepositoryImpl();
  final attendanceRepo = AttendanceRepositoryImpl();
  final homeworkRepo = HomeworkRepositoryImpl();

  final authCubit = AuthCubit(authRepository: authRepo);
  authCubit.checkAuth();

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
