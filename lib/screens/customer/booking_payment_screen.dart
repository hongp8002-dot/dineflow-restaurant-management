import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_exception.dart';
import '../../data/app_data.dart';
import '../../data/mock_data.dart';
import '../../data/settings_repository.dart';
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

// Tài khoản nhận chuyển khoản lấy từ server (GET /api/settings → config/restaurant.php),
// không viết cứng trong app. Xem SettingsRepository.

/// Bước 3 của luồng đặt bàn qua app: "Thanh toán".
///
/// Phương thức duy nhất: Chuyển khoản ngân hàng (CK) qua QR VietQR.
/// Xử lý thanh toán thật là việc của backend – màn này chỉ hiện QR để quét.
class BookingPaymentScreen extends StatefulWidget {
  const BookingPaymentScreen({super.key});

  @override
  State<BookingPaymentScreen> createState() => _BookingPaymentScreenState();
}

class _BookingPaymentScreenState extends State<BookingPaymentScreen>
    with BookingHoldTimer {
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _complete() async {
    final checkout = BookingCheckout.instance;
    final reservation = checkout.reservation;
    if (reservation == null || !checkout.isActive || _submitting) return;

    final itemCount = checkout.preOrder.totalQuantity;
    final total = checkout.preOrder.subtotal;
    setState(() => _submitting = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    void say(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 3)));

    try {
      // Luôn dùng PaymentMethod.qr cho chuyển khoản QR
      final confirmed = await checkout.complete(
        payment: total > 0 ? PaymentMethod.qr : null,
      );

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          settings: const RouteSettings(name: AppRoutes.customerBookingConfirmation),
          builder: (_) => BookingConfirmationScreen(
            reservation: confirmed,
            preOrderCount: itemCount,
            paidAmount: total,
            paymentLabel: total > 0 ? 'Chuyển khoản ngân hàng' : null,
          ),
        ),
        (route) => route.settings.name == AppRoutes.customerHome || route.isFirst,
      );
    } on ApiException catch (e) {
      say(e.message);
      await AppData.refreshReservations(force: true);
      final current = MockData.reservations
          .where((r) => r.id == reservation.id)
          .firstOrNull;
      if (current != null &&
          current.status != ReservationStatus.upcoming &&
          checkout.isActive) {
        checkout.release();
        navigator.popUntil(
            (route) => route.settings.name == AppRoutes.customerHome || route.isFirst);
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
                    title: 'Thanh toán',
                    subtitle: 'Hoàn tất để chốt lượt đặt bàn',
                    showBack: true,
                  ),
                  const SizedBox(height: 16),
                  const CheckoutSteps(current: 2),
                  const SizedBox(height: 14),
                  HoldCountdownBanner(remaining: checkout.remaining),
                  const SizedBox(height: 18),

                  // ── Thông tin đặt bàn ───────────────────────────────────
                  step(Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(20),
                    ),
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

                  // ── Món đặt trước ───────────────────────────────────────
                  step(Text('Món đặt trước',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.textPrimary))),
                  const SizedBox(height: 10),
                  if (items.isEmpty)
                    step(Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          Icon(Icons.restaurant_outlined,
                              size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Bạn không đặt món trước. Có thể gọi món khi đến quán.',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.35),
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('${item.quantity}x',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800, fontSize: 12)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(item.foodName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 14, color: AppColors.textPrimary)),
                            ),
                            Text(AppFormatters.currency(item.total),
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),

                    // Tổng cộng
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                      decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        children: [
                          Text('Tổng cộng',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary)),
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

                    // ── QR Chuyển khoản ─────────────────────────────────
                    step(_BankQrSection(
                      amount: total,
                      // Mã đặt bàn (DF-xxxx) khớp với mã NV Order / Thu ngân / Admin thấy trong Lịch đặt bàn
                      refId: reservation.code,
                    )),
                  ],
                ],
              ),
            ),

            // ── Nút xác nhận ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: AppButton(
                key: const ValueKey('booking-pay'),
                label: needsPayment
                    ? 'Xác nhận đã chuyển khoản'
                    : 'Xác nhận giữ bàn',
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

// ─────────────────────────────────────────────────────────────────────────────
// Widget QR + thông tin ngân hàng
// ─────────────────────────────────────────────────────────────────────────────

class _BankQrSection extends StatelessWidget {
  final double amount;
  final String refId;

  const _BankQrSection({required this.amount, required this.refId});

  @override
  Widget build(BuildContext context) {
    final bank = SettingsRepository.instance.bank;
    if (bank == null) {
      // Không hiện số tài khoản đoán mò: thà báo lỗi để khách không chuyển nhầm.
      return const EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Chưa tải được thông tin chuyển khoản',
        message: 'Kiểm tra kết nối mạng rồi đăng nhập lại để tải thông tin tài khoản của nhà hàng.',
      );
    }
    final noteText = 'Dat ban $refId DineFlow';
    final qrUrl = bank.qrImageUrl(amount, noteText);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(children: [
            Icon(Icons.account_balance_rounded, size: 18, color: AppColors.textPrimary),
            const SizedBox(width: 8),
            Text('Chuyển khoản ngân hàng',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ]),
          const SizedBox(height: 16),

          // QR code từ VietQR
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.softShadow,
            ),
            child: Image.network(
              qrUrl,
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              loadingBuilder: (ctx, child, prog) {
                if (prog == null) return child;
                return const SizedBox(
                  width: 200,
                  height: 200,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              },
              errorBuilder: (ctx, _, __) => Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_2_rounded,
                        size: 72, color: AppColors.textSecondary),
                    const SizedBox(height: 8),
                    Text('Không tải được QR',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Thông tin tài khoản
          _InfoRow(label: 'Ngân hàng', value: bank.name),
          const SizedBox(height: 8),
          _InfoRow(
            label: 'Số TK',
            value: bank.accountNo,
            copyValue: bank.accountNo,
          ),
          const SizedBox(height: 8),
          _InfoRow(label: 'Chủ TK', value: bank.accountName),
          const SizedBox(height: 8),
          _InfoRow(
            label: 'Số tiền',
            value: AppFormatters.currency(amount),
            highlight: true,
          ),
          const SizedBox(height: 8),
          _InfoRow(
            label: 'Nội dung',
            value: noteText,
            copyValue: noteText,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Quét mã QR bằng app ngân hàng để điền tự động. '
                  'Nhập đúng nội dung chuyển khoản để hệ thống xác nhận.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final String? copyValue;
  final bool highlight;

  const _InfoRow({
    required this.label,
    required this.value,
    this.copyValue,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(label,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
              color: highlight ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),
        if (copyValue != null)
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: copyValue!));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text('Đã sao chép "$copyValue"'),
                  duration: const Duration(seconds: 2),
                ));
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.copy_rounded, size: 16, color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }
}
