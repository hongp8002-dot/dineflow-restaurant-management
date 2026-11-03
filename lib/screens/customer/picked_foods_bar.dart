import 'package:flutter/material.dart';

import '../../data/cart_store.dart';
import '../../data/mock_data.dart';
import '../../models/order_item.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_button.dart';
import '../../widgets/food_image.dart';
import '../../widgets/quantity_stepper.dart';

/// Thanh "món đã chọn" nằm ngay trên thanh điều hướng ở Trang chủ và Thực đơn.
///
/// Khách chỉ gọi món qua app bằng cách **đặt món trước khi đặt bàn** (gọi món
/// tại quán do Nhân viên Order nhập), nên thanh này không gửi đơn đi đâu cả:
/// chạm bên trái để xem/sửa các món đã chọn, nút bên phải mở tab Đặt bàn và các
/// món sẽ có sẵn ở bước "Đặt món trước".
class PickedFoodsBar extends StatelessWidget {
  final CartStore picks;
  final VoidCallback onBook;

  const PickedFoodsBar({super.key, required this.picks, required this.onBook});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(18)),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Expanded(
                child: PressScale(
                  key: const ValueKey('picked-foods-open'),
                  onTap: () => showPickedFoodsSheet(context, picks: picks, onBook: onBook),
                  scale: 0.97,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${picks.totalQuantity} món đã chọn',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12.5, color: AppColors.textOnDark.withValues(alpha: 0.75)),
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_up_rounded,
                              size: 18, color: AppColors.textOnDark.withValues(alpha: 0.75)),
                        ],
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: AnimatedValueText(
                          AppFormatters.currency(picks.subtotal),
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textOnDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Nút chiếm tối đa hơn nửa thanh; máy hẹp thì chữ tự thu nhỏ thay vì tràn.
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.55),
                child: PressScale(
                  key: const ValueKey('picked-foods-book'),
                  onTap: onBook,
                  scale: 0.95,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration:
                        BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(13)),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Đặt bàn để gọi',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textOnPrimary)),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.textOnPrimary),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bảng xem/sửa các món đã chọn trước khi đặt bàn.
Future<void> showPickedFoodsSheet(
  BuildContext context, {
  required CartStore picks,
  required VoidCallback onBook,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      // ListenableBuilder: đổi số lượng là danh sách và tạm tính cập nhật ngay trong sheet.
      return ListenableBuilder(
        listenable: picks,
        builder: (context, _) {
          final items = picks.items;
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Món đã chọn', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, size: 18, color: AppColors.textPrimary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Món được gửi cho nhà hàng khi bạn đặt bàn và thanh toán. '
                              'Đang ngồi ở quán? Hãy gọi món với nhân viên.',
                              style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text('Chưa chọn món nào', style: TextStyle(color: AppColors.textSecondary)),
                      )
                    else
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final item in items)
                              _PickedLine(
                                key: ValueKey(item.id),
                                item: item,
                                onQuantityChanged: (q) => picks.updateQuantity(item.id, q),
                              ),
                          ],
                        ),
                      ),
                    Divider(height: 20, color: AppColors.border),
                    Row(
                      children: [
                        Text('Tạm tính', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: AnimatedValueText(
                              AppFormatters.currency(picks.subtotal),
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    AppButton(
                      label: 'Đặt bàn để gọi món',
                      onPressed: items.isEmpty
                          ? null
                          : () {
                              Navigator.of(sheetContext).pop();
                              onBook();
                            },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// Một dòng món đã chọn: ảnh, tên, tuỳ chọn/ghi chú, thành tiền và bộ tăng/giảm.
class _PickedLine extends StatelessWidget {
  final OrderItem item;
  final ValueChanged<int> onQuantityChanged;

  const _PickedLine({super.key, required this.item, required this.onQuantityChanged});

  @override
  Widget build(BuildContext context) {
    final detail = [
      if (item.optionsLabel.isNotEmpty) item.optionsLabel,
      if (item.note.isNotEmpty) item.note,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: FoodImage(food: MockData.foodById(item.foodId), borderRadius: 12, iconSize: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.foodName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppColors.textPrimary)),
                if (detail.isNotEmpty)
                  Text(detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                AnimatedValueText(
                  AppFormatters.currency(item.total),
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // min 0: giảm tiếp khi còn 1 sẽ bỏ món khỏi danh sách.
          QuantityStepper(value: item.quantity, min: 0, onChanged: onQuantityChanged),
        ],
      ),
    );
  }
}
