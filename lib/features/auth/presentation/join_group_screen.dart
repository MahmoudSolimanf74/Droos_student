import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import 'auth_cubit.dart';
import 'auth_state.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final _codeController = TextEditingController();
  bool _isJoining = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String _extractJoinCode(String raw) {
    var clean = raw.trim();
    if (clean.contains('code=') || clean.contains('token=')) {
      final uri = Uri.tryParse(clean);
      if (uri != null) {
        if (uri.queryParameters.containsKey('code')) {
          return uri.queryParameters['code']!.trim();
        }
        if (uri.queryParameters.containsKey('token')) {
          return uri.queryParameters['token']!.trim();
        }
      }
      final matchCode = RegExp(r'code=([a-zA-Z0-9_\u0600-\u06FF-]+)').firstMatch(clean);
      if (matchCode != null) return matchCode.group(1)!;
      final matchToken = RegExp(r'token=([a-zA-Z0-9_\u0600-\u06FF-]+)').firstMatch(clean);
      if (matchToken != null) return matchToken.group(1)!;
    }
    return clean;
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null && data.text!.trim().isNotEmpty) {
        final extracted = _extractJoinCode(data.text!);
        setState(() {
          _codeController.text = extracted;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('تم لصق الكود بنجاح! 📋'),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('الحافظة فارغة'),
              backgroundColor: AppColors.surface,
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _submitCode(String code) async {
    if (_isSubmitting || _isJoining) return;
    final cleanCode = _extractJoinCode(code);
    if (cleanCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(child: Text('يرجى إدخال كود المجموعة أولاً')),
            ],
          ),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    _isSubmitting = true;
    setState(() => _isJoining = true);

    try {
      final res = await context.read<AuthCubit>().joinGroup(cleanCode);
      if (!mounted) return;

      setState(() => _isJoining = false);
      if (res['success'] == true) {
        final message = res['message'] as String? ?? 'تم الانضمام للمجموعة بنجاح! 🎉';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        // Direct navigation to Dashboard!
        context.go('/dashboard');
      } else {
        _isSubmitting = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(res['message'] as String? ?? 'كود المجموعة غير صحيح')),
              ],
            ),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        _isSubmitting = false;
        setState(() => _isJoining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final profile = state is Authenticated ? state.profile : null;

        return Scaffold(
          appBar: AppBar(
            title: const Text(AppStrings.joinGroupTitle),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  context.go('/dashboard');
                }
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: AppColors.red),
                tooltip: 'تسجيل الخروج',
                onPressed: () => context.read<AuthCubit>().signOut(),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Illustration / Icon Badge
                      Center(
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            size: 42,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Welcome header
                      if (profile != null) ...[
                        Text(
                          'أهلاً بك يا ${profile.fullName} 👋',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.displayMedium.copyWith(fontSize: 22),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        AppStrings.joinGroupSubtitle,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 36),

                      // Manual Code Input
                      CustomTextField(
                        controller: _codeController,
                        label: AppStrings.groupCode,
                        hintText: 'مثال: A7B29F',
                        prefixIcon: Icons.vpn_key_outlined,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.paste_rounded, color: AppColors.primary, size: 20),
                          tooltip: 'لصق من الحافظة',
                          onPressed: _pasteFromClipboard,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Paste shortcut hint
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _pasteFromClipboard,
                          icon: const Icon(Icons.content_paste_go_rounded, size: 16),
                          label: const Text('لصق الكود المنسوخ', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      CustomButton(
                        text: AppStrings.joinButton,
                        icon: Icons.login_rounded,
                        isLoading: _isJoining,
                        onPressed: () => _submitCode(_codeController.text),
                      ),
                      const SizedBox(height: 32),

                      // Information Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'كيف أحصل على الكود؟',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'يقوم المعلم بمشاركة كود المجموعة الخاص بك (المكون من 6 رموز). اطلب الكود من معلمك للانضمام فوراً.',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

