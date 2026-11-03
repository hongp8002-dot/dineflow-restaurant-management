import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'app_animations.dart';

/// Chip danh mục món, dùng trong danh sách ngang có thể chọn.
/// Theo mockup Trang chủ: viên thuốc viền mảnh; đang chọn = nền nâu đen, chữ trắng.
class CategoryChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.textOnDark : AppColors.textPrimary;
    return PressScale(
      onTap: onTap,
      scale: 0.94,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: Curves.easeOut,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? AppColors.ink : AppColors.border, width: 1.4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(color: foreground, fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
