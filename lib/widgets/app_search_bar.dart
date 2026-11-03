import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'app_animations.dart';

/// Thanh tìm kiếm dùng chung.
class AppSearchBar extends StatelessWidget {
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilterTap;
  final TextEditingController? controller;

  /// Màu nền ô tìm kiếm: mặc định kem (trên nền trắng); trên nền kem thì truyền trắng.
  /// null = [AppColors.surfaceAlt] (màu đọc theo bảng màu đang dùng nên không đặt mặc định được).
  final Color? fillColor;

  const AppSearchBar({
    super.key,
    this.hint = 'Tìm kiếm món ăn...',
    this.onChanged,
    this.onFilterTap,
    this.controller,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: fillColor ?? AppColors.surfaceAlt,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
              prefixIcon: const Icon(Icons.search_rounded, size: 22),
              border: _border(Colors.transparent),
              enabledBorder: _border(Colors.transparent),
              focusedBorder: _border(AppColors.primaryDark, width: 1.4),
            ),
          ),
        ),
        if (onFilterTap != null) ...[
          const SizedBox(width: 10),
          PressScale(
            onTap: onFilterTap,
            scale: 0.9,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.tune_rounded, size: 21, color: AppColors.textPrimary),
            ),
          ),
        ],
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: color, width: width),
      );
}
