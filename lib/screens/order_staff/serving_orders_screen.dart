import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../data/app_data.dart';
import '../../data/mock_data.dart';
import '../../models/order.dart';
import '../../models/table_model.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_header_band.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/live_data.dart';
import '../../widgets/order_card.dart';

/// Tab Đơn đang phục vụ: danh sách các đơn tại bàn chưa hoàn thành (đã đặt, đang chuẩn bị, đang phục vụ).
/// Kéo xuống để làm mới.
class ServingOrdersScreen extends StatelessWidget {
  const ServingOrdersScreen({super.key});

  static const _openStatuses = {OrderStatus.placed, OrderStatus.preparing, OrderStatus.serving};

  @override
  Widget build(BuildContext context) {
    return LiveData(
      sources: const {LiveSource.tables, LiveSource.orders},
      builder: _buildContent,
    );
  }

  Widget _buildContent(BuildContext context, Future<void> Function() refresh) {
    final orders = MockData.orders
        .where((o) => o.tableNumber != null && _openStatuses.contains(o.status))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      body: Column(
        children: [
          AppHeaderBand(
            caption: '${orders.length} đơn đang mở',
            title: 'Đơn đang phục vụ',
            // Mở bằng mục "Đơn đang phục vụ" ở màn khác thì tự hiện nút quay lại.
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: orders.isEmpty
                  // ListView để kéo-làm-mới vẫn dùng được khi danh sách trống.
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 80),
                        EmptyState(icon: Icons.check_circle_outline, title: 'Không có đơn nào đang phục vụ'),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      itemCount: orders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        // Không còn dùng "bàn đầu tiên" làm phương án dự phòng: mở nhầm
                        // bàn khác nguy hiểm hơn là không mở gì.
                        final matchingTables = MockData.tables.where((t) => t.currentOrderId == order.id);
                        final TableModel? table = matchingTables.isEmpty ? null : matchingTables.first;
                        return FadeSlideIn.staggered(
                          index: index,
                          child: OrderCard(
                            order: order,
                            onTap: table == null
                                ? () => ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(const SnackBar(
                                    content:
                                        Text('Đơn này chưa gắn với bàn nào nên không mở được chi tiết bàn'),
                                  ))
                                : () => Navigator.of(context)
                                    .pushNamed(AppRoutes.staffTableDetail, arguments: table.id),
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
