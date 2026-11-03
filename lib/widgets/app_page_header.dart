import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_animations.dart';

/// Tiêu đề trang lớn đặt trong thân trang, theo mockup ("Đặt bàn", "Đơn của bạn").
///
/// Thay cho AppBar ở các màn của Khách hàng. Nút quay lại (hình tròn nền kem)
/// tự hiện khi màn hình được mở chồng lên màn khác và có thể quay về; khi màn
/// hình là một tab trong khung điều hướng thì không hiện.
class AppPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// Widget nhỏ bên phải tiêu đề (vd: chip số món).
  final Widget? trailing;

  /// Ép hiện/ẩn nút quay lại; để null thì tự xác định theo route hiện tại.
  final bool? showBack;

  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showBack,
  });

  @override
  Widget build(BuildContext context) {
    final canGoBack = showBack ?? (ModalRoute.of(context)?.impliesAppBarDismissal ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canGoBack) ...[
          PressScale(
            onTap: () => Navigator.of(context).maybePop(),
            scale: 0.88,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.surfaceAlt, shape: BoxShape.circle),
              child: Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 14),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.6,
                  height: 1.15,
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ],
    );
  }
}
