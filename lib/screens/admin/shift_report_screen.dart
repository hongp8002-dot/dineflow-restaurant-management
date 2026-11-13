import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/shift_repository.dart';
import '../../models/shift.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';

/// Báo cáo ca của Admin: xem lại các ca thu ngân đã mở trong một ngày.
///
/// Mỗi ca hiện tiền đầu ca, doanh thu theo phương thức (tiền mặt / QR / thẻ),
/// tiền mặt phải có, tiền đếm được khi đóng ca và chênh lệch (thừa / thiếu).
/// Dữ liệu lấy từ `GET /api/shifts?date=` (chỉ Admin, chặn ở backend).
class ShiftReportScreen extends StatefulWidget {
  const ShiftReportScreen({super.key});

  @override
  State<ShiftReportScreen> createState() => _ShiftReportScreenState();
}

class _ShiftReportScreenState extends State<ShiftReportScreen> {
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  List<Shift>? _shifts;
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
      final list = await ShiftRepository.instance.fetchByDate(_date);
      if (mounted) setState(() => _shifts = list);
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
      _shifts = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(_date, DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(title: const Text('Báo cáo ca', style: TextStyle(fontWeight: FontWeight.w800))),
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
    if (_loading && _shifts == null) return const Center(child: CircularProgressIndicator());

    if (_error != null && _shifts == null) {
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

    final shifts = _shifts ?? const <Shift>[];
    final totalRevenue = shifts.fold<double>(0, (sum, s) => sum + s.revenueByMethod.total);

    return RefreshIndicator(
      onRefresh: _load,
      child: shifts.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 60),
                EmptyState(
                  icon: Icons.badge_outlined,
                  title: 'Không có ca nào',
                  message: 'Ngày này chưa có thu ngân nào mở ca.',
                ),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text('${shifts.length} ca · Tổng doanh thu ${AppFormatters.currency(totalRevenue)}',
                    style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                for (final shift in shifts) ...[
                  _ShiftCard(shift: shift),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  final Shift shift;

  const _ShiftCard({required this.shift});

  @override
  Widget build(BuildContext context) {
    final s = shift;
    final revenue = s.revenueByMethod;
    final timeRange = '${AppFormatters.time(s.openedAt)} – ${s.closedAt == null ? 'đang mở' : AppFormatters.time(s.closedAt!)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(s.cashierName,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              ),
              StatusBadge(
                label: s.status.label,
                color: s.isOpen ? AppColors.info : AppColors.success,
                background: s.isOpen ? AppColors.infoBg : AppColors.successBg,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('$timeRange · ${s.invoiceCount} hóa đơn',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const Divider(height: 22),
          _row('Tiền đầu ca', s.openingCash),
          _row('Thu tiền mặt', revenue.cash),
          _row('Thu QR / chuyển khoản', revenue.qr),
          _row('Thu thẻ', revenue.card),
          _row('Tổng doanh thu ca', revenue.total, bold: true),
          const Divider(height: 22),
          _row('Tiền mặt phải có', s.expectedCash),
          if (s.closingCashCounted != null) _row('Tiền mặt đếm được', s.closingCashCounted!),
          if (s.cashDifference != null) _differenceRow(s.cashDifference!),
          if (s.isOpen)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Ca chưa đóng — chưa có số tiền đếm được.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, double value, {bool bold = false}) {
    final style = TextStyle(
      fontSize: 13.5,
      color: AppColors.textPrimary,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(AppFormatters.currency(value), style: style),
        ],
      ),
    );
  }

  /// Chênh lệch = đếm được − phải có. Âm: thiếu tiền (đỏ); dương: thừa (cam); 0: khớp (xanh).
  Widget _differenceRow(double diff) {
    final (label, color) = diff == 0
        ? ('Khớp', AppColors.success)
        : diff < 0
            ? ('Thiếu ${AppFormatters.currency(-diff)}', AppColors.error)
            : ('Thừa ${AppFormatters.currency(diff)}', AppColors.warning);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text('Chênh lệch',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          ),
          Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
