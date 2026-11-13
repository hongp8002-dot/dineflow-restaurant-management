import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/api/api_exception.dart';
import '../../data/app_data.dart';
import '../../data/invoice_repository.dart';
import '../../data/loyalty_rules.dart';
//import '../../data/member_repository.dart';
import '../../data/mock_data.dart';
import '../../data/order_staff_repository.dart';
import '../../data/settings_repository.dart';
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

// Tài khoản nhận chuyển khoản lấy từ server (GET /api/settings → config/restaurant.php),
// không viết cứng trong app. Xem SettingsRepository.

/// Màn hình thanh toán – Quy tắc Kiểu A:
///
/// - Không dùng điểm để trừ tiền.
/// - Giảm = max(giảm theo hạng, giảm theo voucher). Không cộng dồn.
/// - Thu ngân có thể gắn khách thành viên bằng QR hoặc nhập mã để áp giảm hạng.
/// - Server tính lại và cộng điểm khi xác nhận.
/// - Thu ngân có thể Huỷ đơn (chỉ đơn chưa thanh toán).
/// - Tiền cọc (đặt bàn kèm món trước) được hiển thị và khấu trừ vào tổng cuối.
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
    // Không gán thẳng vào `Customer?`: Dart sẽ hiểu là pushNamed<Customer?> và đòi route kiểu
    // Route<Customer?>, trong khi routes.dart tạo MaterialPageRoute<dynamic> → lỗi ép kiểu,
    // bấm vào ô không mở được màn quét. Nhận Object? rồi kiểm tra kiểu.
    final result = await Navigator.of(context).pushNamed(AppRoutes.cashierScanMember);
    final customer = result is Customer ? result : null;
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
        memberCode: _member?.memberCode,
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

  /// Huỷ đơn — chỉ thu ngân, chỉ đơn chưa thanh toán, bắt buộc chọn lý do (nhóm chốt 13/11).
  Future<void> _cancel(Order order) async {
    if (_cancelling) return;

    final choice = await showDialog<({String reason, String note})>(
      context: context,
      builder: (ctx) => _CancelReasonDialog(orderCode: order.displayCode),
    );
    if (choice == null || !mounted) return;

    setState(() => _cancelling = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await OrderStaffRepository.instance.cancelOrder(order.id, reason: choice.reason, note: choice.note);
      unawaited(AppData.refresh({LiveSource.orders, LiveSource.tables}, force: true));
      navigator.pop();
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

    final applicablePromotions = _promotions.where((p) => p.appliesTo(subtotal)).toList();
    final promotion = applicablePromotions.any((p) => p.id == _promotion?.id) ? _promotion : null;

    final member = _member;
    double tierDiscount = 0;
    int tierPercent = 0;
    if (member != null) {
      tierPercent = LoyaltyRules.tierFor(member.points).discountPercent;
      tierDiscount = subtotal * tierPercent / 100;
    }

    final promoDiscount = promotion?.discountFor(subtotal) ?? 0.0;
    final discount = (tierDiscount > promoDiscount) ? tierDiscount : promoDiscount;
    final usingTierDiscount = tierDiscount > promoDiscount && tierDiscount > 0;

    final depositAmount = order.depositAmount;
    // clamp(0.0, ...) thay vì clamp(0, ...) để Dart suy ra kiểu double thay vì num.
    final total = (subtotal - discount - depositAmount).clamp(0.0, double.infinity);

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
                      if (depositAmount > 0)
                        LabeledValueRow(
                          label: 'Đã cọc (đặt bàn)',
                          value: '-${AppFormatters.currency(depositAmount)}',
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
                const SizedBox(height: 14),

                // ── Panel QR hoặc Thẻ (hiện khi chọn tương ứng) ─────────
                if (_method == PaymentMethod.qr)
                  appear(_CashierQrPanel(amount: total, orderCode: order.displayCode)),
                if (_method == PaymentMethod.card)
                  appear(const _CardPaymentPanel()),
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
              'Quét QR hoặc nhập mã thành viên',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel QR chuyển khoản (Thu ngân)
// ─────────────────────────────────────────────────────────────────────────────

class _CashierQrPanel extends StatelessWidget {
  final double amount;
  final String orderCode;

  const _CashierQrPanel({required this.amount, required this.orderCode});

  @override
  Widget build(BuildContext context) {
    final bank = SettingsRepository.instance.bank;
    if (bank == null) {
      return const EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Chưa tải được thông tin chuyển khoản',
        message: 'Đăng nhập lại để tải tài khoản ngân hàng của nhà hàng, hoặc chọn thu tiền mặt / thẻ.',
      );
    }
    final noteText = 'Thanh toan $orderCode DineFlow';
    final qrUrl = bank.qrImageUrl(amount, noteText);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(children: [
            Icon(Icons.account_balance_rounded, size: 18, color: AppColors.textPrimary),
            const SizedBox(width: 8),
            Text(
              'Khách quét QR thanh toán',
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
            ),
          ]),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12, blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Image.network(
                qrUrl,
                width: 200,
                height: 200,
                fit: BoxFit.contain,
                loadingBuilder: (ctx, child, prog) {
                  if (prog == null) return child;
                  return const SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                },
                errorBuilder: (ctx, _, __) => Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_2_rounded,
                          size: 72, color: AppColors.textSecondary),
                      const SizedBox(height: 8),
                      Text('Không tải được QR',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _InfoRowQ(label: 'Ngân hàng', value: bank.name),
          const SizedBox(height: 8),
          _InfoRowQ(label: 'Số TK', value: bank.accountNo),
          const SizedBox(height: 8),
          _InfoRowQ(label: 'Chủ TK', value: bank.accountName),
          const SizedBox(height: 8),
          _InfoRowQ(
              label: 'Số tiền',
              value: AppFormatters.currency(amount),
              highlight: true),
          const SizedBox(height: 8),
          _InfoRowQ(label: 'Nội dung', value: noteText),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Yêu cầu khách quét mã QR bằng app ngân hàng. '
                  'Nhập đúng nội dung chuyển khoản để hệ thống xác nhận.',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textPrimary, height: 1.4),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _InfoRowQ extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _InfoRowQ(
      {required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(label,
              style:
                  TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  highlight ? FontWeight.w800 : FontWeight.w600,
              color: highlight
                  ? AppColors.primary
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel hướng dẫn thanh toán thẻ (POS)
// ─────────────────────────────────────────────────────────────────────────────

class _CardPaymentPanel extends StatelessWidget {
  const _CardPaymentPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.credit_card_rounded,
                size: 18, color: AppColors.textPrimary),
            const SizedBox(width: 8),
            Text(
              'Thanh toán qua máy POS',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.textPrimary),
            ),
          ]),
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 230,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 16,
                      offset: const Offset(0, 6)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('POS Terminal',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                      const Icon(Icons.wifi_rounded,
                          color: Colors.white54, size: 15),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    height: 40,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.nfc_rounded,
                            color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('CHẠM / CÀ THẺ',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _CardBadge('VISA'),
                      const SizedBox(width: 6),
                      _CardBadge('MC'),
                      const SizedBox(width: 6),
                      _CardBadge('JCB'),
                      const SizedBox(width: 6),
                      _CardBadge('NAPAS'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _PosStep(
            icon: Icons.looks_one_rounded,
            text:
                'Yêu cầu khách đưa thẻ hoặc điện thoại (Apple Pay / Google Pay)',
          ),
          const SizedBox(height: 10),
          _PosStep(
            icon: Icons.looks_two_rounded,
            text: 'Chạm thẻ hoặc cà thẻ vào máy POS',
          ),
          const SizedBox(height: 10),
          _PosStep(
            icon: Icons.looks_3_rounded,
            text: 'Khách nhập PIN nếu được yêu cầu',
          ),
          const SizedBox(height: 10),
          _PosStep(
            icon: Icons.looks_4_rounded,
            text:
                'Chờ máy in biên lai, sau đó nhấn "Xác nhận thanh toán"',
          ),
        ],
      ),
    );
  }
}

class _CardBadge extends StatelessWidget {
  final String label;
  const _CardBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5)),
    );
  }
}

class _PosStep extends StatelessWidget {
  final IconData icon;
  final String text;
  const _PosStep({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  height: 1.4)),
        ),
      ],
    );
  }
}

/// Viên lựa chọn voucher.
class _ChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoicePill(
      {required this.label, required this.selected, required this.onTap});

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
              color:
                  selected ? AppColors.textOnDark : AppColors.textPrimary,
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

  const _MethodTile(
      {required this.method, required this.selected, required this.onTap});

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
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: fg)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hộp thoại hủy đơn: chọn lý do (Nhập nhầm / Khách bỏ về / Hết món / Khác) + ghi chú.
/// "Khác" bắt buộc ghi chú. Trả về lựa chọn, hoặc null nếu không hủy.
class _CancelReasonDialog extends StatefulWidget {
  final String orderCode;

  const _CancelReasonDialog({required this.orderCode});

  @override
  State<_CancelReasonDialog> createState() => _CancelReasonDialogState();
}

class _CancelReasonDialogState extends State<_CancelReasonDialog> {
  String? _reason;
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _valid => _reason != null && (_reason != 'other' || _noteCtrl.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Huỷ đơn #${widget.orderCode}?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chọn lý do huỷ (bắt buộc). Hành động này không thể hoàn tác.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            for (final entry in OrderStaffRepository.cancelReasons.entries)
              RadioListTile<String>(
                value: entry.key,
                groupValue: _reason,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(entry.value),
                onChanged: (v) => setState(() => _reason = v),
              ),
            TextField(
              controller: _noteCtrl,
              maxLength: 255,
              maxLines: 2,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: _reason == 'other' ? 'Ghi rõ lý do (bắt buộc)' : 'Ghi chú thêm (không bắt buộc)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Không')),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          onPressed: _valid ? () => Navigator.of(context).pop((reason: _reason!, note: _noteCtrl.text.trim())) : null,
          child: const Text('Huỷ đơn'),
        ),
      ],
    );
  }
}
