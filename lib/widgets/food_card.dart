import 'package:flutter/material.dart';

import '../models/food.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import 'app_animations.dart';
import 'food_image.dart';

/// Card hiển thị món ăn trong lưới (Trang chủ, Thực đơn...).
///
/// Theo mockup: không có khung viền bao ngoài — chỉ gồm ô ảnh sọc chéo bo góc,
/// tên món, giá in đậm và nút "+" tròn màu vàng nhạt để thêm nhanh.
class FoodCard extends StatelessWidget {
  final Food food;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  /// Tag dùng cho hiệu ứng Hero khi mở màn chi tiết món.
  final String? heroTag;

  const FoodCard({
    super.key,
    required this.food,
    required this.onTap,
    this.onAdd,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final image = FoodImage(food: food);

    return AnimatedOpacity(
      duration: AppMotion.normal,
      opacity: food.isAvailable ? 1 : 0.55,
      child: PressScale(
        onTap: food.isAvailable ? onTap : null,
        scale: 0.97,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Expanded: ảnh tự co theo chiều cao ô lưới, tránh tràn theo chiều dọc.
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: heroTag == null ? image : Hero(tag: heroTag!, child: image),
                  ),
                  if (food.isBestSeller)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _Tag(
                        label: 'Bán chạy',
                        background: AppColors.primary,
                        foreground: AppColors.textOnPrimary,
                        icon: Icons.local_fire_department_rounded,
                      ),
                    ),
                  if (!food.isAvailable)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _Tag(
                        label: 'Hết món',
                        background: AppColors.ink,
                        foreground: AppColors.textOnDark,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              food.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      AppFormatters.currency(food.price),
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.textPrimary),
                    ),
                  ),
                ),
                if (onAdd != null)
                  PressScale(
                    scale: 0.85,
                    onTap: food.isAvailable ? onAdd : null,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: food.isAvailable ? AppColors.primaryLight : AppColors.surfaceAlt,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: 22,
                        color: food.isAvailable ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  const _Tag({required this.label, required this.background, required this.foreground, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: foreground),
            const SizedBox(width: 3),
          ],
          Text(label, style: TextStyle(color: foreground, fontSize: 10, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
