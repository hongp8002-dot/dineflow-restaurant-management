import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/mock_data.dart';
import '../../models/promotion.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';

/// Màn "Ví voucher": khách xem các mã khuyến mãi của nhà hàng, chia theo trạng
/// thái và sao chép mã để đọc cho thu ngân khi thanh toán.
///
/// Dữ liệu lấy từ [MockData.promotions] (cùng nguồn với màn Khuyến mãi của
/// Admin và màn Thanh toán của Thu ngân). Chỉ hiển thị những gì model đang có
/// (tên, mã, % giảm, ngày bắt đầu/kết thúc, trạng thái).
class VoucherWalletScreen extends StatefulWidget {
  const VoucherWalletScreen({super.key});

  @override
  State<VoucherWalletScreen> createState() => _VoucherWalletScreenState();
}

class _VoucherWalletScreenState extends State<VoucherWalletScreen> {
  PromotionStatus _tab = PromotionStatus.active;

  static const _tabs = [PromotionStatus.active, PromotionStatus.upcoming, PromotionStatus.expired];

  List<Promotion> _byStatus(PromotionStatus status) =>
      MockData.promotions.where((p) => p.status == status).toList();

  Future<void> _copy(Promotion promo) async {
    await Clipboard.setData(ClipboardData(text: promo.code));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Đã sao chép mã ${promo.code}')));
  }

  @override
  Widget build(BuildContext context) {
    final vouchers = _byStatus(_tab);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: const AppPageHeader(
                title: 'Ví voucher',
                subtitle: 'Đọc mã cho thu ngân khi thanh toán',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _tabs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final status = _tabs[i];
                  return _TabChip(
                    label: status.label,
                    count: _byStatus(status).length,
                    selected: _tab == status,
                    onTap: () => setState(() => _tab = status),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: AnimatedSwitcher(
                duration: AppMotion.normal,
                child: vouchers.isEmpty
                    ? EmptyState(
                        key: ValueKey('empty-${_tab.name}'),
                        icon: Icons.confirmation_number_outlined,
                        title: switch (_tab) {
                          PromotionStatus.active => 'Chưa có voucher đang áp dụng',
                          PromotionStatus.upcoming => 'Chưa có voucher sắp diễn ra',
                          PromotionStatus.expired => 'Không có voucher đã hết hạn',
                        },
                      )
                    : ListView.separated(
                        key: ValueKey('list-${_tab.name}'),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        itemCount: vouchers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => FadeSlideIn.staggered(
                          index: i,
                          child: _VoucherTicket(
                            promotion: vouchers[i],
                            onCopy: vouchers[i].status == PromotionStatus.expired
                                ? null
                                : () => _copy(vouchers[i]),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip chọn nhóm trạng thái, kèm số lượng voucher trong nhóm.
class _TabChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({required this.label, required this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      scale: 0.95,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primaryOnInk : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Thẻ voucher kiểu "vé": khối % giảm bên trái, đường cắt răng cưa ở giữa,
/// thông tin + mã + nút sao chép bên phải.
class _VoucherTicket extends StatelessWidget {
  final Promotion promotion;

  /// null = không cho sao chép (voucher đã hết hạn).
  final VoidCallback? onCopy;

  const _VoucherTicket({required this.promotion, required this.onCopy});

  ({Color color, Color background}) get _visual => switch (promotion.status) {
        PromotionStatus.active => (color: AppColors.success, background: AppColors.successBg),
        PromotionStatus.upcoming => (color: AppColors.info, background: AppColors.infoBg),
        PromotionStatus.expired => (color: AppColors.textSecondary, background: AppColors.surfaceAlt),
      };

  @override
  Widget build(BuildContext context) {
    final expired = promotion.status == PromotionStatus.expired;
    final visual = _visual;

    return Opacity(
      opacity: expired ? 0.6 : 1,
      child: ClipPath(
        clipper: const _TicketClipper(notchX: 92, notchRadius: 9),
        child: Container(
          color: AppColors.surfaceAlt,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Khối % giảm.
                Container(
                  width: 92,
                  color: expired ? AppColors.border : AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('GIẢM',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: AppColors.textOnPrimary)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('${promotion.percent}%',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                                color: AppColors.textOnPrimary)),
                      ),
                    ],
                  ),
                ),
                // Thông tin voucher.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(promotion.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary)),
                            ),
                            const SizedBox(width: 8),
                            StatusBadge(
                                label: promotion.status.label,
                                color: visual.color,
                                background: visual.background),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${AppFormatters.date(promotion.startDate)} – ${AppFormatters.date(promotion.endDate)}',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  promotion.code,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            if (onCopy != null) ...[
                              const SizedBox(width: 8),
                              PressScale(
                                onTap: onCopy,
                                scale: 0.9,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.ink,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.copy_rounded, size: 14, color: AppColors.primaryOnInk),
                                      const SizedBox(width: 5),
                                      Text('Sao chép',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primaryOnInk)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cắt hai nửa hình tròn ở mép trên và mép dưới tại vị trí [notchX] để thẻ
/// trông như tấm vé xé được; bo góc 18 ở bốn góc.
class _TicketClipper extends CustomClipper<Path> {
  final double notchX;
  final double notchRadius;

  const _TicketClipper({required this.notchX, required this.notchRadius});

  @override
  Path getClip(Size size) {
    final card = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)));
    final notches = Path()
      ..addOval(Rect.fromCircle(center: Offset(notchX, 0), radius: notchRadius))
      ..addOval(Rect.fromCircle(center: Offset(notchX, size.height), radius: notchRadius));
    return Path.combine(PathOperation.difference, card, notches);
  }

  @override
  bool shouldReclip(covariant _TicketClipper oldClipper) =>
      oldClipper.notchX != notchX || oldClipper.notchRadius != notchRadius;
}
