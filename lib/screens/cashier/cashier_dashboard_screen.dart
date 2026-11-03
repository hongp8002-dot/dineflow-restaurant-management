import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../data/app_data.dart';
import '../../data/mock_data.dart';
import '../../data/shift_repository.dart';
import '../../models/shift.dart';
import '../../models/user.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_header_band.dart';
import '../../widgets/live_data.dart';
import '../../widgets/status_badge.dart';
import 'cashier_shell.dart';

/// Tab Tổng quan của Thu ngân.
class CashierDashboardScreen extends StatelessWidget {
  const CashierDashboardScreen({super.key});

  /// Mở một tab khác trong khung Thu ngân; nếu màn này đang được mở riêng lẻ
  /// (không nằm trong khung) thì mở màn tương ứng như trước.
  static void _open(BuildContext context, CashierTab tab, String fallbackRoute) {
    if (CashierShell.goTo(context, tab)) return;
    Navigator.of(context).pushNamed(fallbackRoute);
  }

  /// Số liệu lấy từ đơn + hóa đơn thật, tự tải mới khi mở màn và khi dữ liệu đổi.
  @override
  Widget build(BuildContext context) => LiveData(
        sources: const {LiveSource.orders, LiveSource.invoices},
        builder: (context, _) => _buildContent(context),
      );

  Widget _buildContent(BuildContext context) {
    final user = MockData.currentCashier;
    final pendingCount = MockData.pendingPaymentOrders.length;
    final paidCount = MockData.todayInvoices.length;

    var order = 0;
    Widget step(Widget child) => FadeSlideIn.staggered(index: order++, child: child);

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      body: Column(
        children: [
          AppHeaderBand(
            caption: user.name,
            title: 'Tổng quan ca làm',
            titleTrailing: StatusBadge(
              label: user.role.label,
              color: AppColors.textOnPrimary,
              background: AppColors.primary,
            ),
            showBack: false,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                // Thẻ ca hiện tại – load từ server
                step(_ShiftCard(
                  onDetail: () => _open(context, CashierTab.shift, AppRoutes.cashierShift),
                )),
                const SizedBox(height: 12),
                step(Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tổng doanh thu hôm nay',
                          style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: CountUpText(
                          value: MockData.computedTodayRevenue,
                          formatter: (v) => AppFormatters.currency(v.round()),
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 12),
                step(Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _CountTile(value: pendingCount, label: 'Đơn chờ thanh toán')),
                    const SizedBox(width: 10),
                    Expanded(child: _CountTile(value: paidCount, label: 'Đơn đã thanh toán')),
                    const SizedBox(width: 10),
                    Expanded(
                        child:
                            _CountTile(value: MockData.computedTodayOrderCount, label: 'Tổng đơn hôm nay')),
                  ],
                )),
                const SizedBox(height: 22),
                step(Text('Truy cập nhanh',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary))),
                const SizedBox(height: 10),
                step(Row(
                  children: [
                    Expanded(
                      child: _ShortcutCard(
                        icon: Icons.hourglass_empty_rounded,
                        label: 'Chờ thanh toán',
                        onTap: () => _open(context, CashierTab.pending, AppRoutes.cashierPendingPayment),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ShortcutCard(
                        icon: Icons.history_rounded,
                        label: 'Lịch sử',
                        onTap: () => _open(context, CashierTab.history, AppRoutes.cashierHistory),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ShortcutCard(
                        icon: Icons.badge_outlined,
                        label: 'Ca làm',
                        onTap: () => _open(context, CashierTab.shift, AppRoutes.cashierShift),
                      ),
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

/// Thẻ ca hiện tại: load dữ liệu thật từ server.
///
/// - Đang load → hiện skeleton/placeholder.
/// - Chưa mở ca → hiện dòng "Chưa có ca đang mở" + nút "Chi tiết" dẫn tới tab Ca.
/// - Đang mở ca → hiện tên thu ngân + giờ bắt đầu + nút "Chi tiết".
class _ShiftCard extends StatefulWidget {
  final VoidCallback onDetail;

  const _ShiftCard({required this.onDetail});

  @override
  State<_ShiftCard> createState() => _ShiftCardState();
}

class _ShiftCardState extends State<_ShiftCard> {
  Shift? _shift;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final shift = await ShiftRepository.instance.fetchCurrent();
      if (mounted) setState(() => _shift = shift);
    } catch (_) {
      // Lỗi load ca → hiển thị "chưa mở ca"; thu ngân có thể bấm Chi tiết.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.storefront_outlined, color: AppColors.textPrimary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _loading
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Placeholder(width: 100, height: 13),
                      const SizedBox(height: 6),
                      _Placeholder(width: 160, height: 15),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _shift != null && _shift!.isOpen ? 'Ca làm · Đang mở' : 'Ca làm · Chưa mở',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _shift != null && _shift!.isOpen
                            ? 'Bắt đầu lúc ${AppFormatters.time(_shift!.openedAt)}'
                            : 'Bấm Chi tiết để mở ca',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 8),
          PressScale(
            onTap: widget.onDetail,
            scale: 0.92,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.ink, width: 1.3),
              ),
              child: Text('Chi tiết',
                  style:
                      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Khung xám mờ dùng làm placeholder khi đang load ca.
class _Placeholder extends StatelessWidget {
  final double width;
  final double height;

  const _Placeholder({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Ô đếm số đơn: số lớn + nhãn hai dòng.
class _CountTile extends StatelessWidget {
  final int value;
  final String label;

  const _CountTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: CountUpText(
              value: value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.3)),
        ],
      ),
    );
  }
}

/// Ô truy cập nhanh: icon trong ô vàng nhạt + nhãn đậm.
class _ShortcutCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ShortcutCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      scale: 0.94,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.textPrimary, size: 20),
            ),
            const SizedBox(height: 10),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
