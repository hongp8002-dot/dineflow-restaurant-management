import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../data/app_data.dart';
import '../../data/mock_data.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_header_band.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/invoice_card.dart';
import '../../widgets/live_data.dart';

/// Tab Lịch sử: danh sách hóa đơn đã thanh toán.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      LiveData(sources: const {LiveSource.invoices}, builder: _buildContent);

  Widget _buildContent(BuildContext context, Future<void> Function() refresh) {
    // Server đã sắp mới nhất trước; hóa đơn mẫu thì thêm vào sau nên đảo lại cho giống.
    final invoices = MockData.invoices.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      body: Column(
        children: [
          AppHeaderBand(caption: '${invoices.length} hóa đơn đã thanh toán', title: 'Lịch sử thanh toán'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: invoices.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 60),
                        EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'Chưa có hóa đơn nào',
                          message: 'Các hóa đơn đã thanh toán trong ca sẽ hiển thị tại đây',
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      itemCount: invoices.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final invoice = invoices[index];
                        return FadeSlideIn.staggered(
                          index: index,
                          child: InvoiceCard(
                            invoice: invoice,
                            onTap: () =>
                                Navigator.of(context).pushNamed(AppRoutes.cashierInvoice, arguments: invoice),
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
