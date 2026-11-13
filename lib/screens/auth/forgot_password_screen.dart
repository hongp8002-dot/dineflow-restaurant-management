import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/auth_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

/// Quên mật khẩu bằng mã OTP gửi qua email — chỉ dành cho tài khoản khách hàng.
///
/// 3 bước trong cùng một màn:
///   1. Nhập email → server gửi mã 6 số (hiệu lực 10 phút).
///   2. Nhập mã → server kiểm tra (sai tối đa 5 lần). Được gửi lại mã sau 60 giây.
///   3. Nhập mật khẩu mới → đổi xong quay về màn Đăng nhập.
/// Mọi quy tắc (hạn mã, số lần sai, thời gian chờ) do server kiểm tra; app chỉ hiển thị.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _Step { email, code, password }

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  _Step _step = _Step.email;
  bool _loading = false;

  /// Đếm ngược tới lúc được gửi lại mã.
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ── Hành động ──────────────────────────────────────────────────────────────

  /// Gửi (hoặc gửi lại) mã tới email.
  Future<void> _sendCode() async {
    if (_step == _Step.email && !_formKey.currentState!.validate()) return;
    await _run(() async {
      final result = await AuthRepository.instance.requestPasswordReset(_emailController.text);
      _startCountdown(result.resendIn);
      setState(() {
        _step = _Step.code;
        _codeController.clear();
      });
      _snack(result.message);
    });
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;
    await _run(() async {
      await AuthRepository.instance.verifyPasswordResetCode(_emailController.text, _codeController.text);
      setState(() => _step = _Step.password);
    });
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    await _run(() async {
      final message = await AuthRepository.instance.resetPassword(
        email: _emailController.text,
        code: _codeController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      _snack(message);
      Navigator.of(context).pop(); // quay về màn Đăng nhập
    });
  }

  /// Chạy một lời gọi API: hiện loading, báo lỗi của server bằng SnackBar.
  Future<void> _run(Future<void> Function() action) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await action();
    } on ApiException catch (e) {
      // Vừa xin mã cho email này (vd bấm 2 lần): mã trước vẫn dùng được → sang bước nhập mã, đếm ngược
      final retryAfter = int.tryParse(e.errors['retry_after']?.first ?? '');
      if (retryAfter != null && _step == _Step.email) {
        _startCountdown(retryAfter);
        setState(() => _step = _Step.code);
        _snack('Mã xác nhận đã được gửi trước đó. Vui lòng kiểm tra email (cả mục Spam).');
        return;
      }
      _snack(e.message, isError: true);
      // Mã đã bị hủy (sai quá số lần / hết hạn) → quay lại bước nhập mã để xin mã mới
      if (_step == _Step.password && e.isValidation && e.errors.containsKey('code')) {
        setState(() => _step = _Step.code);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _resendIn = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendIn--);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? AppColors.error : null));
  }

  // ── Giao diện ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Quên mật khẩu', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.surface,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StepIndicator(current: _step.index),
                const SizedBox(height: 24),
                FadeSlideIn(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    _Step.email => _buildEmailStep(),
                    _Step.code => _buildCodeStep(),
                    _Step.password => _buildPasswordStep(),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Hint(
          'Nhập email đã dùng khi đăng ký. Chúng tôi sẽ gửi mã xác nhận 6 số để bạn đặt lại mật khẩu.\n'
          'Chức năng này dành cho tài khoản khách hàng. Nhân viên quên mật khẩu vui lòng liên hệ quản lý.',
        ),
        const SizedBox(height: 20),
        AppTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'ban@example.com',
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            final email = (value ?? '').trim();
            if (email.isEmpty) return 'Vui lòng nhập email';
            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return 'Email không đúng định dạng';
            return null;
          },
        ),
        const SizedBox(height: 24),
        AppButton(label: 'Gửi mã xác nhận', onPressed: _sendCode, isLoading: _loading),
      ],
    );
  }

  Widget _buildCodeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Hint(
          'Nếu ${_emailController.text.trim()} là email của tài khoản khách hàng, mã xác nhận đã được gửi tới đó. '
          'Mã có hiệu lực 10 phút. Không thấy email thì xem thêm trong mục Spam.',
        ),
        const SizedBox(height: 20),
        AppTextField(
          controller: _codeController,
          label: 'Mã xác nhận',
          hint: '6 chữ số',
          keyboardType: TextInputType.number,
          validator: (value) =>
              RegExp(r'^\d{6}$').hasMatch((value ?? '').trim()) ? null : 'Mã xác nhận gồm 6 chữ số',
        ),
        const SizedBox(height: 24),
        AppButton(label: 'Xác nhận', onPressed: _verifyCode, isLoading: _loading),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _loading ? null : () => setState(() => _step = _Step.email),
              child: const Text('Đổi email'),
            ),
            TextButton(
              onPressed: _loading || _resendIn > 0 ? null : _sendCode,
              child: Text(_resendIn > 0 ? 'Gửi lại mã sau ${_resendIn}s' : 'Gửi lại mã'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Hint('Đặt mật khẩu mới cho tài khoản. Sau khi đổi, các thiết bị khác đang đăng nhập sẽ bị đăng xuất.'),
        const SizedBox(height: 20),
        AppTextField(
          controller: _passwordController,
          label: 'Mật khẩu mới',
          hint: 'Ít nhất 6 ký tự',
          obscureText: true,
          validator: (value) => (value == null || value.length < 6) ? 'Mật khẩu mới phải có ít nhất 6 ký tự' : null,
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _confirmController,
          label: 'Nhập lại mật khẩu mới',
          obscureText: true,
          validator: (value) => value != _passwordController.text ? 'Mật khẩu xác nhận không khớp' : null,
        ),
        const SizedBox(height: 24),
        AppButton(label: 'Đặt lại mật khẩu', onPressed: _resetPassword, isLoading: _loading),
      ],
    );
  }
}

/// Thanh 3 bước: Email → Mã xác nhận → Mật khẩu mới.
class _StepIndicator extends StatelessWidget {
  final int current;

  const _StepIndicator({required this.current});

  static const _labels = ['Email', 'Mã xác nhận', 'Mật khẩu mới'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < _labels.length - 1 ? 8 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= current ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _labels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: i == current ? FontWeight.w800 : FontWeight.w500,
                      color: i <= current ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;

  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.textSecondary));
  }
}
