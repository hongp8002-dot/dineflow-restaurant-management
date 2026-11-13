import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../data/app_data.dart';
import '../../data/mock_data.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/live_data.dart';
import '../../widgets/order_card.dart';

/// Lịch sử đơn hàng của Khách hàng (mở từ Tài khoản → "Lịch sử đơn hàng").
class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => LiveData(sources: const {LiveSource.orders}, builder: _buildContent);

  Widget _buildContent(BuildContext context, Future<void> Function() refresh) {
    // Server chỉ trả đơn của chính khách đang đăng nhập (lọc theo customer_id), nên không cần
    // lọc lại ở đây. Trước đây lọc theo TÊN khách: hai khách trùng tên sẽ thấy đơn của nhau.
    final orders = [...MockData.orders]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: AppPageHeader(
                title: 'Lịch sử đơn hàng',
                subtitle: orders.isEmpty ? null : '${orders.length} đơn đã đặt qua ứng dụng',
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: refresh,
                child: orders.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 60),
                          EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'Chưa có đơn hàng nào',
                            message: 'Các đơn bạn đặt qua ứng dụng sẽ hiển thị tại đây',
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                        itemCount: orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          return FadeSlideIn.staggered(
                            index: index,
                            child: OrderCard(
                              order: order,
                              onTap: () => Navigator.of(context)
                                  .pushNamed(AppRoutes.customerOrderDetail, arguments: order.id),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
