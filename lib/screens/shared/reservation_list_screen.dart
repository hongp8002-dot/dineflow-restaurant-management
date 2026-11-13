import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/api/api_exception.dart';
import '../../core/session/session_store.dart';
import '../../data/app_data.dart';
import '../../data/reservation_repository.dart';
import '../../models/reservation.dart';
import '../../models/user.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_header_band.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';

/// Lịch đặt bàn của nhà hàng theo ngày, dùng chung cho NV Order, Thu ngân và Admin.
///
/// - Cả ba vai trò đều xem được: khách, giờ, bàn, món đặt trước, tiền cọc.
/// - NV Order và Thu ngân bấm "Nhận bàn" khi khách tới: server mở bàn, tạo đơn từ món
///   đặt trước (đơn gắn lượt đặt để thu ngân trừ cọc) và chuyển lượt đặt sang "Đã hoàn thành".
///   Chỉ nhận được từ [_earlyCheckIn] trước đến [_grace] sau giờ hẹn; trễ hơn thì server
///   tự hủy lượt đặt (khách mất cọc) và bàn trống lại.
/// - Cả ba vai trò hủy được lượt đặt (vd khách không đến); tiền cọc không hoàn lại.
///
/// Quyền thật sự do backend kiểm tra (middleware `role:`); nút ẩn/hiện ở đây chỉ để giao diện gọn.
class ReservationListScreen extends StatefulWidget {
  const ReservationListScreen({super.key});

  @override
  State<ReservationListScreen> createState() => _ReservationListScreenState();
}

/// Khớp với Reservation::EARLY_CHECKIN_MINUTES và GRACE_MINUTES ở backend
/// (server vẫn là nơi quyết định; ở đây chỉ để ẩn/hiện nút cho đúng).
const _earlyCheckIn = Duration(minutes: 30);
const _grace = Duration(minutes: 15);

/// Đang trong khung nhận bàn của lượt đặt [r] không.
bool _inCheckInWindow(Reservation r, DateTime now) =>
    !now.isBefore(r.dateTime.subtract(_earlyCheckIn)) && !now.isAfter(r.dateTime.add(_grace));

class _ReservationListScreenState extends State<ReservationListScreen> {
  final _repo = ReservationRepository.instance;

  DateTime _date = DateUtils.dateOnly(DateTime.now());
  List<Reservation>? _items;
  String? _error;
  bool _loading = true;

  /// Lượt đặt đang được nhận bàn / hủy (để hiện vòng xoay đúng thẻ và chặn bấm hai lần).
  String? _busyId;

  UserRole? get _role => SessionStore.instance.user?.role;
  bool get _canCheckIn => _role == UserRole.orderStaff || _role == UserRole.cashier;

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
      final list = await _repo.fetchForDate(_date);
      if (mounted) setState(() => _items = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeDay(int delta) {
    setState(() {
      _date = _date.add(Duration(days: delta));
      _items = null;
    });
    _load();
  }

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 4)));

  void _replace(Reservation updated) {
    setState(() {
      _items = [for (final r in _items ?? <Reservation>[]) r.id == updated.id ? updated : r];
    });
  }

  Future<void> _checkIn(Reservation r) async {
    final ok = await _confirm(
      title: 'Nhận bàn ${r.tableNumber}?',
      body: 'Khách ${r.customerName ?? ''} · ${r.guestCount} khách · ${AppFormatters.time(r.dateTime)}.\n'
          '${r.preOrderItems.isEmpty ? 'Không có món đặt trước.' : 'Món đặt trước sẽ được thêm sẵn vào đơn.'}',
      action: 'Nhận bàn',
    );
    if (!ok) return;

    setState(() => _busyId = r.id);
    try {
      final result = await _repo.checkIn(r.id);
      if (!mounted) return;
      _replace(result.reservation);
      _say(result.message);
      // Bàn vừa chuyển sang "Đang phục vụ" và có đơn mới: làm mới để các màn khác thấy ngay.
      AppData.refresh({LiveSource.tables, LiveSource.orders}, force: true);
      if (_role == UserRole.orderStaff) {
        Navigator.of(context).pushNamed(AppRoutes.staffTableDetail, arguments: r.tableId);
      }
    } on ApiException catch (e) {
      if (mounted) _say(e.message);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _cancel(Reservation r) async {
    final depositNote = r.isDepositPaid
        ? '\nKhách đã cọc ${AppFormatters.currency(r.depositAmount ?? 0)} — tiền cọc không được hoàn lại.'
        : '';
    final ok = await _confirm(
      title: 'Hủy lượt đặt ${r.code}?',
      body: 'Dùng khi khách không đến hoặc báo hủy.$depositNote',
      action: 'Hủy lượt đặt',
      destructive: true,
    );
    if (!ok) return;

    setState(() => _busyId = r.id);
    try {
      final updated = await _repo.cancel(r.id);
      if (!mounted) return;
      _replace(updated);
      _say(r.isDepositPaid ? 'Đã hủy lượt đặt. Tiền cọc không được hoàn lại.' : 'Đã hủy lượt đặt.');
    } on ApiException catch (e) {
      if (mounted) _say(e.message);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Không')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action, style: TextStyle(color: destructive ? AppColors.error : AppColors.textPrimary)),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(_date, DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      body: Column(
        children: [
          const AppHeaderBand(title: 'Lịch đặt bàn', subtitle: 'Khách đặt trước theo ngày'),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
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
                  onPressed: _loading ? null : () => _changeDay(1),
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

  /// Giải thích vì sao chưa / không còn nút Nhận bàn.
  String _checkInHint(Reservation r) {
    final now = DateTime.now();
    final opensAt = r.dateTime.subtract(_earlyCheckIn);
    if (now.isBefore(opensAt)) {
      return 'Nhận bàn được từ ${AppFormatters.time(opensAt)}'
          '${DateUtils.isSameDay(opensAt, now) ? '' : ' ngày ${AppFormatters.date(opensAt)}'}.';
    }
    return 'Khách đã trễ quá ${_grace.inMinutes} phút — kéo xuống để làm mới, lượt đặt sẽ tự hủy.';
  }

  Widget _buildBody() {
    if (_loading && _items == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items == null) {
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

    final list = _items ?? const <Reservation>[];
    return RefreshIndicator(
      onRefresh: _load,
      child: list.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 60),
                EmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'Không có lượt đặt bàn',
                  message: 'Ngày này chưa có khách nào đặt bàn trước.',
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final r = list[i];
                final upcoming = r.status == ReservationStatus.upcoming;
                final inWindow = _inCheckInWindow(r, DateTime.now());
                return _ReservationCard(
                  reservation: r,
                  busy: _busyId == r.id,
                  checkInHint: upcoming && _canCheckIn && !inWindow ? _checkInHint(r) : null,
                  onCheckIn: upcoming && inWindow && _canCheckIn && _busyId == null ? () => _checkIn(r) : null,
                  onCancel: upcoming && _busyId == null ? () => _cancel(r) : null,
                );
              },
            ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  final Reservation reservation;
  final bool busy;
  final String? checkInHint;
  final VoidCallback? onCheckIn;
  final VoidCallback? onCancel;

  const _ReservationCard({
    required this.reservation,
    required this.busy,
    required this.checkInHint,
    required this.onCheckIn,
    required this.onCancel,
  });

  (Color, Color) get _statusColors => switch (reservation.status) {
        ReservationStatus.upcoming => (AppColors.info, AppColors.infoBg),
        ReservationStatus.completed => (AppColors.success, AppColors.successBg),
        ReservationStatus.cancelled => (AppColors.error, AppColors.errorBg),
      };

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final (fg, bg) = _statusColors;
    final secondary = TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(AppFormatters.time(r.dateTime),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(r.tableNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
              StatusBadge(label: r.status.label, color: fg, background: bg),
            ],
          ),
          const SizedBox(height: 6),
          Text('${r.customerName ?? 'Khách'}${r.customerPhone == null ? '' : ' · ${r.customerPhone}'}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Text('${r.area} · ${r.guestCount} khách · Mã ${r.code}', style: secondary),
          if (r.note != null && r.note!.trim().isNotEmpty) Text('Ghi chú: ${r.note}', style: secondary),
          if (r.preOrderItems.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Món đặt trước', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            for (final item in r.preOrderItems)
              Text(
                '${item.quantity}× ${item.foodName}'
                '${item.optionsLabel.isEmpty ? '' : ' (${item.optionsLabel})'}'
                '${item.note.isEmpty ? '' : ' — ${item.note}'}',
                style: secondary,
              ),
          ],
          const SizedBox(height: 8),
          Text(
            r.isDepositPaid
                ? 'Đã cọc ${AppFormatters.currency(r.depositAmount ?? 0)} — trừ vào hóa đơn khi thanh toán'
                : 'Không có tiền cọc',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: r.isDepositPaid ? AppColors.success : AppColors.textSecondary,
            ),
          ),
          if (checkInHint != null) ...[
            const SizedBox(height: 6),
            Text(checkInHint!, style: TextStyle(fontSize: 12.5, color: AppColors.warning, fontWeight: FontWeight.w600)),
          ],
          if (onCheckIn != null || onCancel != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (onCancel != null)
                  Expanded(
                    child: AppButton(
                      label: 'Hủy lượt đặt',
                      variant: AppButtonVariant.outlined,
                      dense: true,
                      onPressed: onCancel,
                    ),
                  ),
                if (onCancel != null && onCheckIn != null) const SizedBox(width: 10),
                if (onCheckIn != null)
                  Expanded(
                    child: AppButton(
                      label: 'Nhận bàn',
                      icon: Icons.how_to_reg_rounded,
                      dense: true,
                      isLoading: busy,
                      onPressed: onCheckIn,
                    ),
                  ),
              ],
            ),
          ],
          if (busy && onCheckIn == null) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
