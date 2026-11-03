import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../data/app_data.dart';
import '../../data/mock_data.dart';
import '../../models/order.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_header_band.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/live_data.dart';
import '../../widgets/status_badge.dart';

/// Tab Chờ thanh toán: danh sách đơn cần thu ngân xử lý.
class PendingPaymentScreen extends StatelessWidget {
  const PendingPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      LiveData(sources: const {LiveSource.orders, LiveSource.tables}, builder: _buildContent);

  Widget _buildContent(BuildContext context, Future<void> Function() refresh) {
    final orders = MockData.pendingPaymentOrders;

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      body: Column(
        children: [
          AppHeaderBand(caption: '${orders.length} đơn cần xử lý', title: 'Chờ thanh toán'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: orders.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 80),
                        EmptyState(icon: Icons.done_all_rounded, title: 'Không có đơn nào chờ thanh toán'),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      itemCount: orders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return FadeSlideIn.staggered(
                          index: index,
                          child: _PendingOrderCard(
                            order: order,
                            onPay: () => Navigator.of(context)
                                .pushNamed(AppRoutes.cashierPayment, arguments: order.id),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingOrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onPay;

  const _PendingOrderCard({required this.order, required this.onPay});

  @override
  Widget build(BuildContext context) {
    final isProcessing = order.paymentStatus == PaymentStatus.pending;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Đơn #${order.displayCode} · ${order.tableNumber}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
              ),
              const SizedBox(width: 8),
              // "Đang xử lý" = viên nâu đen, "Chưa thanh toán" = viên trắng viền mảnh
              // (theo mockup) để hai trạng thái phân biệt rõ.
              isProcessing
                  ? StatusBadge(label: 'Đang xử lý', color: AppColors.textOnDark, background: AppColors.ink)
                  : StatusBadge(
                      label: 'Chưa thanh toán',
                      color: AppColors.textSecondary,
                      background: AppColors.surface,
                      borderColor: AppColors.textSecondary,
                    ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Nhân viên order: ${order.staffName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(AppFormatters.timeDate(order.createdAt),
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(AppFormatters.currency(order.subtotal),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.4,
                      )),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 128,
                child: AppButton(label: 'Thanh toán', dense: true, onPressed: onPay),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
