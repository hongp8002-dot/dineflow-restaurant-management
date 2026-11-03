import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/auth_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_page_header.dart';

/// Màn hình Đổi mật khẩu cho Nhân viên Order.
class StaffSettingsScreen extends StatefulWidget {
  const StaffSettingsScreen({super.key});

  @override
  State<StaffSettingsScreen> createState() => _StaffSettingsScreenState();
}

class _StaffSettingsScreenState extends State<StaffSettingsScreen> {
  // ─── Đổi mật khẩu ───────────────────────────────────────────────────────────
  final _pwFormKey = GlobalKey<FormState>();
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _currentPwVisible = false;
  bool _newPwVisible = false;
  bool _confirmPwVisible = false;
  bool _pwChanged = false;
  bool _saving = false;
  // Lỗi server trả về cho ô mật khẩu hiện tại (vd: nhập sai), hiện ngay dưới ô.
  String? _currentPwServerError;

  @override
  void dispose() {
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  /// Gửi yêu cầu đổi mật khẩu lên server. Chỉ báo thành công khi server xác nhận.
  Future<void> _submitPasswordChange() async {
    if (_saving) return;
    _currentPwServerError = null;
    if (!_pwFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await AuthRepository.instance.changePassword(
        currentPassword: _currentPwCtrl.text,
        newPassword: _newPwCtrl.text,
      );
      if (!mounted) return;
      setState(() => _pwChanged = true);
    } on ApiException catch (e) {
      if (!mounted) return;
      final currentPwError = e.errors['current_password'];
      if (currentPwError != null && currentPwError.isNotEmpty) {
        _currentPwServerError = currentPwError.first;
        _pwFormKey.currentState!.validate(); // hiện lỗi dưới ô mật khẩu hiện tại
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetPasswordForm() {
    setState(() {
      _pwChanged = false;
      _currentPwServerError = null;
      _currentPwCtrl.clear();
      _newPwCtrl.clear();
      _confirmPwCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    var idx = 0;
    Widget step(Widget child) => FadeSlideIn.staggered(index: idx++, child: child);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            step(const AppPageHeader(title: 'Đổi mật khẩu')),
            const SizedBox(height: 22),
            step(_pwChanged ? _buildPasswordSuccess() : _buildPasswordForm()),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordForm() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Form(
        key: _pwFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PasswordField(
              controller: _currentPwCtrl,
              label: 'Mật khẩu hiện tại',
              visible: _currentPwVisible,
              onToggle: () => setState(() => _currentPwVisible = !_currentPwVisible),
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Vui lòng nhập mật khẩu hiện tại'
                  : _currentPwServerError,
            ),
            const SizedBox(height: 12),
            _PasswordField(
              controller: _newPwCtrl,
              label: 'Mật khẩu mới',
              visible: _newPwVisible,
              onToggle: () => setState(() => _newPwVisible = !_newPwVisible),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu mới';
                if (v.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự';
                if (v == _currentPwCtrl.text)
                  return 'Mật khẩu mới phải khác mật khẩu hiện tại';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _PasswordField(
              controller: _confirmPwCtrl,
              label: 'Xác nhận mật khẩu mới',
              visible: _confirmPwVisible,
              onToggle: () => setState(() => _confirmPwVisible = !_confirmPwVisible),
              textInputAction: TextInputAction.done,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Vui lòng xác nhận mật khẩu';
                if (v != _newPwCtrl.text) return 'Mật khẩu xác nhận không khớp';
                return null;
              },
            ),
            const SizedBox(height: 18),
            PressScale(
              onTap: _saving ? null : _submitPasswordChange,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: _saving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: AppColors.primaryOnInk),
                        )
                      : Text(
                    'Cập nhật mật khẩu',
                    style: TextStyle(
                      color: AppColors.primaryOnInk,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordSuccess() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_open_rounded, color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 14),
          Text(
            'Đổi mật khẩu thành công!',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Mật khẩu của bạn đã được cập nhật.',
            style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          PressScale(
            onTap: _resetPasswordForm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                'Đổi lại',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Password input field ──────────────────────────────────────────────────────

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool visible;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.visible,
    required this.onToggle,
    this.validator,
    this.textInputAction = TextInputAction.next,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: !visible,
      textInputAction: textInputAction,
      validator: validator,
      style: TextStyle(fontSize: 14.5, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        suffixIcon: IconButton(
          icon: Icon(
            visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: AppColors.textSecondary,
            size: 20,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
