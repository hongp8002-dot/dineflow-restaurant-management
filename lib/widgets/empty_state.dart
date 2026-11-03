import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'app_animations.dart';

/// Trạng thái rỗng dùng chung (giỏ hàng trống, danh sách rỗng...).
/// Có hiệu ứng icon phóng to nhẹ khi xuất hiện.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.7, end: 1),
              duration: AppMotion.slow,
              curve: AppMotion.emphasized,
              builder: (context, value, child) => Transform.scale(scale: value, child: child),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                child: Icon(icon, size: 42, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 18),
            FadeSlideIn(
              delay: const Duration(milliseconds: 120),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
                  if (message != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      message!,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.45),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (action != null) ...[const SizedBox(height: 18), action!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
