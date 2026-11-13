import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/admin_repository.dart';
import '../../models/order.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';

/// Admin xem các đơn bị hủy trong một ngày (nhóm chốt 13/11, cách A): mã đơn, bàn, số tiền,
/// lý do, ghi chú, ai hủy, lúc nào. Dữ liệu từ `GET /api/admin/cancelled-orders?date=`
/// (chỉ Admin, chặn ở backend). Web /admin xem được ở trang Đơn hàng (cột "Lý do hủy").
class CancelledOrdersScreen extends StatefulWidget {
  const CancelledOrdersScreen({super.key});

  @override
  State<CancelledOrdersScreen> createState() => _CancelledOrdersScreenState();
}

class _CancelledOrdersScreenState extends State<CancelledOrdersScreen> {
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  List<Order>? _orders;
  double _total = 0;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await AdminRepository.instance.fetchCancelledOrders(_date);
      if (mounted) {
        setState(() {
          _orders = result.orders;
          _total = result.total;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeDay(int delta) {
    final next = _date.add(Duration(days: delta));
    if (next.isAfter(DateTime.now())) return; // không xem ngày tương lai
    setState(() {
      _date = next;
      _orders = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(_date, DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(title: const Text('Đơn đã hủy', style: TextStyle(fontWeight: FontWeight.w800))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Ngày trước',
                  onPressed: _loading ? null : () => _changeDay(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    isToday ? 'Hôm nay · ${AppFormatters.weekdayDate(_date)}' : AppFormatters.weekdayDate(_date),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
                  ),
                ),
                IconButton(
                  tooltip: 'Ngày sau',
                  onPressed: _loading || isToday ? null : () => _changeDay(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _orders == null) return const Center(child: CircularProgressIndicator());

    if (_error != null && _orders == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: AppColors.error)),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }

    final orders = _orders ?? const <Order>[];

    return RefreshIndicator(
      onRefresh: _load,
      child: orders.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 60),
                EmptyState(
                  icon: Icons.task_alt_rounded,
                  title: 'Không có đơn nào bị hủy',
                  message: 'Ngày này chưa có đơn nào bị hủy.',
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: orders.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Text('${orders.length} đơn · Tổng giá trị ${AppFormatters.currency(_total)}',
                      style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600));
                }
                return _CancelledOrderCard(order: orders[i - 1]);
              },
            ),
    );
  }
}

class _CancelledOrderCard extends StatelessWidget {
  final Order order;

  const _CancelledOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(fontSize: 12.5, color: AppColors.textSecondary);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Đơn #${order.displayCode} · ${order.tableNumber ?? 'Đặt qua app'}',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppColors.textPrimary)),
              ),
              Text(AppFormatters.currency(order.subtotal),
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(10)),
            child: Text(
              [order.cancelReasonLabel ?? 'Không rõ lý do (hủy trước khi có chức năng ghi lý do)', if ((order.cancelNote ?? '').isNotEmpty) order.cancelNote!]
                  .join(': '),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.error),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hủy bởi ${order.cancelledByName ?? '—'}'
            '${order.cancelledAt != null ? ' lúc ${AppFormatters.time(order.cancelledAt!)}' : ''}'
            ' · ${order.totalQuantity} món · NV order: ${order.staffName}',
            style: muted,
          ),
        ],
      ),
    );
  }
}
