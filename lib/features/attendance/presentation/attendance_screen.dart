import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../auth/presentation/auth_state.dart';
import 'attendance_cubit.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  Set<String> _studiedSessionIds = {};
  String? _currentStudentId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final auth = context.read<AuthCubit>().state;
    if (auth is Authenticated) {
      _currentStudentId = auth.profile.id;
      final cubit = context.read<AttendanceCubit>();
      cubit.loadAttendance(
        auth.profile.id,
        gradeId: auth.profile.gradeId,
      );
      final studied = await cubit.getStudiedLessons(auth.profile.id);
      if (mounted) {
        setState(() => _studiedSessionIds = studied);
      }
    }
  }

  void _toggleStudied(String sessionId, String lessonTitle) async {
    if (_currentStudentId == null) return;
    final cubit = context.read<AttendanceCubit>();
    await cubit.toggleStudiedLesson(_currentStudentId!, sessionId);
    final updated = await cubit.getStudiedLessons(_currentStudentId!);

    if (mounted) {
      final isNowStudied = updated.contains(sessionId);
      setState(() => _studiedSessionIds = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isNowStudied
              ? 'أحسنت! تم تسجيل مذاكرة "$lessonTitle" بنجاح 📖✨'
              : 'تم إلغاء تحديد مذاكرة "$lessonTitle"'),
          backgroundColor: isNowStudied ? AppColors.green : AppColors.surface,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الحضور ومتابعة الدروس'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _loadData,
          ),
        ],
      ),
      body: BlocBuilder<AttendanceCubit, AttendanceState>(
        builder: (context, state) {
          if (state is AttendanceLoading) {
            return const LoadingView(message: 'جاري تحميل سجل الحضور...');
          }

          if (state is AttendanceError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 48),
                  const SizedBox(height: 12),
                  Text(state.message, style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 14),
                  ElevatedButton(onPressed: _loadData, child: const Text('إعادة المحاولة')),
                ],
              ),
            );
          }

          if (state is AttendanceLoaded) {
            final records = state.records;
            if (records.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.fact_check_outlined, color: AppColors.textFaint, size: 54),
                    const SizedBox(height: 14),
                    Text('لا توجد حصص مسجلة لمجموعتك بعد', style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              );
            }

            final recordedRecords = records.where((r) => r.status != 'not_recorded').toList();
            final presentCount = records.where((r) => r.status == 'present').length;
            final attendanceRate = recordedRecords.isNotEmpty
                ? ((presentCount / recordedRecords.length) * 100).round()
                : 100;
            final studiedCount = records.where((r) => _studiedSessionIds.contains(r.sessionId)).length;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // KPI Summary Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        // Circular Attendance Gauge
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (attendanceRate >= 75 ? AppColors.green : AppColors.red).withValues(alpha: 0.15),
                            border: Border.all(color: attendanceRate >= 75 ? AppColors.green : AppColors.red, width: 2.5),
                          ),
                          child: Center(
                            child: Text(
                              '$attendanceRate%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: attendanceRate >= 75 ? AppColors.green : AppColors.red,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('نسبة الحضور والالتزام', style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('حضرت $presentCount من أصل ${records.length} حصة', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Studied Lessons Counter Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'تمت مذاكرة $studiedCount من ${records.length} درس 📖',
                                  style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text('سجل الحصص ومتابعة المذاكرة', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  ...records.map((r) {
                    final isLate = r.status == 'late' || r.status == 'excused';
                    final isAbsent = r.status == 'absent';
                    final isNotRecorded = r.status == 'not_recorded';

                    Color statusColor = AppColors.green;
                    String statusLabel = 'حاضر ✅';
                    IconData statusIcon = Icons.check_circle_rounded;

                    if (isLate) {
                      statusColor = AppColors.yellow;
                      statusLabel = 'متأخر ⏳';
                      statusIcon = Icons.access_time_filled_rounded;
                    } else if (isAbsent) {
                      statusColor = AppColors.red;
                      statusLabel = 'غائب ❌';
                      statusIcon = Icons.cancel_rounded;
                    } else if (isNotRecorded) {
                      statusColor = AppColors.textFaint;
                      statusLabel = 'قادمة / لم تسجل';
                      statusIcon = Icons.event_available_rounded;
                    }

                    final isStudied = _studiedSessionIds.contains(r.sessionId);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isStudied ? AppColors.green.withValues(alpha: 0.4) : AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(statusIcon, color: statusColor, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.lessonTitle, style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat('yyyy/MM/dd – hh:mm a').format(r.sessionDate),
                                      style: AppTextStyles.bodySmall.copyWith(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 18, color: AppColors.border),
                          // Student Self-Study Checkbox Bar
                          InkWell(
                            onTap: () => _toggleStudied(r.sessionId, r.lessonTitle),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    isStudied ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                    color: isStudied ? AppColors.green : AppColors.textSecondary,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isStudied ? 'تمت مذاكرة هذا الدرس بنجاح' : 'اضغط هنا لتأكيد مذاكرة الدرس',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isStudied ? FontWeight.bold : FontWeight.normal,
                                      color: isStudied ? AppColors.green : AppColors.textSecondary,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (isStudied)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.green.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('مكتمل 📖', style: TextStyle(color: AppColors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
