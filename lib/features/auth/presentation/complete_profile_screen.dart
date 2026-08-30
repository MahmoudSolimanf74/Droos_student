import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import 'auth_cubit.dart';
import 'auth_state.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthCubit>().state;
    if (authState is ProfileIncomplete) {
      _nameController.text = authState.profile.fullName;
      _phoneController.text = authState.profile.phone;
      _parentPhoneController.text = authState.profile.parentPhone;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _parentPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is Authenticated) {
          if (!state.profile.isEnrolledInGroup) {
            context.go('/join-group');
          } else {
            context.go('/dashboard');
          }
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppColors.red),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return Scaffold(
          appBar: AppBar(
            title: const Text(AppStrings.completeProfileTitle),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: AppColors.red),
                tooltip: 'العودة لتسجيل الدخول',
                onPressed: () => context.read<AuthCubit>().signOut(),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  AppStrings.completeProfileSubtitle,
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        CustomTextField(
                          controller: _nameController,
                          label: AppStrings.fullName,
                          hintText: 'مثال: أحمد محمد علي',
                          prefixIcon: Icons.person_outline_rounded,
                          validator: (v) => (v == null || v.trim().length < 3) ? 'يرجى كتابة الاسم ثلاثي' : null,
                        ),
                        const SizedBox(height: 16),

                        CustomTextField(
                          controller: _phoneController,
                          label: AppStrings.studentPhone,
                          hintText: '01xxxxxxxxx',
                          prefixIcon: Icons.phone_android_rounded,
                          keyboardType: TextInputType.phone,
                          validator: (v) => (v == null || v.trim().length < 10) ? 'يرجى إدخال رقم هاتف صحيح' : null,
                        ),
                        const SizedBox(height: 16),

                        CustomTextField(
                          controller: _parentPhoneController,
                          label: AppStrings.parentPhone,
                          hintText: '01xxxxxxxxx',
                          prefixIcon: Icons.family_restroom_rounded,
                          keyboardType: TextInputType.phone,
                          validator: (v) => (v == null || v.trim().length < 10) ? 'يرجى إدخال رقم هاتف ولي الأمر' : null,
                        ),
                        const SizedBox(height: 32),

                        CustomButton(
                          text: AppStrings.saveAndContinue,
                          icon: Icons.check_circle_outline_rounded,
                          isLoading: isLoading,
                          onPressed: () {
                            if (_formKey.currentState?.validate() ?? false) {
                              context.read<AuthCubit>().completeProfile(
                                    fullName: _nameController.text.trim(),
                                    phone: _phoneController.text.trim(),
                                    parentPhone: _parentPhoneController.text.trim(),
                                  );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
