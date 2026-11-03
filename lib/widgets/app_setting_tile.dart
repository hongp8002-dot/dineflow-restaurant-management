import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_animations.dart';

/// Một dòng mục trong màn Cá nhân / Cài đặt (icon - nhãn - mũi tên).
///
/// Dùng chung cho cả Khách hàng, Nhân viên Order và Thu ngân; trước đây mỗi
/// màn tự viết một bản `_ProfileTile` gần giống nhau.
class AppSettingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Màu nhấn cho mục nguy hiểm (vd: Đăng xuất dùng màu đỏ).
  /// null = [AppColors.textPrimary] (màu đọc theo bảng màu đang dùng nên không đặt mặc định được).
  final Color? color;

  /// Nền ô icon; để null thì dùng vàng (mục thường) hoặc đỏ nhạt (mục nguy hiểm).
  final Color? iconBackground;

  /// Hình ô icon: tròn (mặc định) hoặc vuông bo góc như mockup Nhân viên Order.
  final BoxShape iconShape;

  /// Giá trị đang chọn, hiện mờ trước mũi tên (vd "Sáng" ở mục Giao diện).
  final String? value;

  const AppSettingTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.iconBackground,
    this.iconShape = BoxShape.circle,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? AppColors.textPrimary;
    final isDanger = color == AppColors.error;
    return PressScale(
      onTap: onTap,
      scale: 0.98,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBackground ?? (isDanger ? AppColors.errorBg : AppColors.primary),
                shape: iconShape,
                borderRadius: iconShape == BoxShape.rectangle ? BorderRadius.circular(12) : null,
              ),
              child: Icon(icon, size: 19, color: isDanger ? AppColors.error : AppColors.textOnPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w600),
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              Text(value!, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
            Icon(Icons.chevron_right_rounded, size: 20, color: isDanger ? color : AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Khung bo góc bọc một nhóm [AppSettingTile].
class AppSettingGroup extends StatelessWidget {
  final List<Widget> children;

  /// Nền khung: kem khi đặt trên trang trắng, trắng khi đặt trên trang nền kem.
  /// null = [AppColors.surfaceAlt].
  final Color? background;

  /// Kẻ đường mảnh giữa các mục (mockup Nhân viên Order).
  final bool divided;

  const AppSettingGroup({
    super.key,
    required this.children,
    this.background,
    this.divided = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: background ?? AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (divided && i > 0) Divider(height: 1, thickness: 1, color: AppColors.border),
            children[i],
          ],
        ],
      ),
    );
  }
}
