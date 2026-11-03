import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Đường kẻ đứt kiểu hoá đơn giấy, dùng ở màn Hoá đơn và khối tổng tiền
/// của màn Thanh toán.
class DashedDivider extends StatelessWidget {
  /// null = [AppColors.primarySoft] (màu đọc theo bảng màu đang dùng nên không đặt mặc định được).
  final Color? color;

  const DashedDivider({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dashCount = (constraints.maxWidth / 8).floor();
        return Row(
          children: List.generate(
            dashCount,
            (_) => Expanded(
              child: Container(
                  height: 1,
                  color: color ?? AppColors.primarySoft,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5)),
            ),
          ),
        );
      },
    );
  }
}
