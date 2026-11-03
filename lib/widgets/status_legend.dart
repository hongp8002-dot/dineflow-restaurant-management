import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Một mục chú thích: chấm màu + nhãn.
class StatusLegendItem {
  final Color color;
  final String label;

  /// Viền cho mẫu màu quá nhạt so với nền (vd ô "Trống" màu trắng).
  final Color? borderColor;

  const StatusLegendItem(this.color, this.label, {this.borderColor});
}

/// Hàng chú thích màu trạng thái (bàn trống / đang phục vụ / đã đặt trước...).
///
/// Dùng `Wrap` nên trên máy hẹp các mục tự xuống dòng thay vì tràn ra ngoài -
/// đây chính là lỗi từng gặp ở màn Sơ đồ bàn.
class StatusLegend extends StatelessWidget {
  final List<StatusLegendItem> items;

  /// Mẫu màu hình vuông bo góc (mockup Nhân viên Order) thay cho chấm tròn.
  final bool square;

  const StatusLegend({super.key, required this.items, this.square = false});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: items
          .map((item) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: square ? 12 : 9,
                    height: square ? 12 : 9,
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: square ? BoxShape.rectangle : BoxShape.circle,
                      borderRadius: square ? BorderRadius.circular(3) : null,
                      border:
                          item.borderColor == null ? null : Border.all(color: item.borderColor!, width: 1),
                    ),
                  ),
                  SizedBox(width: square ? 7 : 6),
                  Text(
                    item.label,
                    style: square
                        ? TextStyle(fontSize: 13, color: AppColors.textPrimary)
                        : TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ))
          .toList(),
    );
  }
}
