import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/api/api_exception.dart';
import '../../data/app_data.dart';
import '../../data/mock_data.dart';
import '../../data/order_repository.dart';
import '../../models/order.dart';
import '../../models/table_model.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_header_band.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/live_data.dart';
import '../../widgets/order_items_card.dart';
import '../../widgets/staff_table_tile.dart';
import '../../widgets/status_badge.dart';

/// Chi tiết bàn: trạng thái, danh sách món đang order, các thao tác quản lý bàn.
///
/// Nút "Yêu cầu thanh toán" đã bỏ theo quyết định nhóm:
/// khách hàng tự ra quầy thu ngân, nhân viên order chỉ lo order.
class TableDetailScreen extends StatefulWidget {
  final String tableId;
  const TableDetailScreen({super.key, required this.tableId});

  @override
  State<TableDetailScreen> createState() => _TableDetailScreenState();
}

class _TableDetailScreenState extends State<TableDetailScreen> {
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) => LiveData(
        sources: const {LiveSource.tables, LiveSource.orders},
        builder: _buildContent,
      );

  Widget _buildContent(BuildContext context, Future<void> Function() refresh) {
    final table = MockData.tables.firstWhere((t) => t.id == widget.tableId);
    final order = table.currentOrderId != null ? MockData.findOrder(table.currentOrderId!) : null;
    final nextStatus = order != null ? _nextStatus(order.status) : null;

    var step = 0;
    Widget appear(Widget child) => FadeSlideIn.staggered(index: step++, child: child);

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      body: Column(
        children: [
          AppHeaderBand(
            title: table.number,
            subtitle: '${table.area} · ${table.capacity} khách',
            trailing: TableStatusPill(status: table.status),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  appear(Row(
                    children: [
                      Expanded(
                        child: Text('Món đang order',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
                      ),
                      if (order != null)
                        Text(
                          'Đơn #${order.displayCode} · ${AppFormatters.time(order.createdAt)}',
                          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                        ),
                    ],
                  )),
                  // Badge trạng thái đơn hiện tại
                  if (order != null) ...[
                    const SizedBox(height: 8),
                    appear(Align(
                      alignment: Alignment.centerLeft,
                      child: _buildStatusBadge(order.status),
                    )),
                  ],
                  const SizedBox(height: 10),
                  if (order == null)
                    appear(Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const EmptyState(
                        icon: Icons.restaurant_outlined,
                        title: 'Chưa có món nào được order',
                        message: 'Bấm "Thêm món" để lên order cho bàn này',
                      ),
                    ))
                  else ...[
                    appear(OrderItemsCard(items: order.items)),
                    const SizedBox(height: 18),
                    appear(Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('Tổng tiền · ${order.totalQuantity} món',
                            style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: AnimatedValueText(
                                AppFormatters.currency(order.subtotal),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 26,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  // Nút cập nhật trạng thái đơn (hiện chỉ khi đơn đang mở và còn bước tiếp theo)
                  if (order != null && nextStatus != null) ...[
                    AppButton(
                      label: _statusActionLabel(nextStatus),
                      icon: _statusActionIcon(nextStatus),
                      variant: AppButtonVariant.dark,
                      isLoading: _isUpdating,
                      onPressed: _isUpdating
                          ? null
                          : () => _updateStatus(order, nextStatus, refresh),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // Hàng 1: Thêm món (full width)
                  AppButton(
                    label: 'Thêm món',
                    icon: Icons.add_rounded,
                    onPressed: () => Navigator.of(context)
                        .pushNamed(AppRoutes.staffCreateOrder, arguments: table.id),
                  ),
                  const SizedBox(height: 10),
                  // Hàng 2: Chuyển bàn / Gộp bàn
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Chuyển bàn',
                          icon: Icons.swap_horiz_rounded,
                          variant: AppButtonVariant.light,
                          dense: true,
                          onPressed: table.status == TableStatus.serving
                              ? () => Navigator.of(context)
                                  .pushNamed(AppRoutes.staffTransferTable, arguments: table.id)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppButton(
                          label: 'Gộp bàn',
                          icon: Icons.call_merge_rounded,
                          variant: AppButtonVariant.light,
                          dense: true,
                          onPressed: table.status == TableStatus.serving
                              ? () => Navigator.of(context)
                                  .pushNamed(AppRoutes.staffMergeTable, arguments: table.id)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Logic cập nhật trạng thái
  // ---------------------------------------------------------------------------

  /// Gọi API PATCH /orders/{id}/status → force-refresh MockData → rebuild UI.
  Future<void> _updateStatus(
      Order order, OrderStatus next, Future<void> Function() refresh) async {
    setState(() => _isUpdating = true);
    try {
      await OrderRepository.instance.updateStatus(order.id, next);
      // force: true → bypass dedup, đảm bảo lấy dữ liệu mới sau khi vừa thay đổi.
      await AppData.refresh({LiveSource.tables, LiveSource.orders}, force: true);
      // Gọi thêm refresh() để LiveData biết cần rebuild lại widget tree.
      await refresh();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.error,
          ));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  /// Bước tiếp theo trong luồng: đặt → chuẩn bị → phục vụ → hoàn thành.
  /// Trả về null nếu đơn đã xong hoặc đã hủy (không còn nút).
  OrderStatus? _nextStatus(OrderStatus current) => switch (current) {
        OrderStatus.placed => OrderStatus.preparing,
        OrderStatus.preparing => OrderStatus.serving,
        OrderStatus.serving => OrderStatus.completed,
        _ => null,
      };

  /// Nhãn hiển thị trên nút tương ứng trạng thái sẽ chuyển tới.
  String _statusActionLabel(OrderStatus next) => switch (next) {
        OrderStatus.preparing => 'Bếp đã nhận',
        OrderStatus.serving => 'Ra món',
        OrderStatus.completed => 'Hoàn thành phục vụ',
        _ => '',
      };

  /// Icon nút tương ứng.
  IconData _statusActionIcon(OrderStatus next) => switch (next) {
        OrderStatus.preparing => Icons.restaurant_rounded,
        OrderStatus.serving => Icons.room_service_rounded,
        OrderStatus.completed => Icons.check_circle_outline_rounded,
        _ => Icons.arrow_forward_rounded,
      };

  // ---------------------------------------------------------------------------
  // Status badge
  // ---------------------------------------------------------------------------

  Widget _buildStatusBadge(OrderStatus status) {
    final String label;
    final Color color;
    final Color bg;

    switch (status) {
      case OrderStatus.placed:
        label = 'Đã đặt';
        color = AppColors.textSecondary;
        bg = AppColors.surfaceAlt;
        break;
      case OrderStatus.preparing:
        label = 'Đang chuẩn bị';
        color = const Color(0xFFB45309); // amber-700
        bg = const Color(0xFFFEF3C7);   // amber-100
        break;
      case OrderStatus.serving:
        label = 'Đang phục vụ';
        color = const Color(0xFF1D4ED8); // blue-700
        bg = const Color(0xFFDBEAFE);   // blue-100
        break;
      case OrderStatus.completed:
        label = 'Hoàn thành';
        color = const Color(0xFF15803D); // green-700
        bg = const Color(0xFFDCFCE7);   // green-100
        break;
      case OrderStatus.cancelled:
        label = 'Đã hủy';
        color = AppColors.error;
        bg = AppColors.error.withValues(alpha: 0.12);
        break;
    }

    return StatusBadge(label: label, color: color, background: bg);
  }
}
