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
import 'order_staff_shell.dart';

/// Tab Cá nhân của Nhân viên Order.
class StaffProfileScreen extends StatelessWidget {
  const StaffProfileScreen({super.key});

  /// Mở một tab khác trong khung Nhân viên Order; nếu màn này đang được mở
  /// riêng lẻ (không nằm trong khung) thì mở màn tương ứng như trước.
  void _open(BuildContext context, StaffTab tab, String fallbackRoute) {
    if (OrderStaffShell.goTo(context, tab)) return;
    Navigator.of(context).pushNamed(fallbackRoute);
  }

  @override
  Widget build(BuildContext context) {
    final user = MockData.currentOrderStaff;

    var order = 0;
    Widget step(Widget child) => FadeSlideIn.staggered(index: order++, child: child);

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      body: Column(
        children: [
          const AppHeaderBand(caption: 'Tài khoản nhân viên', title: 'Cá nhân'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                step(AccountIdentityCard(user: user)),
                const SizedBox(height: 14),
                step(AppSettingGroup(
                  background: AppColors.surface,
                  divided: true,
                  children: [
                    AppSettingTile(
                      icon: Icons.table_bar_outlined,
                      label: 'Sơ đồ bàn',
                      iconBackground: AppColors.primaryLight,
                      iconShape: BoxShape.rectangle,
                      onTap: () => _open(context, StaffTab.tables, AppRoutes.staffTables),
                    ),
                    AppSettingTile(
                      icon: Icons.assignment_outlined,
                      label: 'Đơn đang phục vụ',
                      iconBackground: AppColors.primaryLight,
                      iconShape: BoxShape.rectangle,
                      onTap: () => _open(context, StaffTab.serving, AppRoutes.staffServingOrders),
                    ),
                    ThemeModeTile(iconBackground: AppColors.primaryLight, iconShape: BoxShape.rectangle),
                    AppSettingTile(
                      icon: Icons.lock_outline_rounded,
                      label: 'Đổi mật khẩu',
                      iconBackground: AppColors.primaryLight,
                      iconShape: BoxShape.rectangle,
                      onTap: () => Navigator.of(context).pushNamed(AppRoutes.staffSettings),
                    ),
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
