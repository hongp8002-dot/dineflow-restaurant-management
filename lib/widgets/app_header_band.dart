import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'app_animations.dart';

/// Dải tiêu đề nền vàng nhạt ở đầu trang, theo bộ mockup Nhân viên Order
/// (Sơ đồ bàn, Chi tiết bàn, Order món, Chuyển bàn...).
///
/// - Trang là một tab: dòng phụ nhỏ [caption] ở trên + tiêu đề lớn, có thể kèm
///   nhãn nhỏ [titleTrailing] ngay sau tiêu đề (vd "Phục vụ").
/// - Trang mở chồng lên trang khác: nút quay lại tròn nền trắng bên trái,
///   [subtitle] ở dưới tiêu đề, [trailing] ở mép phải (vd trạng thái bàn).
///
/// Dải tự chừa chỗ cho thanh trạng thái nên trang dùng nó không cần AppBar.
class AppHeaderBand extends StatelessWidget {
  final String title;

  /// Dòng nhỏ phía trên tiêu đề (trang dạng tab).
  final String? caption;

  /// Dòng nhỏ phía dưới tiêu đề (trang mở chồng).
  final String? subtitle;

  /// Widget nhỏ đứng ngay sau tiêu đề.
  final Widget? titleTrailing;

  /// Widget ở mép phải của dải.
  final Widget? trailing;

  /// Ép hiện/ẩn nút quay lại; để null thì tự xác định theo route hiện tại.
  final bool? showBack;

  const AppHeaderBand({
    super.key,
    required this.title,
    this.caption,
    this.subtitle,
    this.titleTrailing,
    this.trailing,
    this.showBack,
  });

  @override
  Widget build(BuildContext context) {
    final canGoBack = showBack ?? (ModalRoute.of(context)?.impliesAppBarDismissal ?? false);
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Container(
        width: double.infinity,
        color: AppColors.primaryLight,
        padding: EdgeInsets.fromLTRB(20, topInset + (canGoBack ? 16 : 28), 20, canGoBack ? 16 : 20),
        child: Row(
          children: [
            if (canGoBack) ...[
              Semantics(
                button: true,
                label: 'Quay lại',
                child: PressScale(
                  onTap: () => Navigator.of(context).maybePop(),
                  scale: 0.88,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                    child: Icon(Icons.chevron_left_rounded, size: 28, color: AppColors.textPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (caption != null) ...[
                    Text(
                      caption!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: canGoBack ? 26 : 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.6,
                            height: 1.15,
                          ),
                        ),
                      ),
                      if (titleTrailing != null) ...[const SizedBox(width: 10), titleTrailing!],
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.3),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ],
        ),
      ),
    );
  }
}
