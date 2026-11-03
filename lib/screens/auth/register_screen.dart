import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/api/api_exception.dart';
import '../../data/app_data.dart';
import '../../data/auth_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

/// Màn hình đăng ký tài khoản Khách hàng qua API; đăng ký xong được đăng nhập luôn.
/// Bố cục đồng bộ với màn Đăng nhập theo mockup: phần đầu nền vàng nhạt có chữ
/// DineFlow hai màu, các ô nhập không icon, nút vàng bo góc.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _loading = false;

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate() || _loading) return;

    setState(() => _loading = true);
    try {
      final user = await AuthRepository.instance.register(
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        password: _passwordController.text,
      );
      final loadError = await AppData.load();
      if (!mounted) return;
      if (loadError != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loadError)));
      }
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.homeFor(user.role), (route) => false);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    // Các ô nhập hiện lần lượt.
    var order = 0;
    Widget step(Widget child) => FadeSlideIn.staggered(index: order++, child: child);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: AppColors.primaryLight,
              padding: EdgeInsets.fromLTRB(24, topInset + 16, 24, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PressScale(
                    onTap: () => Navigator.of(context).maybePop(),
                    scale: 0.88,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                      child: Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Tạo tài khoản',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      text: 'Đặt bàn và gọi món nhanh hơn với ',
                      style: TextStyle(color: AppColors.textSecondary),
                      children: [
                        TextSpan(
                          text: 'Dine',
                          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        TextSpan(
                          text: 'Flow',
                          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.accent),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 14.5),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      step(AppTextField(
                        controller: _nameController,
                        label: 'Họ và tên',
                        hint: 'Nhập họ và tên',
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập họ tên' : null,
                      )),
                      const SizedBox(height: 16),
                      step(AppTextField(
                        controller: _phoneController,
                        label: 'Số điện thoại',
                        hint: '09xx xxx xxx',
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Vui lòng nhập số điện thoại' : null,
                      )),
                      const SizedBox(height: 16),
                      step(AppTextField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'ten@email.com',
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
                          if (!v.contains('@')) return 'Email không hợp lệ';
                          return null;
                        },
                      )),
                      const SizedBox(height: 16),
                      step(AppTextField(
                        controller: _passwordController,
                        label: 'Mật khẩu',
                        hint: 'Tối thiểu 4 ký tự',
                        obscureText: true,
                        validator: (v) => (v == null || v.length < 4) ? 'Mật khẩu tối thiểu 4 ký tự' : null,
                      )),
                      const SizedBox(height: 16),
                      step(AppTextField(
                        controller: _confirmPasswordController,
                        label: 'Xác nhận mật khẩu',
                        hint: 'Nhập lại mật khẩu',
                        obscureText: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Vui lòng xác nhận mật khẩu';
                          if (v != _passwordController.text) return 'Mật khẩu xác nhận không khớp';
                          return null;
                        },
                      )),
                      const SizedBox(height: 24),
                      step(AppButton(label: 'Đăng ký', onPressed: _handleRegister, isLoading: _loading)),
                      const SizedBox(height: 10),
                      Center(
                        // Chỉ chữ "Đăng nhập" in đậm, gạch chân để thấy rõ phần bấm được.
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          child: Text.rich(
                            TextSpan(
                              text: 'Đã có tài khoản? ',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Đăng nhập',
                                  style: TextStyle(
                                    fontSize: 13,
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
