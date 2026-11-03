import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_animations.dart';

/// Cỡ của bộ tăng/giảm số lượng.
enum QuantityStepperSize {
  /// Dùng trong dòng danh sách chật (giỏ hàng, order đang tạo).
  small,

  /// Dùng trong khối riêng (chi tiết món, chọn số khách).
  large,
}

/// Bộ nút tăng/giảm số lượng dùng chung.
///
/// Gom 4 biến thể từng được viết riêng ở màn giỏ hàng, chi tiết món, đặt bàn
/// và tạo order, để kiểu dáng và vùng chạm thống nhất toàn app.
class QuantityStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  /// Giá trị nhỏ nhất; giảm xuống dưới mức này thì nút trừ bị vô hiệu hoá.
  /// Đặt 0 nếu muốn cho phép giảm về 0 để xoá món.
  final int min;
  final int max;

  final QuantityStepperSize size;

  /// Hiện số ở giữa hai nút. Tắt khi số đã được hiển thị ở chỗ khác.
  final bool showValue;

  /// Màu nền nút ở cỡ lớn. Mockup dùng vàng nhạt trong màn "Đơn của bạn"
  /// và trắng khi bộ đếm nằm trên khối nền kem (màn Đặt bàn).
  final Color? buttonColor;

  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 99,
    this.size = QuantityStepperSize.small,
    this.showValue = true,
    this.buttonColor,
  });

  bool get _isLarge => size == QuantityStepperSize.large;

  @override
  Widget build(BuildContext context) {
    final canDecrease = value > min;
    final canIncrease = value < max;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: Icons.remove_rounded,
          large: _isLarge,
          enabled: canDecrease,
          color: buttonColor,
          onTap: () => onChanged(value - 1),
        ),
        if (showValue)
          SizedBox(
            width: _isLarge ? 44 : 34,
            child: Center(
              child: AnimatedValueText(
                '$value',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: _isLarge ? 18 : 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          )
        else
          SizedBox(width: _isLarge ? 10 : 6),
        _StepButton(
          icon: Icons.add_rounded,
          large: _isLarge,
          enabled: canIncrease,
          color: buttonColor,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final bool large;
  final bool enabled;
  final Color? color;
  final VoidCallback onTap;

  const _StepButton({
    required this.icon,
    required this.large,
    required this.enabled,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Cỡ lớn theo mockup: ô vuông bo góc 44px; cỡ nhỏ giữ nguyên cho danh sách chật.
    final box = large ? 44.0 : 26.0;
    return PressScale(
      onTap: enabled ? onTap : null,
      scale: 0.85,
      // Vùng chạm luôn tối thiểu 36px dù nút vẽ nhỏ hơn, cho dễ bấm.
      child: SizedBox(
        width: large ? box : 36,
        height: large ? box : 36,
        child: Center(
          child: AnimatedContainer(
            duration: AppMotion.fast,
            width: box,
            height: box,
            decoration: large
                ? BoxDecoration(
                    color: color ?? AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  )
                : BoxDecoration(
                    color: enabled ? AppColors.primaryLight : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: enabled ? AppColors.primarySoft : AppColors.border),
                  ),
            child: Icon(
              icon,
              size: large ? 22 : 15,
              color: enabled
                  ? AppColors.textPrimary
                  : AppColors.textSecondary.withValues(alpha: large ? 0.45 : 1),
            ),
          ),
        ),
      ),
    );
  }
}
