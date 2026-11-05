import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../../features/auth/domain/student_profile_model.dart';
import '../../features/auth/presentation/auth_cubit.dart';
import '../../features/auth/presentation/auth_state.dart';
import '../../features/auth/presentation/qr_scanner_screen.dart';

class GroupSwitcherBottomSheet extends StatelessWidget {
  final ValueChanged<StudentGroupEnrollment>? onGroupSwitched;

  const GroupSwitcherBottomSheet({super.key, this.onGroupSwitched});

  static Future<void> show(BuildContext context, {ValueChanged<StudentGroupEnrollment>? onGroupSwitched}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => GroupSwitcherBottomSheet(onGroupSwitched: onGroupSwitched),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) return const SizedBox.shrink();

        final profile = state.profile;
        final enrollments = profile.enrollments;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Drag Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.swap_horiz_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المجموعات والمعلمين المسجل بهم',
                            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'اختر المجموعة للانتقال لدروسها واختباراتها الخاصة',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),

                // Enrollments List
                if (enrollments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'لا توجد مجموعات مسجلة حالياً',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: enrollments.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final enrollment = enrollments[index];
                        final isSelected = enrollment.gradeId == profile.gradeId;

                        return Material(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: () async {
                              Navigator.pop(context);
                              if (!isSelected) {
                                await context.read<AuthCubit>().switchActiveGroup(enrollment);
                                onGroupSwitched?.call(enrollment);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('تم الانتقال إلى مجموعة "${enrollment.gradeName}" مع ${enrollment.teacherName} 🔄'),
                                      backgroundColor: AppColors.primary,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : AppColors.border,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary.withValues(alpha: 0.25)
                                          : Colors.white.withValues(alpha: 0.05),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isSelected ? Icons.check_circle_rounded : Icons.school_rounded,
                                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          enrollment.gradeName,
                                          style: AppTextStyles.titleSmall.copyWith(
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'المعلم: ${enrollment.teacherName}',
                                          style: AppTextStyles.bodySmall.copyWith(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'الحالية',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 14),

                // Add Another Teacher / Group Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5), width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                        label: const Text(
                          'مسح كود QR',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          final scannedCode = await QrScannerScreen.open(context);
                          if (scannedCode != null && scannedCode.isNotEmpty && context.mounted) {
                            final res = await context.read<AuthCubit>().joinGroup(scannedCode);
                            if (context.mounted) {
                              if (res['success'] == true) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res['message'] as String? ?? 'تم الانضمام للمجموعة بنجاح! 🎉'),
                                    backgroundColor: AppColors.green,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res['message'] as String? ?? 'كود المجموعة غير صحيح'),
                                    backgroundColor: AppColors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          foregroundColor: AppColors.textPrimary,
                          elevation: 0,
                          side: const BorderSide(color: AppColors.border, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.keyboard_alt_outlined, size: 20),
                        label: const Text(
                          'كتابة كود',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/join-group');
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
