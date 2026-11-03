import 'package:flutter/material.dart';

import '../models/invoice.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import 'app_animations.dart';

/// Icon tương ứng phương thức thanh toán (tiền mặt / QR / thẻ).
IconData paymentMethodIcon(PaymentMethod method) {
  switch (method) {
    case PaymentMethod.cash:
      return Icons.payments_outlined;
    case PaymentMethod.qr:
      return Icons.qr_code_2_rounded;
    case PaymentMethod.card:
      return Icons.credit_card_rounded;
  }
}

/// Card tóm tắt hóa đơn trong Lịch sử thanh toán (Thu ngân), theo mockup:
/// ô icon phương thức - mã hoá đơn · bàn - giờ · ngày · phương thức - tổng tiền.
class InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback? onTap;

  const InvoiceCard({super.key, required this.invoice, this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      scale: 0.98,
      child: Container(
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
              child: Icon(paymentMethodIcon(invoice.paymentMethod), color: AppColors.textPrimary, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('#${invoice.displayCode} · ${invoice.tableNumber ?? 'Đặt qua app'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14.5, color: AppColors.textPrimary)),
                  const SizedBox(height: 3),
                  Text(
                    '${AppFormatters.timeDate(invoice.createdAt)} · ${invoice.paymentMethod.label}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(AppFormatters.currency(invoice.total),
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
