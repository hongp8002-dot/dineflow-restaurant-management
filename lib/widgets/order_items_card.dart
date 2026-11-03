import 'package:flutter/material.dart';

import '../models/order_item.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';

/// Khung trắng liệt kê các món của một đơn, mỗi dòng: ô số lượng "2×" - tên
/// món - thành tiền, ngăn bằng đường kẻ mảnh. Dùng ở Chi tiết bàn (Nhân viên
/// Order) và Thanh toán (Thu ngân).
class OrderItemsCard extends StatelessWidget {
  final List<OrderItem> items;

  /// Nền ô số lượng: kem (Chi tiết bàn) hoặc vàng nhạt (Thanh toán) theo mockup.
  /// null = [AppColors.surfaceAlt] (màu đọc theo bảng màu đang dùng nên không đặt mặc định được).
  final Color? quantityColor;

  const OrderItemsCard({super.key, required this.items, this.quantityColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 16, 11),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: quantityColor ?? AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text('${items[i].quantity}×',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(items[i].foodName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                  ),
                  const SizedBox(width: 8),
                  Text(AppFormatters.currency(items[i].total),
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
