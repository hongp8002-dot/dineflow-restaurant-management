import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'app_animations.dart';

/// Tiêu đề section kèm hành động phụ (vd: "Xem tất cả").
/// Theo mockup: tiêu đề in đậm, hành động là chữ gạch chân ở bên phải.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
        ),
        if (actionLabel != null)
          PressScale(
            onTap: onAction,
            scale: 0.92,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                actionLabel!,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.textPrimary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
