import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_exception.dart';
import '../../models/invoice.dart';
import '../../models/shift.dart';
import '../../data/shift_repository.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_header_band.dart';
import '../../widgets/status_badge.dart';

/// Icon tương ứng với từng phương thức thanh toán.
IconData paymentMethodIcon(PaymentMethod method) => switch (method) {
  PaymentMethod.cash => Icons.payments_rounded,
  PaymentMethod.qr   => Icons.qr_code_rounded,
  PaymentMethod.card => Icons.credit_card_rounded,
};

/// Tab Ca làm: thông tin ca hiện tại, doanh thu theo phương thức, mở/đóng ca.
///
/// Lấy dữ liệu thật từ `ShiftRepository`. Nếu chưa mở ca → hiện nút Mở ca.
class ShiftScreen extends StatefulWidget {
  const ShiftScreen({super.key});

  @override
  State<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends State<ShiftScreen> {
  Shift? _shift;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadShift();
  }

  Future<void> _loadShift() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final shift = await ShiftRepository.instance.fetchCurrent();
      if (mounted) setState(() => _shift = shift);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Không tải được thông tin ca làm. Thử lại sau.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Mở ca ────────────────────────────────────────────────────────────────

  Future<void> _openShiftDialog() async {
    final controller = TextEditingController(text: '0');
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Mở ca làm việc'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nhập số tiền mặt đầu ca (đồng):'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: '0',
                prefixText: 'đ  ',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mở ca')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final cash = double.tryParse(controller.text) ?? 0;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final shift = await ShiftRepository.instance.openShift(openingCash: cash);
      if (!mounted) return;
      setState(() => _shift = shift);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Đã mở ca lúc ${AppFormatters.time(shift.openedAt)}')));
    } on ApiException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  // ── Đóng ca ──────────────────────────────────────────────────────────────

  Future<void> _closeShiftDialog(Shift shift) async {
    final controller = TextEditingController(text: '0');
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final counted = double.tryParse(controller.text) ?? 0;
          final diff = counted - shift.expectedCash;
          final diffStr = '${diff >= 0 ? "+" : ""}${AppFormatters.currency(diff.abs())}';
          final diffColor = diff.abs() < 1 ? AppColors.textSecondary : (diff > 0 ? AppColors.ink : AppColors.error);

          return AlertDialog(
            title: const Text('Đóng ca làm việc'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'Tiền mở ca', value: AppFormatters.currency(shift.openingCash)),
                _InfoRow(label: 'Doanh thu tiền mặt', value: AppFormatters.currency(shift.revenueByMethod.cash)),
                _InfoRow(label: 'Tiền mặt dự kiến', value: AppFormatters.currency(shift.expectedCash)),
                const SizedBox(height: 14),
                const Text('Nhập số tiền mặt đếm được:'),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: '0',
                    prefixText: 'đ  ',
                  ),
                  autofocus: true,
                  onChanged: (_) => setSt(() {}),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Chênh lệch: ', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      diff.abs() < 1 ? 'Khớp' : (diff > 0 ? '+$diffStr (thừa)' : '$diffStr (thiếu)'),
                      style: TextStyle(fontWeight: FontWeight.w700, color: diffColor),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Đóng ca', style: TextStyle(color: AppColors.error)),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed != true || !mounted) return;

    final counted = double.tryParse(controller.text) ?? 0;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final closed = await ShiftRepository.instance.closeShift(
        shiftId: shift.id,
        closingCashCounted: counted,
      );
      if (!mounted) return;
      setState(() => _shift = closed);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Đã đóng ca lúc ${AppFormatters.time(closed.closedAt!)}')));
    } on ApiException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  AppButton(label: 'Thử lại', onPressed: _loadShift),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final shift = _shift;
    if (shift == null || !shift.isOpen) return _buildNoShift();
    return _buildOpenShift(shift);
  }

  /// Chưa mở ca → chỉ hiện nút Mở ca.
  Widget _buildNoShift() {
    var i = 0;
    Widget appear(Widget w) => FadeSlideIn.staggered(index: i++, child: w);

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      body: Column(
        children: [
          const AppHeaderBand(caption: 'Thông tin ca hiện tại', title: 'Ca làm việc'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                appear(Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                        child: Icon(Icons.lock_clock_outlined, color: AppColors.textPrimary, size: 28),
                      ),
                      const SizedBox(height: 14),
                      Text('Chưa có ca đang mở',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      Text(
                        'Mở ca để bắt đầu nhận thanh toán.\nMỗi thu ngân chỉ có một ca mở tại một thời điểm.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.4),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: AppButton(
                label: 'Mở ca',
                icon: Icons.lock_open_rounded,
                onPressed: _openShiftDialog,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ca đang mở → hiện thông tin + doanh thu + nút Đóng ca.
  Widget _buildOpenShift(Shift shift) {
    final totalRevenue = shift.revenueByMethod.total;
    final byMethod = {
      PaymentMethod.cash: shift.revenueByMethod.cash,
      PaymentMethod.qr: shift.revenueByMethod.qr,
      PaymentMethod.card: shift.revenueByMethod.card,
    };

    var order = 0;
    Widget step(Widget child) => FadeSlideIn.staggered(index: order++, child: child);

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      body: Column(
        children: [
          const AppHeaderBand(caption: 'Thông tin ca hiện tại', title: 'Ca làm việc'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                // Thẻ thông tin ca
                step(Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const _IconTile(icon: Icons.badge_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(shift.cashierName,
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text(
                              'Bắt đầu: ${AppFormatters.time(shift.openedAt)} · '
                              'Tiền đầu ca: ${AppFormatters.currency(shift.openingCash)}',
                              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(label: 'Đang mở', color: AppColors.textOnDark, background: AppColors.ink),
                    ],
                  ),
                )),
                const SizedBox(height: 12),

                // Tổng thu ca này
                step(Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tổng thu ca này',
                                style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: CountUpText(
                                value: totalRevenue,
                                formatter: (v) => AppFormatters.currency(v.round()),
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: StatusBadge(
                          label: '${shift.invoiceCount} hóa đơn',
                          color: AppColors.textPrimary,
                          background: AppColors.surfaceAlt,
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 22),

                // Doanh thu theo phương thức
                step(Text('Doanh thu theo phương thức',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary))),
                const SizedBox(height: 10),
                step(Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      for (final method in PaymentMethod.values)
                        _MethodRow(
                          method: method,
                          value: byMethod[method]!,
                          share: totalRevenue == 0 ? 0 : byMethod[method]! / totalRevenue,
                        ),
                    ],
                  ),
                )),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: AppButton(
                label: 'Đóng ca',
                icon: Icons.lock_outline_rounded,
                onPressed: () => _closeShiftDialog(shift),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hàng thông tin nhỏ trong dialog đóng ca.
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final IconData icon;

  const _IconTile({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 21, color: AppColors.textPrimary),
    );
  }
}

/// Một dòng doanh thu theo phương thức: ô icon, nhãn, số tiền và thanh tỉ lệ.
class _MethodRow extends StatelessWidget {
  final PaymentMethod method;
  final double value;

  /// Tỉ lệ trên tổng thu, từ 0 tới 1.
  final double share;

  const _MethodRow({required this.method, required this.value, required this.share});

  static Color _barColor(PaymentMethod method) => switch (method) {
        PaymentMethod.cash => AppColors.ink,
        PaymentMethod.qr   => AppColors.primary,
        PaymentMethod.card => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _IconTile(icon: paymentMethodIcon(method)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(method.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14.5, color: AppColors.textPrimary)),
                    ),
                    const SizedBox(width: 8),
                    AnimatedValueText(
                      AppFormatters.currency(value),
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14.5, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 7,
                    color: AppColors.border,
                    alignment: Alignment.centerLeft,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: share.clamp(0, 1)),
                      duration: AppMotion.slow,
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => FractionallySizedBox(
                        widthFactor: v,
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _barColor(method),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
