import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../data/app_data.dart';
import '../../data/cart_store.dart';
import '../../data/mock_data.dart';
import '../../models/food.dart';
import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/food_image.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/labeled_value_row.dart';
import '../../widgets/live_data.dart';
import '../../widgets/order_card.dart';
import '../../widgets/status_badge.dart';
import 'customer_shell.dart';

/// Tìm món theo id mà không ném lỗi nếu dữ liệu đơn trỏ tới món đã bị xoá.
Food? _findFood(String id) {
  for (final food in MockData.foods) {
    if (food.id == id) return food;
  }
  return null;
}

/// Dựng lại danh sách món từ đơn cũ để "Đặt lại".
///
/// - Bỏ qua món không còn trong thực đơn hoặc đang hết món.
/// - Dùng **giá hiện tại** của thực đơn (giá trong đơn cũ có thể đã đổi).
/// - Chỉ giữ các tuỳ chọn (size/topping) mà món vẫn còn, theo giá hiện tại.
({List<OrderItem> items, int skipped}) _buildReorderItems(Order order) {
  final items = <OrderItem>[];
  var skipped = 0;
  final stamp = DateTime.now().millisecondsSinceEpoch;

  for (final (i, old) in order.items.indexed) {
    final food = _findFood(old.foodId);
    if (food == null || !food.isAvailable) {
      skipped++;
      continue;
    }
    final options = [
      for (final opt in old.selectedOptions) ...food.options.where((o) => o.id == opt.id),
    ];
    items.add(OrderItem(
      id: '${food.id}-reorder-$stamp-$i',
      foodId: food.id,
      foodName: food.name,
      price: food.price,
      quantity: old.quantity,
      selectedOptions: options,
      note: old.note,
    ));
  }
  return (items: items, skipped: skipped);
}

/// Hỏi khách khi danh sách món đặt trước đang có sẵn món.
/// Trả về true = thay thế, false = thêm vào, null = huỷ.
Future<bool?> _askReplaceOrAppend(BuildContext context, int currentCount) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Bạn đang có món đã chọn'),
      content: Text('Danh sách món đặt trước đang có $currentCount món. '
          'Bạn muốn thay bằng món của đơn này hay thêm vào?'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Huỷ')),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Thay thế')),
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Thêm vào')),
      ],
    ),
  );
}

/// Chi tiết đơn hàng + theo dõi trạng thái (timeline):
/// Đã đặt → Đang chuẩn bị → Đang phục vụ → Hoàn thành.
/// Bố cục đồng bộ với màn "Đơn của bạn": danh sách món có ảnh, khối tổng tiền nền kem.
class OrderDetailScreen extends StatelessWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  static const _steps = [
    OrderStatus.placed,
    OrderStatus.preparing,
    OrderStatus.serving,
    OrderStatus.completed,
  ];

  /// Tải mới đơn khi mở màn để thấy trạng thái bếp/phục vụ mới nhất.
  @override
  Widget build(BuildContext context) =>
      LiveData(sources: const {LiveSource.orders}, builder: (context, _) => _buildContent(context));

  Widget _buildContent(BuildContext context) {
    final order = MockData.findOrder(orderId);
    if (order == null) {
      return const Scaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Không tìm thấy đơn hàng',
            message: 'Đơn này có thể đã bị xóa hoặc chưa được tải về',
          ),
        ),
      );
    }
    final currentStepIndex = order.status == OrderStatus.cancelled ? -1 : _steps.indexOf(order.status);
    final visual = orderStatusVisual(order.status);
    final itemCount = order.items.fold(0, (sum, i) => sum + i.quantity);

    var index = 0;
    Widget step(Widget child) => FadeSlideIn.staggered(index: index++, child: child);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            step(AppPageHeader(
              title: 'Đơn #${order.displayCode}',
              subtitle: AppFormatters.dateTime(order.createdAt),
              trailing:
                  StatusBadge(label: order.status.label, color: visual.color, background: visual.background),
            )),
            const SizedBox(height: 20),
            step(order.status == OrderStatus.cancelled
                ? _buildCancelledBanner()
                : _buildTimeline(currentStepIndex)),
            const SizedBox(height: 22),
            step(Text('Danh sách món',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary))),
            const SizedBox(height: 12),
            for (final item in order.items)
              step(Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: switch (_findFood(item.foodId)) {
                        final Food food => FoodImage(food: food, borderRadius: 14, iconSize: 22),
                        null => Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.foodName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text('${item.quantity} x ${AppFormatters.currency(item.unitPrice)}',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(AppFormatters.currency(item.total),
                        style: TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  ],
                ),
              )),
            const SizedBox(height: 4),
            step(Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  LabeledValueRow(
                    label: 'Tạm tính ($itemCount món)',
                    value: AppFormatters.currency(order.subtotal),
                  ),
                  LabeledValueRow(
                    label: 'Thanh toán',
                    value: order.paymentStatus == PaymentStatus.paid ? 'Đã thanh toán' : 'Chưa thanh toán',
                    valueColor:
                        order.paymentStatus == PaymentStatus.paid ? AppColors.success : AppColors.textPrimary,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1, color: AppColors.border),
                  ),
                  Row(
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
                              AppFormatters.currency(order.subtotal),
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
                ],
              ),
            )),
            // Chỉ cho đặt lại đơn đã kết thúc; đơn đang làm thì không cần.
            if (order.status == OrderStatus.completed || order.status == OrderStatus.cancelled) ...[
              const SizedBox(height: 18),
              step(AppButton(
                label: 'Đặt lại đơn này',
                icon: Icons.replay_rounded,
                onPressed: () => _reorder(context, order),
              )),
            ],
          ],
        ),
      ),
    );
  }

  /// Đưa món của đơn cũ vào danh sách món đặt trước rồi mở thẳng tab Đặt bàn
  /// (khách đã chọn xong món, không cần qua Thực đơn). Bước "Đặt món trước"
  /// phía sau dùng chung giỏ này nên khách vẫn sửa/thêm món được.
  Future<void> _reorder(BuildContext context, Order order) async {
    // Lấy messenger của app trước khi đổi màn để SnackBar vẫn hiện ở màn mới.
    final messenger = ScaffoldMessenger.of(context);
    final result = _buildReorderItems(order);

    if (result.items.isEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Các món trong đơn hiện không còn bán')));
      return;
    }

    final cart = AppCart.customer;
    if (!cart.isEmpty) {
      final replace = await _askReplaceOrAppend(context, cart.totalQuantity);
      if (replace == null || !context.mounted) return;
      if (replace) cart.clear();
    }
    for (final item in result.items) {
      cart.addItem(item);
    }

    final added = result.items.fold(0, (sum, i) => sum + i.quantity);
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.customerHome,
      (route) => false,
      arguments: CustomerTab.booking,
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(result.skipped == 0
            ? 'Đã thêm $added món · Chọn bàn để hoàn tất'
            : 'Đã thêm $added món · ${result.skipped} món không còn bán nên đã bỏ qua'),
      ));
  }

  Widget _buildCancelledBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Icon(Icons.cancel_outlined, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Đơn hàng đã bị hủy',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(int currentStepIndex) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: List.generate(_steps.length, (index) {
          return _TimelineStep(
            label: _steps[index].label,
            done: index <= currentStepIndex,
            lineFilled: index < currentStepIndex,
            isLast: index == _steps.length - 1,
            isCurrent: index == currentStepIndex,
          );
        }),
      ),
    );
  }
}

/// Một mốc trong timeline trạng thái đơn.
class _TimelineStep extends StatelessWidget {
  final String label;
  final bool done;
  final bool lineFilled;
  final bool isLast;
  final bool isCurrent;

  const _TimelineStep({
    required this.label,
    required this.done,
    required this.lineFilled,
    required this.isLast,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: done ? 0.4 : 1, end: 1),
                duration: AppMotion.slow,
                curve: AppMotion.emphasized,
                builder: (context, value, child) => Transform.scale(scale: value, child: child),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    // Mốc chưa tới để nền trắng cho nổi trên khối nền kem.
                    color: done ? AppColors.primary : AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: done ? AppColors.primary : AppColors.border, width: 2),
                  ),
                  child: done ? Icon(Icons.check_rounded, size: 14, color: AppColors.textOnPrimary) : null,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: lineFilled ? 1.0 : 0.0),
                    duration: AppMotion.slow,
                    curve: Curves.easeOut,
                    builder: (context, value, _) => Container(
                      width: 2.5,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        // Phần đã qua tô màu vàng, phần còn lại màu viền nhạt.
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.primary, AppColors.border],
                          stops: [value, value],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24, top: 2),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: done ? FontWeight.w800 : FontWeight.w500,
                        fontSize: 14.5,
                        color: done ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (isCurrent) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Hiện tại',
                          style: TextStyle(
                              fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.primaryOnInk)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
