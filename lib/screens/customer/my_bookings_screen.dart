import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/app_data.dart';
import '../../data/reservation_repository.dart';

import '../../data/mock_data.dart';
import '../../models/reservation.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';

({Color color, Color background}) _visualFor(ReservationStatus status) {
  switch (status) {
    case ReservationStatus.upcoming:
      return (color: AppColors.info, background: AppColors.infoBg);
    case ReservationStatus.completed:
      return (color: AppColors.success, background: AppColors.successBg);
    case ReservationStatus.cancelled:
      return (color: AppColors.error, background: AppColors.errorBg);
  }
}

/// Tab "Lịch đặt" của Khách hàng: các lượt đặt bàn Sắp tới / Lịch sử kèm món đặt
/// trước, có thể huỷ đặt bàn sắp tới. Cũng mở riêng được qua route
/// `AppRoutes.customerMyBookings` (khi đó có nút quay lại).
/// Bố cục đồng bộ với mockup: tiêu đề lớn trong trang, thẻ lịch đặt bàn giống
/// thẻ "Lịch đặt bàn sắp tới" ở Trang chủ (giờ · thứ, ngày in đậm).
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);

  List<Reservation> get _all =>
      MockData.reservations.where((r) => r.customerId == MockData.currentCustomer.id).toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

  List<Reservation> get _upcoming => _all.where((r) => r.status == ReservationStatus.upcoming).toList()
    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  List<Reservation> get _history => _all.where((r) => r.status != ReservationStatus.upcoming).toList();

  @override
  void initState() {
    super.initState();
    // Nằm sẵn trong khung tab nên phải tự cập nhật khi khách đặt/huỷ bàn ở nơi khác.
    MockData.reservationsVersion.addListener(_onReservationsChanged);
    AppData.refreshReservations(); // âm thầm: lịch đặt mới nhất mỗi lần mở tab
  }

  @override
  void dispose() {
    MockData.reservationsVersion.removeListener(_onReservationsChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onReservationsChanged() => setState(() {});

  Future<void> _confirmCancel(Reservation reservation) async {
    // Tiền cọc không hoàn lại khi huỷ → nói rõ trước khi khách xác nhận.
    final depositNote = reservation.isDepositPaid
        ? '\n\nTiền cọc ${AppFormatters.currency(reservation.depositAmount ?? 0)} sẽ KHÔNG được hoàn lại.'
        : '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Huỷ đặt bàn?'),
        content: Text('Bạn có chắc muốn huỷ đặt bàn ${reservation.tableNumber} lúc '
            '${AppFormatters.dateTime(reservation.dateTime)}?$depositNote'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Không')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Huỷ đặt bàn', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      MockData.upsertReservation(await ReservationRepository.instance.cancel(reservation.id));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(reservation.isDepositPaid
                ? 'Đã huỷ đặt bàn. Tiền cọc không được hoàn lại.'
                : 'Đã huỷ đặt bàn')));
    } on ApiException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
      // Có thể lượt đặt đã đổi trạng thái (vd. hết hạn giữ bàn): tải lại cho đúng.
      AppData.refreshReservations(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: AppPageHeader(title: 'Lịch đặt bàn', subtitle: 'Bàn đã giữ và món đặt trước'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: _SegmentedTabs(
                controller: _tabController,
                labels: ['Sắp tới (${_upcoming.length})', 'Lịch sử'],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _BookingList(
                    reservations: _upcoming,
                    onCancel: _confirmCancel,
                    emptyText: 'Bạn chưa có lịch đặt bàn nào sắp tới',
                  ),
                  _BookingList(reservations: _history, onCancel: null, emptyText: 'Chưa có lịch sử đặt bàn'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thanh chọn tab dạng nút gộp: nền kem, tab đang chọn nền nâu đen chữ trắng
/// (cùng kiểu với chip danh mục đang chọn ở Trang chủ).
class _SegmentedTabs extends StatelessWidget {
  final TabController controller;
  final List<String> labels;

  const _SegmentedTabs({required this.controller, required this.labels});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: AppColors.textOnDark,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        splashBorderRadius: BorderRadius.circular(12),
        indicator: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(12),
        ),
        tabs: [for (final label in labels) Tab(height: 40, text: label)],
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  final List<Reservation> reservations;
  final Future<void> Function(Reservation)? onCancel;
  final String emptyText;

  const _BookingList({required this.reservations, required this.onCancel, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    if (reservations.isEmpty) {
      return EmptyState(icon: Icons.event_busy_outlined, title: emptyText);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      itemCount: reservations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => FadeSlideIn.staggered(
        index: index,
        child: _BookingCard(reservation: reservations[index], onCancel: onCancel),
      ),
    );
  }
}

/// Thẻ một lượt đặt bàn: lượt sắp tới nền vàng nhạt (giống thẻ ở Trang chủ),
/// lượt đã qua/đã huỷ nền kem.
class _BookingCard extends StatelessWidget {
  final Reservation reservation;
  final Future<void> Function(Reservation)? onCancel;

  const _BookingCard({required this.reservation, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final visual = _visualFor(reservation.status);
    final upcoming = reservation.status == ReservationStatus.upcoming;
    final tables = reservation.isMerged
        ? '${reservation.tableNumber} (ghép ${reservation.tableIds.length} bàn)'
        : reservation.tableNumber;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: upcoming ? AppColors.primaryLight : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${AppFormatters.time(reservation.dateTime)} · ${AppFormatters.weekdayDate(reservation.dateTime)}',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(
                  label: reservation.status.label, color: visual.color, background: visual.background),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$tables · ${reservation.area} · ${reservation.guestCount} khách',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.confirmation_number_outlined, size: 16, color: AppColors.textPrimary),
              const SizedBox(width: 6),
              Flexible(
                child: Text('Mã ${reservation.code}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textPrimary)),
              ),
            ],
          ),
          if (reservation.note != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.sticky_note_2_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(reservation.note!,
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _PreOrderSection(reservation: reservation),
          if (onCancel != null) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => onCancel!(reservation),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  backgroundColor: AppColors.surface,
                  side: BorderSide.none,
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                child: const Text('Huỷ đặt bàn'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Khối món đặt trước trong thẻ đặt bàn: danh sách món, tổng tiền và cách thanh toán.
/// Lượt sắp tới kèm lời nhắc gọi thêm món với nhân viên khi đến quán.
class _PreOrderSection extends StatelessWidget {
  final Reservation reservation;

  const _PreOrderSection({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final items = reservation.preOrderItems;
    final upcoming = reservation.status == ReservationStatus.upcoming;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.restaurant_outlined, size: 16, color: AppColors.textPrimary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  items.isEmpty
                      ? 'Không đặt món trước'
                      : 'Món đặt trước · ${reservation.preOrderQuantity} món',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text('${item.quantity}x',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary)),
                    ),
                    Expanded(
                      child: Text(
                        item.optionsLabel.isEmpty ? item.foodName : '${item.foodName} (${item.optionsLabel})',
                        style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(AppFormatters.currency(item.total),
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            Divider(height: 16, color: AppColors.border),
            _MoneyRow(label: 'Tổng món đặt trước', value: reservation.preOrderTotal, bold: true),
            // Đã cọc: hiện số tiền cọc và phần còn lại trả khi đến quán (thu ngân trừ cọc vào hóa đơn)
            if (reservation.isDepositPaid) ...[
              const SizedBox(height: 4),
              _MoneyRow(label: 'Đã cọc', value: -(reservation.depositAmount ?? 0)),
              const SizedBox(height: 4),
              _MoneyRow(
                label: 'Còn lại trả tại quán',
                value: (reservation.preOrderTotal - (reservation.depositAmount ?? 0)).clamp(0, double.infinity).toDouble(),
                bold: true,
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text('Chưa cọc · Trả tại quán',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            ],
          ],
          if (upcoming) ...[
            const SizedBox(height: 8),
            Text(
              items.isEmpty
                  ? 'Bạn có thể gọi món với nhân viên khi đến quán.'
                  : 'Món đặt trước đã được chốt. Muốn gọi thêm, hãy gọi nhân viên khi đến quán.',
              style: TextStyle(fontSize: 12, height: 1.35, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Một dòng tiền trong thẻ đặt bàn: nhãn bên trái, số tiền bên phải (số âm = khoản trừ).
class _MoneyRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;

  const _MoneyRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final text = value < 0 ? '-${AppFormatters.currency(-value)}' : AppFormatters.currency(value);
    return Row(
      children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
        const SizedBox(width: 8),
        Text(text,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: bold ? 14 : 13,
              color: AppColors.textPrimary,
            )),
      ],
    );
  }
}
