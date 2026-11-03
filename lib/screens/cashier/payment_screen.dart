import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/api/api_exception.dart';
import '../../data/app_data.dart';
import '../../data/invoice_repository.dart';
import '../../data/loyalty_rules.dart';
import '../../data/mock_data.dart';
import '../../data/order_staff_repository.dart';
import '../../models/customer.dart';
import '../../models/invoice.dart';
import '../../models/order.dart';
import '../../models/promotion.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_header_band.dart';
import '../../widgets/dashed_divider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/invoice_card.dart';
import '../../widgets/labeled_value_row.dart';
import '../../widgets/live_data.dart';
import '../../widgets/order_items_card.dart';

/// Màn hình thanh toán – Quy tắc Kiểu A:
///
/// - Không dùng điểm để trừ tiền.
/// - Giảm = max(giảm theo hạng, giảm theo voucher). Không cộng dồn.
/// - Thu ngân có thể gắn khách thành viên bằng QR hoặc nhập mã để áp giảm hạng.
/// - Server tính lại và cộng điểm khi xác nhận.
/// - Thu ngân có thể Huỷ đơn (chỉ đơn chưa thanh toán).
class PaymentScreen extends StatefulWidget {
  final String orderId;
  const PaymentScreen({super.key, required this.orderId});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  Promotion? _promotion;
  PaymentMethod _method = PaymentMethod.cash;
  bool _paying = false;
  bool _cancelling = false;

  /// Khách thành viên được gắn vào đơn (sau khi quét QR hoặc đặt qua app).
  Customer? _member;

  /// Danh sách khuyến mãi đang hoạt động — tải từ API thật khi màn hình mở.
  List<Promotion> _promotions = [];
  bool _loadingPromotions = true;

  static TextStyle get _sectionStyle =>
      TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPromotions());
  }

  /// Tải khuyến mãi đang hoạt động từ API thật.
  Future<void> _loadPromotions() async {
    try {
      final list = await OrderStaffRepository.instance.fetchActivePromotions();
      if (mounted) setState(() => _promotions = list);
    } catch (_) {
      // Lỗi tải khuyến mãi không chặn thanh toán — dùng danh sách rỗng.
    } finally {
      if (mounted) setState(() => _loadingPromotions = false);
    }
  }

  /// Gắn khách thành viên vào phiên thanh toán.
  Future<void> _scanMember(Order order) async {
    final Customer? customer = await Navigator.of(context).pushNamed(AppRoutes.cashierScanMember);
    if (customer == null || !mounted) return;
    setState(() => _member = customer);
  }

  Future<void> _pay(Order order, {required Promotion? promotion}) async {
    if (_paying) return;
    setState(() => _paying = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final Invoice invoice = await InvoiceRepository.instance.pay(
        order.id,
        method: _method,
        promotionCode: promotion?.code,
      );
      unawaited(AppData.refresh({LiveSource.orders, LiveSource.tables, LiveSource.invoices}, force: true));
      navigator.pushReplacementNamed(AppRoutes.cashierInvoice, arguments: invoice);
    } on ApiException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
      unawaited(AppData.refresh({LiveSource.orders}, force: true));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  /// Huỷ đơn — chỉ thu ngân, chỉ đơn chưa thanh toán.
  Future<void> _cancel(Order order) async {
    if (_cancelling) return;

    // Hiện dialog xác nhận trước khi huỷ.
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Huỷ đơn hàng?'),
        content: Text(
          'Bạn có chắc muốn huỷ đơn #${order.displayCode}?\n'
          'Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Không'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Huỷ đơn'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _cancelling = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await OrderStaffRepository.instance.cancelOrder(order.id);
      unawaited(AppData.refresh({LiveSource.orders, LiveSource.tables}, force: true));
      navigator.pop(); // Quay lại màn hình trước
      messenger.showSnackBar(
        SnackBar(content: Text('Đã huỷ đơn #${order.displayCode}')),
      );
    } on ApiException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      LiveData(sources: const {LiveSource.orders}, builder: (context, _) => _buildContent(context));

  Widget _buildContent(BuildContext context) {
    final order = MockData.findOrder(widget.orderId);
    if (order == null) {
      return const Scaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Không tìm thấy đơn hàng',
            message: 'Đơn này có thể đã được thanh toán hoặc bị hủy',
          ),
        ),
      );
    }

    final subtotal = order.subtotal;

    // Lọc khuyến mãi phù hợp với giá trị đơn hiện tại từ danh sách tải từ API.
    final applicablePromotions = _promotions.where((p) => p.appliesTo(subtotal)).toList();
    final promotion = applicablePromotions.any((p) => p.id == _promotion?.id) ? _promotion : null;

    // Tính giảm theo hạng (dựa trên điểm khách biết được ở app)
    final member = _member;
    double tierDiscount = 0;
    int tierPercent = 0;
    if (member != null) {
      tierPercent = LoyaltyRules.tierFor(member.points).discountPercent;
      tierDiscount = subtotal * tierPercent / 100;
    }

    final promoDiscount = promotion?.discountFor(subtotal) ?? 0.0;

    // Hiển thị mức giảm cao hơn (server sẽ xác nhận lại)
    final discount = (tierDiscount > promoDiscount) ? tierDiscount : promoDiscount;
    final usingTierDiscount = tierDiscount > promoDiscount && tierDiscount > 0;
    final total = (subtotal - discount).clamp(0, double.infinity);

    // Nếu hạng thắng, không gửi promotion_code lên server
    final effectivePromotion = usingTierDiscount ? null : promotion;

    var step = 0;
    Widget appear(Widget child) => FadeSlideIn.staggered(index: step++, child: child);

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      body: Column(
        children: [
          AppHeaderBand(
            title: order.tableNumber != null ? 'Thanh toán · ${order.tableNumber}' : 'Thanh toán',
            subtitle: 'Đơn #${order.displayCode} · ${order.items.length} món',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              children: [
                appear(OrderItemsCard(items: order.items, quantityColor: AppColors.primaryLight)),
                const SizedBox(height: 18),

                // ── Thành viên ───────────────────────────────────────────
                appear(Text('Thành viên', style: _sectionStyle)),
                const SizedBox(height: 10),
                appear(_buildMemberSection(order, member)),
                const SizedBox(height: 18),

                // ── Voucher ──────────────────────────────────────────────
                appear(Text('Voucher', style: _sectionStyle)),
                const SizedBox(height: 10),
                if (_loadingPromotions)
                  appear(const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ))
                else
                  appear(Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ChoicePill(
                        label: 'Không dùng',
                        selected: _promotion == null,
                        onTap: () => setState(() => _promotion = null),
                      ),
                      for (final p in applicablePromotions)
                        _ChoicePill(
                          label: '${p.code} · -${p.percent}%',
                          selected: promotion?.id == p.id,
                          onTap: () => setState(() => _promotion = p),
                        ),
                      if (applicablePromotions.isEmpty && !_loadingPromotions)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Không có voucher áp dụng được cho đơn này',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ),
                    ],
                  )),
                const SizedBox(height: 18),

                // ── Tổng tiền ────────────────────────────────────────────
                appear(Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      LabeledValueRow(
                        label: 'Tạm tính',
                        value: AppFormatters.currency(subtotal),
                        animateValue: true,
                      ),
                      if (discount > 0)
                        LabeledValueRow(
                          label: usingTierDiscount
                              ? 'Giảm hạng ${LoyaltyRules.tierFor(member!.points).label} ($tierPercent%)'
                              : 'Giảm giá (${promotion?.code})',
                          value: '-${AppFormatters.currency(discount)}',
                          animateValue: true,
                        ),
                      const SizedBox(height: 8),
                      const DashedDivider(),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text('Tổng tiền',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: AppColors.textPrimary)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: AnimatedValueText(
                                  AppFormatters.currency(total),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 28,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (member != null && total > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(Icons.stars_rounded, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                'Khách được +${LoyaltyRules.pointsEarned(total)} điểm',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                )),
                const SizedBox(height: 18),

                // ── Phương thức thanh toán ───────────────────────────────
                appear(Text('Phương thức thanh toán', style: _sectionStyle)),
                const SizedBox(height: 10),
                appear(Row(
                  children: [
                    for (final method in PaymentMethod.values) ...[
                      if (method != PaymentMethod.values.first) const SizedBox(width: 8),
                      Expanded(
                        child: _MethodTile(
                          method: method,
                          selected: _method == method,
                          onTap: () => setState(() => _method = method),
                        ),
                      ),
                    ],
                  ],
                )),
                const SizedBox(height: 24),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  AppButton(
                    label: 'Xác nhận thanh toán',
                    isLoading: _paying,
                    onPressed: _cancelling ? null : () => _pay(order, promotion: effectivePromotion),
                  ),
                  const SizedBox(height: 10),
                  // Nút huỷ đơn — chỉ khi chưa thanh toán (nghĩa là đơn đang ở màn hình này).
                  AppButton(
                    label: 'Huỷ đơn',
                    icon: Icons.cancel_outlined,
                    variant: AppButtonVariant.outlined,
                    dense: true,
                    isLoading: _cancelling,
                    onPressed: _paying ? null : () => _cancel(order),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Thẻ thành viên: hiển thị nếu đã quét, hoặc nút "Quét QR".
  Widget _buildMemberSection(Order order, Customer? member) {
    if (member != null) {
      final tier = LoyaltyRules.tierFor(member.points);
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
              child: Icon(Icons.badge_outlined, color: AppColors.textPrimary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.name,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    '${tier.label} · ${member.points} điểm · ${member.memberCode}',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            PressScale(
              onTap: () => setState(() => _member = null),
              scale: 0.9,
              child: Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    // Chưa gắn khách
    return PressScale(
      onTap: () => _scanMember(order),
      scale: 0.97,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: AppColors.textPrimary, size: 20),
            const SizedBox(width: 10),
            Text(
              'Quét QR để áp dụng giảm giá thành viên',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Viên lựa chọn voucher.
class _ChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoicePill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: PressScale(
        onTap: onTap,
        scale: 0.94,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : AppColors.surface,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.textOnDark : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Ô phương thức thanh toán.
class _MethodTile extends StatelessWidget {
  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  const _MethodTile({required this.method, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.textOnDark : AppColors.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      child: PressScale(
        onTap: onTap,
        scale: 0.95,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: Curves.easeOut,
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(paymentMethodIcon(method), size: 21, color: fg),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(method.label,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: fg)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
