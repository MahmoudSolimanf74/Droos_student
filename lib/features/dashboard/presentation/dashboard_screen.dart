import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/group_switcher_bottom_sheet.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../auth/presentation/auth_state.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _showEditNameDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: 10),
            Text('تعديل اسم الطالب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أدخل اسمك ثلاثي كما تحب أن يظهر لمعلمك وفي نتائج الامتحانات:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'الاسم الكامل',
                hintText: 'مثال: أحمد محمد علي',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                Navigator.pop(ctx);
                await context.read<AuthCubit>().updateProfileName(newName);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تحديث اسمك بنجاح'), backgroundColor: AppColors.green),
                  );
                }
              }
            },
            child: const Text('حفظ التعديل', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final profile = state.profile;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    profile.fullName.isNotEmpty ? profile.fullName : 'طالب',
                    style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _showEditNameDialog(context, profile.fullName),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.edit_rounded, size: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            actions: [
              // Standalone Group / Account Switcher Icon
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.switch_account_rounded, color: AppColors.primary, size: 20),
                ),
                tooltip: 'تبديل المجموعة / الحساب بالكامل',
                onPressed: () => GroupSwitcherBottomSheet.show(context),
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: AppColors.red),
                tooltip: 'تسجيل الخروج',
                onPressed: () {
                  context.read<AuthCubit>().signOut();
                },
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Enrolled Group Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.25),
                          AppColors.surface,
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.groups_rounded, color: AppColors.primary, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          profile.gradeName ?? 'المجموعة الدراسية',
                                          style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      if (profile.enrollments.length > 1)
                                        InkWell(
                                          onTap: () => GroupSwitcherBottomSheet.show(context),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.swap_horiz_rounded, color: Colors.black, size: 16),
                                                SizedBox(width: 4),
                                                Text(
                                                  'تبديل',
                                                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'المعلم: ${profile.teacherName ?? "الأستاذ"}',
                                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Multi-Teacher / Multi-Group Quick Switcher Chips
                        if (profile.enrollments.length > 1) ...[
                          const SizedBox(height: 14),
                          const Divider(height: 1, color: AppColors.border),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'المجموعات المسجل بها (${profile.enrollments.length}):',
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                              InkWell(
                                onTap: () => GroupSwitcherBottomSheet.show(context),
                                child: Text(
                                  'عرض الكل ▾',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: profile.enrollments.map((enrollment) {
                                final isSelected = enrollment.gradeId == profile.gradeId;
                                return Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: InkWell(
                                    onTap: () {
                                      if (!isSelected) {
                                        context.read<AuthCubit>().switchActiveGroup(enrollment);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('تم الانتقال إلى مجموعة "${enrollment.gradeName}" مع ${enrollment.teacherName} 🔄'),
                                            backgroundColor: AppColors.primary,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surface,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected ? AppColors.primary : AppColors.border,
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isSelected ? Icons.check_circle_rounded : Icons.school_outlined,
                                            color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${enrollment.teacherName}: ${enrollment.gradeName}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text('هاتفك: ${profile.phone}', style: AppTextStyles.bodySmall),
                            const Spacer(),
                            InkWell(
                              onTap: () => context.push('/join-group'),
                              child: Text(
                                '➕ إضافة معلم / مجموعة أخرى',
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section Title
                  Text('الخدمات والأقسام', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),

                  // 4 Main Feature Cards (Grid)
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.15,
                    children: [
                      _buildFeatureCard(
                        context: context,
                        title: 'الدروس والـ PDF',
                        subtitle: 'مذكرات وملازم الحصص',
                        icon: Icons.menu_book_rounded,
                        color: AppColors.primary,
                        onTap: () => context.push('/curriculum'),
                      ),
                      _buildFeatureCard(
                        context: context,
                        title: 'الامتحانات',
                        subtitle: 'حل الاختبارات والدرجات',
                        icon: Icons.quiz_rounded,
                        color: AppColors.yellow,
                        onTap: () => context.push('/exams'),
                      ),
                      _buildFeatureCard(
                        context: context,
                        title: 'سجل الحضور',
                        subtitle: 'متابعة حضور الحصص',
                        icon: Icons.fact_check_rounded,
                        color: AppColors.green,
                        onTap: () => context.push('/attendance'),
                      ),
                      _buildFeatureCard(
                        context: context,
                        title: 'الواجبات',
                        subtitle: 'متابعة تسليم المهام',
                        icon: Icons.assignment_turned_in_rounded,
                        color: AppColors.secondary,
                        onTap: () => context.push('/homework'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
