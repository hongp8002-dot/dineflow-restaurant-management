import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../models/reservation.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_button.dart';
import '../../widgets/labeled_value_row.dart';
import 'customer_shell.dart';

/// Màn hình xác nhận đặt bàn thành công, hiển thị sau khi khách hoàn tất bước đặt bàn.
/// Dấu tích bung ra, mã đặt bàn và các dòng thông tin hiện lần lượt.
class BookingConfirmationScreen extends StatelessWidget {
  final Reservation reservation;

  /// Số món đã đặt trước trong luồng đặt bàn qua app (0 = không đặt trước).
  final int preOrderCount;

  /// Số tiền đã thanh toán ở bước Thanh toán; null nếu không đi qua luồng đó.
  final double? paidAmount;

  /// Phương thức thanh toán đã chọn (chỉ có khi có tiền phải trả).
  final String? paymentLabel;

  const BookingConfirmationScreen({
    super.key,
    required this.reservation,
    this.preOrderCount = 0,
    this.paidAmount,
    this.paymentLabel,
  });

  @override
  Widget build(BuildContext context) {
    var order = 1;
    Widget step(Widget child) => FadeSlideIn.staggered(index: order++, child: child);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: (constraints.maxHeight - 36).clamp(0.0, double.infinity)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        const _SuccessCheck(),
                        const SizedBox(height: 14),
                        step(Text(
                          'Đặt bàn thành công!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5),
                        )),
                        const SizedBox(height: 10),
                        step(Column(
                          children: [
                            Text(
                              'Mã đặt bàn của bạn là',
                              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: AppColors.goldShadow,
                              ),
                              child: Text(
                                reservation.code,
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textOnPrimary,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ],
                        )),
                        const SizedBox(height: 22),
                        step(Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              LabeledValueRow(
                                icon: Icons.calendar_today_outlined,
                                iconInTile: true,
                                label: 'Ngày & giờ',
                                value:
                                    '${AppFormatters.time(reservation.dateTime)} · ${AppFormatters.weekdayDate(reservation.dateTime)}',
                              ),
                              const Divider(height: 24),
                              LabeledValueRow(
                                icon: Icons.people_outline,
                                iconInTile: true,
                                label: 'Số khách',
                                value: '${reservation.guestCount} khách',
                              ),
                              const Divider(height: 24),
                              LabeledValueRow(
                                icon: Icons.table_bar_outlined,
                                iconInTile: true,
                                label: reservation.isMerged
                                    ? 'Bàn (ghép ${reservation.tableIds.length} bàn)'
                                    : 'Bàn',
                                value: '${reservation.tableNumber} · ${reservation.area}',
                              ),
                              if (reservation.note != null) ...[
                                const Divider(height: 24),
                                LabeledValueRow(
                                  icon: Icons.sticky_note_2_outlined,
                                  iconInTile: true,
                                  label: 'Ghi chú',
                                  value: reservation.note!,
                                ),
                              ],
                              if (paidAmount != null) ...[
                                const Divider(height: 24),
                                LabeledValueRow(
                                  icon: Icons.restaurant_outlined,
                                  iconInTile: true,
                                  label: 'Món đặt trước',
                                  value: preOrderCount > 0 ? '$preOrderCount món' : 'Không đặt trước',
                                ),
                                const Divider(height: 24),
                                LabeledValueRow(
                                  icon: Icons.payments_outlined,
                                  iconInTile: true,
                                  label: 'Thanh toán',
                                  value: paidAmount! > 0
                                      ? '${AppFormatters.currency(paidAmount!)} · $paymentLabel'
                                      : 'Không cần trả trước',
                                ),
                              ],
                            ],
                          ),
                        )),
                        const SizedBox(height: 16),
                        step(Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primarySoft),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.schedule_rounded, size: 18, color: AppColors.textPrimary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Nhà hàng giữ bàn trong 15 phút kể từ giờ đặt. Vui lòng đến đúng giờ.',
                                  style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                    step(Column(
                      children: [
                        const SizedBox(height: 24),
                        AppButton(
                          label: 'Xem lịch đặt',
                          // Mở lại khung Khách hàng ở tab Lịch đặt (tab đã có lượt vừa đặt).
                          onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                              AppRoutes.customerHome, (route) => false,
                              arguments: CustomerTab.bookings),
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          label: 'Về trang chủ',
                          variant: AppButtonVariant.outlined,
                          onPressed: () => Navigator.of(context)
                              .pushNamedAndRemoveUntil(AppRoutes.customerHome, (route) => false),
                        ),
                      ],
                    )),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Vòng tròn dấu tích: bung ra kèm hai vòng sáng lan toả.
class _SuccessCheck extends StatefulWidget {
  const _SuccessCheck();

  @override
  State<_SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<_SuccessCheck> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pop =
        CurvedAnimation(parent: _controller, curve: const Interval(0, 0.6, curve: Curves.easeOutBack));
    final ring = CurvedAnimation(parent: _controller, curve: const Interval(0.25, 1, curve: Curves.easeOut));

    return SizedBox(
      width: 118,
      height: 118,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Hai vòng sáng lan ra ngoài.
          for (final scale in [1.0, 1.35])
            AnimatedBuilder(
              animation: ring,
              builder: (context, _) => Opacity(
                opacity: (1 - ring.value) * 0.45,
                child: Container(
                  width: 84 * (1 + (scale - 1) * ring.value),
                  height: 84 * (1 + (scale - 1) * ring.value),
                  decoration: BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                ),
              ),
            ),
          ScaleTransition(
            scale: pop,
            child: Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                shape: BoxShape.circle,
                boxShadow: AppColors.goldShadow,
              ),
              child: Icon(Icons.check_rounded, color: AppColors.textOnPrimary, size: 48),
            ),
          ),
        ],
      ),
    );
  }
}
