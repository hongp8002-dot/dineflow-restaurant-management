import 'package:flutter/material.dart';

import '../../app/app_navigator.dart';
import '../../app/routes.dart';
import '../../data/mock_data.dart';
import '../../theme/app_colors.dart';
import '../../widgets/account_identity_card.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_header_band.dart';
import '../../widgets/app_setting_tile.dart';
import '../../widgets/theme_mode_tile.dart';
import 'cashier_shell.dart';

/// Tab Cá nhân của Thu ngân.
class CashierProfileScreen extends StatelessWidget {
  const CashierProfileScreen({super.key});

  /// Mở một tab khác trong khung Thu ngân; nếu màn này đang được mở riêng lẻ
  /// thì mở màn tương ứng như trước.
  void _open(BuildContext context, CashierTab tab, String fallbackRoute) {
    if (CashierShell.goTo(context, tab)) return;
    Navigator.of(context).pushNamed(fallbackRoute);
  }

  @override
  Widget build(BuildContext context) {
    var order = 0;
    Widget step(Widget child) => FadeSlideIn.staggered(index: order++, child: child);

    AppSettingTile tile(IconData icon, String label, VoidCallback onTap) => AppSettingTile(
          icon: icon,
          label: label,
          iconBackground: AppColors.primaryLight,
          iconShape: BoxShape.rectangle,
          onTap: onTap,
        );

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      body: Column(
        children: [
          const AppHeaderBand(caption: 'Tài khoản thu ngân', title: 'Cá nhân'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                step(AccountIdentityCard(user: MockData.currentCashier)),
                const SizedBox(height: 14),
                step(AppSettingGroup(
                  background: AppColors.surface,
                  divided: true,
                  children: [
                    tile(Icons.badge_outlined, 'Ca làm việc',
                        () => _open(context, CashierTab.shift, AppRoutes.cashierShift)),
                    tile(Icons.history_rounded, 'Lịch sử thanh toán',
                        () => _open(context, CashierTab.history, AppRoutes.cashierHistory)),
                    ThemeModeTile(iconBackground: AppColors.primaryLight, iconShape: BoxShape.rectangle),
                    tile(Icons.lock_outline_rounded, 'Đổi mật khẩu',
                        () => Navigator.of(context).pushNamed(AppRoutes.cashierSettings)),
                  ],
                )),
                const SizedBox(height: 14),
                step(AppSettingGroup(
                  background: AppColors.surface,
                  children: [
                    AppSettingTile(
                      icon: Icons.logout_rounded,
                      label: 'Đăng xuất',
                      color: AppColors.error,
                      iconBackground: AppColors.surfaceAlt,
                      iconShape: BoxShape.rectangle,
                      onTap: signOut,
                    ),
                  ],
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
