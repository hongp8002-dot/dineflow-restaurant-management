import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/app_data.dart';
import '../../data/mock_data.dart';
import '../../models/reservation.dart';

import '../../app/routes.dart';
import '../../models/invoice.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/labeled_value_row.dart';
import 'booking_checkout.dart';
import 'booking_confirmation_screen.dart';

/// Bước 3 của luồng đặt bàn qua app: "Thanh toán".
///
/// Có món đặt trước thì khách chọn phương thức và thanh toán; không đặt món thì
/// chỉ cần xác nhận giữ bàn. Xử lý thanh toán thật (cổng thanh toán, đặt cọc...)
/// là việc của backend - ở đây chỉ là giao diện demo.
class BookingPaymentScreen extends StatefulWidget {
  const BookingPaymentScreen({super.key});

  @override
  State<BookingPaymentScreen> createState() => _BookingPaymentScreenState();
}

class _BookingPaymentScreenState extends State<BookingPaymentScreen> with BookingHoldTimer {
  PaymentMethod _method = PaymentMethod.qr;

  static String _methodLabel(PaymentMethod method) => switch (method) {
        PaymentMethod.qr => 'Ví điện tử / QR',
        PaymentMethod.card => 'Thẻ ngân hàng',
        PaymentMethod.cash => 'Tiền mặt tại quán',
      };

  static IconData _methodIcon(PaymentMethod method) => switch (method) {
        PaymentMethod.qr => Icons.qr_code_2_rounded,
        PaymentMethod.card => Icons.credit_card_rounded,
        PaymentMethod.cash => Icons.payments_outlined,
      };

  bool _submitting = false;

  /// Xác nhận lượt đặt (và món đặt trước) trên server rồi sang màn thành công. Server từ chối thì ở lại
  /// màn và báo lý do; nếu lượt giữ bàn đã hết hạn ở server thì nhả bàn và đưa khách về trang chủ.
  Future<void> _complete() async {
    final checkout = BookingCheckout.instance;
    final reservation = checkout.reservation;
    if (reservation == null || !checkout.isActive || _submitting) return;

    final itemCount = checkout.preOrder.totalQuantity;
    final total = checkout.preOrder.subtotal;
    setState(() => _submitting = true);

    // Lấy trước khi await để không dùng context sau khoảng chờ.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // Thông báo nổi đè lên nút thanh toán nên để thời gian ngắn.
    void say(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 3)));

    try {
      final confirmed = await checkout.complete(payment: total > 0 ? _method : null);

      // Về màn thành công; xoá các màn của luồng khỏi ngăn xếp để nút quay lại
      // không đưa khách về lại bước thanh toán đã xong.
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          settings: const RouteSettings(name: AppRoutes.customerBookingConfirmation),
          builder: (_) => BookingConfirmationScreen(
            reservation: confirmed,
            preOrderCount: itemCount,
            paidAmount: total,
            paymentLabel: total > 0 ? _methodLabel(_method) : null,
          ),
        ),
        (route) => route.settings.name == AppRoutes.customerHome || route.isFirst,
      );
    } on ApiException catch (e) {
      say(e.message);
      // Server có thể đã hủy lượt giữ bàn do quá hạn: tải lại để biết, rồi xử lý như hết giờ.
      await AppData.refreshReservations(force: true);
      final current = MockData.reservations.where((r) => r.id == reservation.id).firstOrNull;
      if (current != null && current.status != ReservationStatus.upcoming && checkout.isActive) {
        checkout.release();
        navigator.popUntil((route) => route.settings.name == AppRoutes.customerHome || route.isFirst);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkout = BookingCheckout.instance;
    final reservation = checkout.reservation;

    if (reservation == null || !checkout.isActive) {
      return const Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: AppPageHeader(title: 'Thanh toán', showBack: true),
              ),
              Expanded(
                child: EmptyState(
                  icon: Icons.event_busy_outlined,
                  title: 'Không có lượt đặt bàn đang giữ',
                  message: 'Lượt đặt bàn đã hoàn tất hoặc đã hết thời gian giữ bàn',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final items = checkout.preOrder.items;
    final total = checkout.preOrder.subtotal;
    final needsPayment = total > 0;

    var order = 0;
    Widget step(Widget child) => FadeSlideIn.staggered(index: order++, child: child);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  const AppPageHeader(
                      title: 'Thanh toán', subtitle: 'Hoàn tất để chốt lượt đặt bàn', showBack: true),
                  const SizedBox(height: 16),
                  const CheckoutSteps(current: 2),
                  const SizedBox(height: 14),
                  HoldCountdownBanner(remaining: checkout.remaining),
                  const SizedBox(height: 18),
                  step(Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    decoration:
                        BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      children: [
                        LabeledValueRow(
                          icon: Icons.calendar_today_outlined,
                          iconInTile: true,
                          label: 'Thời gian',
                          value:
                              '${AppFormatters.time(reservation.dateTime)} · ${AppFormatters.weekdayDate(reservation.dateTime)}',
                        ),
                        LabeledValueRow(
                          icon: Icons.table_bar_outlined,
                          iconInTile: true,
                          label: 'Bàn',
                          value: '${reservation.tableNumber} · ${reservation.area}',
                        ),
                        LabeledValueRow(
                          icon: Icons.people_outline_rounded,
                          iconInTile: true,
                          label: 'Số khách',
                          value: '${reservation.guestCount} khách',
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 20),
                  step(Text('Món đặt trước',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary))),
                  const SizedBox(height: 10),
                  if (items.isEmpty)
                    step(Container(
                      padding: const EdgeInsets.all(14),
                      decoration:
                          BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          Icon(Icons.restaurant_outlined, size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Bạn không đặt món trước. Có thể gọi món khi đến quán.',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ))
                  else ...[
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('${item.quantity}x',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(item.foodName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                            ),
                            Text(AppFormatters.currency(item.total),
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                      decoration:
                          BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        children: [
                          Text('Tổng cộng',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  AppFormatters.currency(total),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Phương thức thanh toán',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
                    const SizedBox(height: 10),
                    for (final method in [PaymentMethod.qr, PaymentMethod.card, PaymentMethod.cash])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _MethodTile(
                          icon: _methodIcon(method),
                          label: _methodLabel(method),
                          selected: _method == method,
                          onTap: () => setState(() => _method = method),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: AppButton(
                key: const ValueKey('booking-pay'),
                label: needsPayment ? 'Thanh toán ${AppFormatters.currency(total)}' : 'Xác nhận giữ bàn',
                isLoading: _submitting,
                onPressed: _complete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Một lựa chọn phương thức thanh toán; đang chọn = viền vàng, nền vàng nhạt.
class _MethodTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MethodTile({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      scale: 0.98,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: 1.4),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.textPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: AppColors.textPrimary,
                  )),
            ),
            AnimatedSwitcher(
              duration: AppMotion.fast,
              child: Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                key: ValueKey(selected),
                size: 22,
                color: selected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
