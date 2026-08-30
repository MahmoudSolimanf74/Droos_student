import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../auth/presentation/auth_state.dart';
import 'homework_cubit.dart';

class HomeworkScreen extends StatefulWidget {
  const HomeworkScreen({super.key});

  @override
  State<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends State<HomeworkScreen> {
  Set<String> _solvedHomeworkIds = {};
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
      final cubit = context.read<HomeworkCubit>();
      cubit.loadHomework(
        auth.profile.id,
        gradeId: auth.profile.gradeId,
      );
      final solved = await cubit.getSolvedHomeworks(auth.profile.id);
      if (mounted) {
        setState(() => _solvedHomeworkIds = solved);
      }
    }
  }

  void _toggleSolved(String homeworkId, String homeworkTitle) async {
    if (_currentStudentId == null) return;
    final cubit = context.read<HomeworkCubit>();
    await cubit.toggleSolvedHomework(_currentStudentId!, homeworkId);
    final updated = await cubit.getSolvedHomeworks(_currentStudentId!);

    if (mounted) {
      final isNowSolved = updated.contains(homeworkId);
      setState(() => _solvedHomeworkIds = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isNowSolved
              ? 'ممتاز! تم تأكيد حل واجب "$homeworkTitle" بنجاح ✍️✨'
              : 'تم إلغاء تحديد حل واجب "$homeworkTitle"'),
          backgroundColor: isNowSolved ? AppColors.green : AppColors.surface,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الواجبات والمهام الدراسية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _loadData,
          ),
        ],
      ),
      body: BlocBuilder<HomeworkCubit, HomeworkState>(
        builder: (context, state) {
          if (state is HomeworkLoading) {
            return const LoadingView(message: 'جاري تحميل الواجبات...');
          }

          if (state is HomeworkError) {
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

          if (state is HomeworkLoaded) {
            final records = state.records;
            if (records.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.assignment_turned_in_outlined, color: AppColors.textFaint, size: 54),
                    const SizedBox(height: 14),
                    Text('لا توجد واجبات مسجلة لمجموعتك حالياً', style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              );
            }

            final doneCount = records.where((r) => r.status == 'done' || r.status == 'submitted').length;
            final solvedCount = records.where((r) => _solvedHomeworkIds.contains(r.homeworkId)).length;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Summary Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.secondary.withValues(alpha: 0.15),
                          ),
                          child: const Icon(Icons.task_alt_rounded, color: AppColors.secondary, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('إنجاز ومتابعة الواجبات', style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('تم اعتماد تسليم $doneCount من أصل ${records.length} واجب ✅', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'تم حل $solvedCount من ${records.length} واجب بنفسك ✍️',
                                  style: const TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text('قائمة الواجبات والمهام', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  ...records.map((r) {
                    final isSubmitted = r.status == 'done' || r.status == 'submitted';
                    final Color statusColor = isSubmitted ? AppColors.green : AppColors.red;
                    final String statusLabel = isSubmitted ? 'تم التسليم ✅' : 'لم يتم التسليم ❌';

                    final isSolved = _solvedHomeworkIds.contains(r.homeworkId);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isSolved ? AppColors.green.withValues(alpha: 0.4) : AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isSubmitted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                color: statusColor,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.homeworkTitle, style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                                    if (r.dueDate != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'موعد التسليم: ${DateFormat('yyyy/MM/dd').format(r.dueDate!)}',
                                        style: AppTextStyles.bodySmall.copyWith(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                    if (r.teacherNotes != null && r.teacherNotes!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text('ملاحظة المعلم: ${r.teacherNotes}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontSize: 11)),
                                    ],
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
                          // Student Self-Solve Checkbox Bar
                          InkWell(
                            onTap: () => _toggleSolved(r.homeworkId, r.homeworkTitle),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    isSolved ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                    color: isSolved ? AppColors.green : AppColors.textSecondary,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isSolved ? 'تم حل هذا الواجب والتدرب عليه' : 'اضغط هنا لتأكيد أنك حللت الواجب',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSolved ? FontWeight.bold : FontWeight.normal,
                                      color: isSolved ? AppColors.green : AppColors.textSecondary,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (isSolved)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.green.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('محلول ✍️', style: TextStyle(color: AppColors.green, fontSize: 10, fontWeight: FontWeight.bold)),
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
