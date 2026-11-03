import 'package:flutter/material.dart';

import '../models/table_model.dart';
import '../theme/app_colors.dart';
import '../theme/status_visuals.dart';
import 'app_animations.dart';

/// Card hiển thị một bàn trong sơ đồ bàn.
class TableCard extends StatelessWidget {
  final TableModel table;
  final VoidCallback? onTap;
  final bool selected;

  const TableCard({super.key, required this.table, this.onTap, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final visual = tableStatusVisual(table.status);
    return PressScale(
      onTap: onTap,
      scale: 0.94,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : visual.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primaryDark : visual.color.withValues(alpha: 0.35),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? AppColors.goldShadow : null,
        ),
        // FittedBox: card được dùng trong nhiều lưới có tỉ lệ ô khác nhau
        // (sơ đồ bàn, chọn bàn, chuyển bàn, gộp bàn). Cho nội dung tự thu nhỏ
        // để không bao giờ tràn khi ô thấp hơn dự kiến.
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.table_bar_rounded, color: visual.color, size: 22),
                const SizedBox(height: 6),
                Text(table.number,
                    maxLines: 1,
                    softWrap: false,
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('${table.capacity} khách',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(
                  table.status.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: visual.color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
