import 'package:flutter/material.dart';

import '../../app/app_navigator.dart';
import '../../app/routes.dart';
import '../../data/mock_data.dart';
import '../../models/customer.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/app_setting_tile.dart';
import '../../widgets/theme_mode_tile.dart';
import 'customer_shell.dart';

/// Tab Cá nhân của Khách hàng.
class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = MockData.currentCustomerUser;
    final customer = MockData.currentCustomer;

    var order = 0;
    Widget step(Widget child) => FadeSlideIn.staggered(index: order++, child: child);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            step(const AppPageHeader(title: 'Tài khoản')),
            const SizedBox(height: 18),
            step(_buildIdentityCard(user.name, user.phone, user.email)),
            const SizedBox(height: 16),
            step(_buildMemberCard(context, customer)),
            const SizedBox(height: 22),
            step(const _GroupLabel('Tiện ích')),
            const SizedBox(height: 8),
            step(AppSettingGroup(children: [
              AppSettingTile(
                icon: Icons.qr_code_rounded,
                label: 'QR thành viên',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.customerMemberQr),
              ),
              AppSettingTile(
                icon: Icons.confirmation_number_outlined,
                label: 'Ví voucher',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.customerVouchers),
              ),
              AppSettingTile(
                icon: Icons.favorite_border_rounded,
                label: 'Món yêu thích',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.customerFavorites),
              ),
              AppSettingTile(
                icon: Icons.notifications_none_rounded,
                label: 'Thông báo',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.customerNotifications),
              ),
              AppSettingTile(
                icon: Icons.event_seat_outlined,
                label: 'Lịch đặt bàn',
                onTap: () {
                  if (!CustomerShell.goTo(context, CustomerTab.bookings)) {
                    Navigator.of(context).pushNamed(AppRoutes.customerMyBookings);
                  }
                },
              ),
              AppSettingTile(
                icon: Icons.receipt_long_outlined,
                label: 'Lịch sử đơn hàng',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.customerOrders),
              ),
            ])),
            const SizedBox(height: 18),
            step(const _GroupLabel('Tài khoản')),
            const SizedBox(height: 8),
            step(AppSettingGroup(children: [
              // Chọn Sáng / Tối / Theo hệ thống cho toàn app.
              const ThemeModeTile(),
              AppSettingTile(
                icon: Icons.location_on_outlined,
                label: 'Vị trí cửa hàng',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.customerStoreLocation),
              ),
              AppSettingTile(
                icon: Icons.lock_outline,
                label: 'Đổi mật khẩu',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.customerSettings),
              ),
              AppSettingTile(
                icon: Icons.help_outline,
                label: 'Trợ giúp & hỗ trợ',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.customerHelp),
              ),
            ])),
            const SizedBox(height: 18),
            step(PressScale(
              onTap: signOut,
              scale: 0.97,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
                    const SizedBox(width: 8),
                    Text('Đăng xuất',
                        style:
                            TextStyle(color: AppColors.error, fontWeight: FontWeight.w800, fontSize: 14.5)),
                  ],
                ),
              ),
            )),
            const SizedBox(height: 18),
            Center(
              child: Text('DineFlow · Phiên bản 0.1.0',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityCard(String name, String phone, String email) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              shape: BoxShape.circle,
              boxShadow: AppColors.goldShadow,
            ),
            child: Icon(Icons.person_rounded, color: AppColors.textOnPrimary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(phone, style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                Text(email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(BuildContext context, Customer customer) {
    return PressScale(
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.customerMemberQr),
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: AppColors.inkGradient,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hạng thành viên', style: TextStyle(fontSize: 11.5, color: AppColors.textOnDark)),
                  const SizedBox(height: 3),
                  Text(customer.tier.label,
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.primaryOnInk)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Điểm thưởng', style: TextStyle(fontSize: 11.5, color: AppColors.textOnDark)),
                const SizedBox(height: 3),
                CountUpText(
                  value: customer.points,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.primaryOnInk),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}