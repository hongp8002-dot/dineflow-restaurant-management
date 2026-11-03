import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'app_animations.dart';

/// Ô thống kê dùng cho các Dashboard (Admin, Cashier).
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  /// null = [AppColors.primary] (màu đọc theo bảng màu đang dùng nên không đặt mặc định được).
  final Color? color;
  final String? trend;
  final bool trendUp;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.trend,
    this.trendUp = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Khối nền kem phẳng, giống khối tổng tiền trong mockup.
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration:
                BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 12),
          // Giá trị tự thu nhỏ thay vì tràn ngang khi số dài (vd: tiền tỉ).
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedValueText(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.25),
          ),
          if (trend != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(trendUp ? Icons.trending_up : Icons.trending_down,
                    size: 14, color: trendUp ? AppColors.success : AppColors.error),
                const SizedBox(width: 4),
                // Flexible + ellipsis: câu xu hướng dài không đẩy tràn ô thống kê.
                Flexible(
                  child: Text(
                    trend!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: trendUp ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
