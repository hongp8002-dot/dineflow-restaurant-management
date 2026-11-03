import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_animations.dart';

/// Một mục trên thanh điều hướng dưới cùng.
class AppNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// Số hiển thị trên huy hiệu (0 nghĩa là không hiện).
  final int badgeCount;

  const AppNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount = 0,
  });
}

/// Thanh điều hướng dưới cùng dùng chung cho các vai trò.
/// Tab đang chọn được bọc trong "viên thuốc" màu vàng, icon đổi từ nét sang
/// đặc kèm hiệu ứng phóng nhẹ - đồng bộ với bảng màu vàng/đen/trắng của app.
class AppBottomNav extends StatelessWidget {
  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Chế độ gọn cho thanh có nhiều mục (từ 5 mục trở lên như vai trò Admin):
  /// thu nhỏ chữ và "viên thuốc" để mỗi mục vẫn đủ chỗ trên máy hẹp.
  final bool compact;

  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(compact ? 4 : 10, 8, compact ? 4 : 10, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(items.length, (i) {
              return _NavButton(
                item: items[i],
                selected: currentIndex == i,
                compact: compact,
                onTap: () => onTap(i),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final AppNavItem item;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = AnimatedSwitcher(
      duration: AppMotion.fast,
      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
      child: Icon(
        selected ? item.activeIcon : item.icon,
        key: ValueKey(selected),
        size: compact ? 19 : 21,
        color: selected ? AppColors.textOnPrimary : AppColors.textSecondary,
      ),
    );

    return Expanded(
      child: PressScale(
        onTap: onTap,
        scale: 0.9,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AppMotion.normal,
              curve: Curves.easeOutCubic,
              height: compact ? 28 : 32,
              constraints: BoxConstraints(maxWidth: compact ? 44 : 54),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: item.badgeCount > 0
                    ? Badge(
                        label: Text('${item.badgeCount}'),
                        backgroundColor: selected ? AppColors.ink : AppColors.error,
                        textColor: AppColors.textOnDark,
                        child: icon,
                      )
                    : icon,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: AppMotion.normal,
              style: TextStyle(
                fontSize: compact ? 9.5 : 10.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
              child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
