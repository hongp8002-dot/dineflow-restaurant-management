import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/api/api_exception.dart';
import '../../data/app_data.dart';
import '../../data/auth_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

/// Màn hình đăng nhập.
///
/// Đăng nhập thật qua API (số điện thoại hoặc email + mật khẩu); vai trò do server
/// trả về quyết định mở màn hình nào.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _enter(String route) {
    Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
  }

  Future<void> _signIn(String identifier, String password) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final user = await AuthRepository.instance.login(identifier, password);
      final loadError = await AppData.load();
      if (!mounted) return;
      if (loadError != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loadError)));
      }
      _enter(AppRoutes.homeFor(user.role));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleLogin() {
    if (!_formKey.currentState!.validate()) return;
    _signIn(_phoneController.text, _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Hero(),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FadeSlideIn(
                        child: AppTextField(
                          controller: _phoneController,
                          label: 'Số điện thoại',
                          hint: '09xx xxx xxx',
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                            if (digits.isEmpty) return 'Vui lòng nhập số điện thoại';
                            if (digits.length < 9) return 'Số điện thoại chưa đúng';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 60),
                        child: AppTextField(
                          controller: _passwordController,
                          label: 'Mật khẩu',
                          hint: 'Nhập mật khẩu',
                          obscureText: true,
                          validator: (value) =>
                              (value == null || value.length < 4) ? 'Mật khẩu tối thiểu 4 ký tự' : null,
                        ),
                      ),

                      // Quên mật khẩu – căn phải dưới ô mật khẩu
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 80),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.forgotPassword),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Quên mật khẩu?',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 120),
                        child: AppButton(
                          label: 'Đăng nhập',
                          onPressed: _handleLogin,
                          isLoading: _loading,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Link đăng ký – căn giữa
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 160),
                        child: Center(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.register),
                            child: Text.rich(
                              TextSpan(
                                text: 'Chưa có tài khoản? ',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary),
                                children: [
                                  TextSpan(
                                    text: 'Đăng ký ngay',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                      decoration: TextDecoration.underline,
                                      decorationColor: AppColors.primaryDark,
                                      decorationThickness: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Phần đầu nền vàng nhạt: hình tròn vàng + vòng tròn viền nâu trang trí ở góc
/// trên phải, chữ "Dine" nâu đen + "Flow" vàng nâu, câu giới thiệu bên dưới.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      height: 300 + topInset,
      color: AppColors.primaryLight,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Hình tròn vàng lớn tràn ra khỏi góc trên phải.
          Positioned(
            top: -80,
            right: -70,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: AppMotion.slow,
              curve: AppMotion.emphasized,
              builder: (context, value, child) => Transform.scale(scale: value, child: child),
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              ),
            ),
          ),
          // Vòng tròn viền mảnh lệch sang phải, chồng lên hình tròn vàng.
          Positioned(
            top: -22,
            right: -14,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.ink, width: 1.6),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 28,
            child: FadeSlideIn(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: 'Dine',
                      style: TextStyle(color: AppColors.textPrimary),
                      children: [TextSpan(text: 'Flow', style: TextStyle(color: AppColors.accent))],
                    ),
                    style: const TextStyle(
                        fontSize: 46, fontWeight: FontWeight.w800, letterSpacing: -1.5, height: 1),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Quản lý nhà hàng & cafe trong một ứng dụng',
                    style: TextStyle(fontSize: 14.5, color: AppColors.textPrimary.withValues(alpha: 0.75)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
