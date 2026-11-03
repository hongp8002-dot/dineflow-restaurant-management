import 'package:flutter/material.dart';

import '../models/revenue.dart';
import '../theme/app_colors.dart';

/// Biểu đồ cột đơn giản vẽ bằng CustomPainter, dùng dữ liệu mock để
/// minh họa doanh thu (không dùng thư viện chart ngoài).
class MockBarChart extends StatelessWidget {
  final List<RevenuePoint> data;
  final double height;

  const MockBarChart({super.key, required this.data, this.height = 160});

  @override
  Widget build(BuildContext context) {
    final maxValue = data.map((e) => e.amount).fold<double>(0, (a, b) => a > b ? a : b);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((point) {
          final ratio = maxValue == 0 ? 0.0 : point.amount / maxValue;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${(point.amount / 1000000).toStringAsFixed(1)}tr',
                    style: TextStyle(fontSize: 9.5, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: ratio.clamp(0.03, 1.0),
                        widthFactor: 1,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [AppColors.primary, AppColors.primaryDark],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(point.label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
