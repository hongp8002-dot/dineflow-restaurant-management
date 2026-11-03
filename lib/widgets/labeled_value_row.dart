import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_animations.dart';

/// Dòng "nhãn bên trái - giá trị bên phải" dùng chung cho mọi bảng thông tin:
/// xác nhận đặt bàn, chi tiết đơn, hoá đơn, tổng tiền giỏ hàng...
///
/// Trước đây mỗi màn hình tự viết một biến thể riêng (`_InfoRow`, `_Row`,
/// `_SummaryRow`, `_reviewRow`...) nên sửa kiểu chữ hay màu phải sửa nhiều chỗ.
class LabeledValueRow extends StatelessWidget {
  final String label;
  final String value;

  /// Icon nhỏ đứng trước nhãn (tuỳ chọn).
  final IconData? icon;

  /// Đặt icon trong ô bo góc nền vàng nhạt thay vì icon trần.
  final bool iconInTile;

  /// Dòng tổng kết: chữ to và đậm hơn các dòng thường.
  final bool emphasize;

  /// Màu riêng cho phần giá trị (vd: xanh khi đã thanh toán).
  final Color? valueColor;

  /// Giá trị đổi số có hiệu ứng trượt (dùng cho tiền, số lượng thay đổi liên tục).
  final bool animateValue;

  final EdgeInsetsGeometry padding;

  const LabeledValueRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.iconInTile = false,
    this.emphasize = false,
    this.valueColor,
    this.animateValue = false,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: emphasize ? 15 : 13,
      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
      color: emphasize ? AppColors.textPrimary : AppColors.textSecondary,
    );
    final valueStyle = TextStyle(
      fontSize: emphasize ? 17 : 13.5,
      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
      color: valueColor ?? AppColors.textPrimary,
    );

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            if (iconInTile)
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: AppColors.textPrimary),
              )
            else
              Icon(icon, size: 18, color: AppColors.textPrimary),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(label, style: labelStyle)),
          const SizedBox(width: 10),
          Flexible(
            child: animateValue
                // Align: AnimatedSwitcher co lại theo nội dung nên cần đẩy sang phải.
                ? Align(
                    alignment: Alignment.centerRight,
                    child: AnimatedValueText(value, style: valueStyle, textAlign: TextAlign.right),
                  )
                : Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: valueStyle,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
