import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/theme_settings.dart';
import 'app_animations.dart';
import 'app_setting_tile.dart';

/// Mục "Giao diện" ở trang tài khoản: hiện chế độ đang dùng, chạm để chọn
/// Sáng / Tối / Theo hệ thống. Dùng chung cho Khách hàng, Nhân viên Order và Thu ngân.
class ThemeModeTile extends StatelessWidget {
  /// Nền ô icon, theo kiểu của từng màn tài khoản (xem [AppSettingTile]).
  final Color? iconBackground;
  final BoxShape iconShape;

  const ThemeModeTile({super.key, this.iconBackground, this.iconShape = BoxShape.circle});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeSettings.mode,
      builder: (context, mode, _) => AppSettingTile(
        key: const ValueKey('theme-mode-tile'),
        icon: AppThemeSettings.icon(mode),
        label: 'Giao diện',
        value: AppThemeSettings.label(mode),
        iconBackground: iconBackground,
        iconShape: iconShape,
        onTap: () => _showThemeModeSheet(context),
      ),
    );
  }
}

void _showThemeModeSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      final current = AppThemeSettings.mode.value;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Giao diện', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 12),
              for (final option in AppThemeSettings.options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ThemeOption(
                    mode: option,
                    selected: option == current,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      AppThemeSettings.mode.value = option;
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Một lựa chọn trong bảng Giao diện; đang chọn = nền vàng nhạt, viền vàng, dấu ✓.
class _ThemeOption extends StatelessWidget {
  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({required this.mode, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      key: ValueKey('theme-option-${mode.name}'),
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          children: [
            Icon(AppThemeSettings.icon(mode), size: 20, color: AppColors.textPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppThemeSettings.label(mode),
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
            if (selected)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: Icon(Icons.check_rounded, size: 14, color: AppColors.textOnPrimary),
              ),
          ],
        ),
      ),
    );
  }
}
