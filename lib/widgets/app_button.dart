import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_animations.dart';

enum AppButtonVariant {
  /// Nút chính: nền vàng, chữ đen.
  primary,

  /// Nút viền đen, nền trong suốt.
  outlined,

  /// Nút chữ.
  text,

  /// Nút nhấn mạnh: nền đen, chữ trắng.
  dark,

  /// Nút nền trắng không viền, dùng trên nền kem (vd Chuyển bàn, Gộp bàn).
  light,
}

/// Nút bấm dùng chung, hỗ trợ trạng thái loading và phản hồi khi chạm.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  /// Cỡ gọn cho nút đứng 2 chiếc một hàng: chữ nhỏ hơn, lề trong hẹp hơn,
  /// nhãn dài thì tự thu nhỏ thay vì bị cắt "...".
  final bool dense;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
    this.dense = false,
  });

  static const _denseStyle = ButtonStyle(
    padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
    textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
  );

  Color get _spinnerColor => switch (variant) {
        AppButtonVariant.dark => AppColors.textOnDark,
        _ => AppColors.textOnPrimary,
      };

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: _spinnerColor),
          )
        : dense
            ? FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                    Text(label),
                  ],
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                  Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
                ],
              );

    final onTap = isLoading ? null : onPressed;
    final extra = dense ? _denseStyle : null;

    Widget button;
    switch (variant) {
      case AppButtonVariant.primary:
        button = ElevatedButton(onPressed: onTap, style: extra, child: child);
        break;
      case AppButtonVariant.dark:
        button = ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.ink,
            foregroundColor: AppColors.textOnDark,
          ).merge(extra),
          child: child,
        );
        break;
      case AppButtonVariant.light:
        button = ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
          ).merge(extra),
          child: child,
        );
        break;
      case AppButtonVariant.outlined:
        button = OutlinedButton(onPressed: onTap, style: extra, child: child);
        break;
      case AppButtonVariant.text:
        button = TextButton(onPressed: onTap, style: extra, child: child);
        break;
    }

    final sized = fullWidth ? SizedBox(width: double.infinity, child: button) : button;

    // Thu nhỏ nhẹ khi nhấn để nút có phản hồi "mobile".
    return _PressFeedback(enabled: onTap != null, child: sized);
  }
}

/// Bọc nút để thu nhỏ khi ngón tay chạm xuống. Dùng [Listener] thay cho
/// GestureDetector để không tranh chấp sự kiện chạm với chính nút bên trong.
class _PressFeedback extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const _PressFeedback({required this.child, required this.enabled});

  @override
  State<_PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<_PressFeedback> {
  bool _pressed = false;

  void _set(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: AppMotion.fast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
