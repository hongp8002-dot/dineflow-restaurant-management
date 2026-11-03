import 'package:flutter/material.dart';

/// Nhãn trạng thái dạng pill bo tròn, tái sử dụng cho mọi loại trạng thái
/// (bàn, đơn hàng, khuyến mãi, tài khoản...).
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  /// Viền cho nhãn nền trắng/trong (vd "Chưa thanh toán" ở mockup Thu ngân).
  final Color? borderColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.background,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}
