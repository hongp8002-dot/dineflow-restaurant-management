import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/app_data.dart';
import '../../data/reservation_repository.dart';
import '../../models/reservation.dart';

import '../../app/routes.dart';
import '../../data/cart_store.dart';
import '../../data/mock_data.dart';
import '../../models/table_model.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/live_tables.dart';
import '../../widgets/quantity_stepper.dart';
import '../../widgets/status_legend.dart';
import '../../widgets/table_card.dart';
import 'booking_checkout.dart';

const EdgeInsets _pagePadding = EdgeInsets.symmetric(horizontal: 20);

TextStyle get _labelStyle =>
    TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary);

bool _isSameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Tổng số chỗ của các bàn còn trống trong một khu vực.
/// Tính ngay tại tầng giao diện từ danh sách bàn có sẵn, không thêm hàm mới
/// vào lớp dữ liệu (phần đó dành cho backend).
int _availableCapacityOfArea(String area) => MockData.tables
    .where((t) => t.area == area && t.status == TableStatus.empty)
    .fold(0, (sum, t) => sum + t.capacity);

int _emptyTablesOfArea(String area) =>
    MockData.tables.where((t) => t.area == area && t.status == TableStatus.empty).length;

/// Số khách tối đa nhận đặt online: bằng khu vực còn nhiều chỗ trống nhất,
/// vì chỉ ghép bàn trong cùng một khu vực.
int _maxPartySize() {
  final capacities = MockData.areas.map(_availableCapacityOfArea);
  return capacities.isEmpty ? 0 : capacities.reduce((a, b) => a > b ? a : b);
}

String _formatTime(TimeOfDay time) {
  final hh = time.hour.toString().padLeft(2, '0');
  final mm = time.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

/// Màn hình Đặt bàn dựng theo mockup "Đặt bàn": một trang duy nhất gồm
/// Ngày → Giờ đến → Số khách → Khu vực → (Chọn bàn) → Ghi chú → nút Xác nhận.
///
/// Khối "Chọn bàn" không có trong mockup nhưng được giữ lại vì nhóm đã chốt
/// tính năng ghép bàn khi số khách vượt sức chứa một bàn.
///
/// Màn hình dùng được ở hai nơi: là một tab trong khung Khách hàng, hoặc mở
/// riêng qua route [AppRoutes.customerBooking] (khi đó có nút quay lại).
class BookingTableScreen extends StatefulWidget {
  const BookingTableScreen({super.key});

  @override
  State<BookingTableScreen> createState() => _BookingTableScreenState();
}

class _BookingTableScreenState extends State<BookingTableScreen> {
  final _noteController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _selectedTime;
  int _guestCount = 2;
  late String _selectedArea = MockData.areas.isEmpty ? '' : MockData.areas.first;

  /// Các bàn khách đang chọn; nhiều hơn một bàn nghĩa là ghép bàn.
  /// Dùng List để giữ đúng thứ tự khách bấm chọn.
  final List<String> _selectedTableIds = [];

  /// Tính lại mỗi lần vì số chỗ trống đổi theo trạng thái bàn mới nhất.
  int get _maxGuestCount => _maxPartySize();

  late final List<DateTime> _upcomingDays = List.generate(30, (i) => DateTime.now().add(Duration(days: i)));

  static const _timeSlots = [
    '11:00', '11:30', '12:00', '12:30', '13:00', '13:30', '17:00', '17:30', //
    '18:00', '18:30', '19:00', '19:30', '20:00', '20:30', '21:00',
  ];

  List<TableModel> get _selectedTables =>
      _selectedTableIds.map((id) => MockData.tables.firstWhere((t) => t.id == id)).toList();

  int get _selectedCapacity => _selectedTables.fold(0, (sum, t) => sum + t.capacity);

  int get _missingSeats {
    final missing = _guestCount - _selectedCapacity;
    return missing > 0 ? missing : 0;
  }

  bool get _hasEnoughSeats => _selectedTableIds.isNotEmpty && _missingSeats == 0;

  /// Màn hình đang được mở riêng bằng route (không nằm trong tab).
  bool get _isStandalone => ModalRoute.of(context)?.settings.name == AppRoutes.customerBooking;

  bool _isPastSlot(String slot) {
    if (!_isSameDate(_selectedDate, DateTime.now())) return false;
    final parts = slot.split(':');
    final slotTime = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day, int.parse(parts[0]), int.parse(parts[1]));
    return slotTime.isBefore(DateTime.now().add(const Duration(minutes: 30)));
  }

  @override
  void initState() {
    super.initState();
    // Dòng nhắc cuối trang nói rõ số món khách đã chọn ở Thực đơn / Trang chủ.
    AppCart.customer.addListener(_onPicksChanged);
  }

  @override
  void dispose() {
    AppCart.customer.removeListener(_onPicksChanged);
    _noteController.dispose();
    super.dispose();
  }

  void _onPicksChanged() => setState(() {});

  void _toggleTable(TableModel table) {
    setState(() {
      if (_selectedTableIds.contains(table.id)) {
        _selectedTableIds.remove(table.id);
      } else {
        _selectedTableIds.add(table.id);
      }
    });
  }

  void _selectDate(DateTime day) {
    setState(() {
      _selectedDate = day;
      final time = _selectedTime;
      if (time != null && _isPastSlot(_formatTime(time))) _selectedTime = null;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      // Snackbar nổi đè lên nút xác nhận nên để thời gian ngắn.
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
  }

  bool _submitting = false;

  Future<void> _confirmBooking() async {
    if (_submitting) return;
    final time = _selectedTime;
    if (time == null) {
      _showMessage('Vui lòng chọn giờ đến');
      return;
    }
    if (_selectedTableIds.isEmpty) {
      _showMessage('Vui lòng chọn bàn');
      return;
    }
    if (!_hasEnoughSeats) {
      _showMessage('Các bàn đã chọn chỉ có $_selectedCapacity chỗ, '
          'còn thiếu $_missingSeats chỗ cho $_guestCount khách. Hãy ghép thêm bàn.');
      return;
    }

    // Bước 1: xin server GIỮ bàn (10 phút). Bàn đã bị người khác đặt / không đủ chỗ thì server từ chối.
    setState(() => _submitting = true);
    final Reservation reservation;
    try {
      reservation = await ReservationRepository.instance.hold(
        tables: _selectedTables,
        dateTime:
            DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, time.hour, time.minute),
        guestCount: _guestCount,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
      // Có thể trạng thái bàn đã đổi: tải lại để khách chọn bàn khác.
      AppData.refreshTables(force: true);
      return;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    if (!mounted) return;

    MockData.upsertReservation(reservation);

    // Bước 1 xong: giữ bàn và bắt đầu đếm thời gian hoàn tất 3 bước,
    // rồi sang bước 2 "Đặt món trước".
    BookingCheckout.instance.start(reservation);

    final navigator = Navigator.of(context);
    if (_isStandalone) {
      navigator.pushReplacementNamed(AppRoutes.customerPreOrder);
    } else {
      // Đang là một tab: không được thay thế route (sẽ mất cả khung điều hướng),
      // nên mở bước tiếp theo đè lên và làm mới biểu mẫu cho lần đặt sau.
      navigator.pushNamed(AppRoutes.customerPreOrder);
      setState(() {
        _selectedTime = null;
        _selectedTableIds.clear();
        _noteController.clear();
      });
    }
  }

  /// Bọc bằng [LiveTables]: tải trạng thái bàn mới nhất khi mở màn và dựng lại khi bàn đổi.
  @override
  Widget build(BuildContext context) => LiveTables(builder: (context, _) => _buildContent(context));

  Widget _buildContent(BuildContext context) {
    final time = _selectedTime;
    final confirmLabel = time == null
        ? 'Chọn giờ đến để tiếp tục'
        : 'Xác nhận · ${AppFormatters.shortWeekdayDate(_selectedDate)} lúc ${_formatTime(time)}';
    final holdMinutes = BookingCheckout.holdDuration.inMinutes;
    final picked = AppCart.customer.totalQuantity;
    final holdHint = picked > 0
        ? 'Sau khi giữ bàn, $picked món bạn đã chọn sẽ có sẵn ở bước Đặt món. '
            'Bạn có $holdMinutes phút để xác nhận và thanh toán.'
        : 'Sau khi giữ bàn, bạn có $holdMinutes phút để đặt món trước '
            '(không bắt buộc) và thanh toán.';

    var order = 0;
    Widget step(Widget child) => FadeSlideIn.staggered(index: order++, child: child);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 16, bottom: 20),
                children: [
                  step(Padding(padding: _pagePadding, child: _buildHeader())),
                  const SizedBox(height: 18),
                  step(_buildDates()),
                  const SizedBox(height: 20),
                  step(Padding(padding: _pagePadding, child: _buildTimes())),
                  const SizedBox(height: 18),
                  step(Padding(padding: _pagePadding, child: _buildGuests())),
                  const SizedBox(height: 20),
                  step(Padding(padding: _pagePadding, child: _buildAreas())),
                  const SizedBox(height: 20),
                  step(Padding(padding: _pagePadding, child: _buildTables())),
                  const SizedBox(height: 20),
                  step(Padding(padding: _pagePadding, child: _buildNote())),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Text(
                holdHint,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: AppButton(
                key: const ValueKey('booking-confirm'),
                label: confirmLabel,
                isLoading: _submitting,
                onPressed: _confirmBooking,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AppPageHeader(
      title: 'Đặt bàn',
      subtitle: 'Chọn ngày, giờ và số khách',
      showBack: _isStandalone,
    );
  }

  Widget _buildDates() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: _pagePadding,
          child: Text('Ngày · Tháng ${_selectedDate.month}', style: _labelStyle),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 70,
          child: ListView.separated(
            padding: _pagePadding,
            scrollDirection: Axis.horizontal,
            itemCount: _upcomingDays.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final day = _upcomingDays[i];
              return _DateChip(
                key: ValueKey('booking-date-$i'),
                date: day,
                selected: _isSameDate(day, _selectedDate),
                onTap: () => _selectDate(day),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimes() {
    final allPast = _timeSlots.every(_isPastSlot);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Giờ đến', style: _labelStyle),
        const SizedBox(height: 10),
        if (allPast) ...[
          const _NoSlotsNotice(),
          const SizedBox(height: 10),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 8.0;
            const columns = 4;
            final width = ((constraints.maxWidth - gap * (columns - 1)) / columns)
                .floorToDouble()
                .clamp(0.0, double.infinity);
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: _timeSlots.map((slot) {
                final parts = slot.split(':');
                final value = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
                final past = _isPastSlot(slot);
                return SizedBox(
                  width: width,
                  child: _TimeChip(
                    key: ValueKey('booking-time-$slot'),
                    label: slot,
                    selected: _selectedTime == value,
                    // Giờ đã qua vẫn hiển thị (gạch ngang) như mockup thay vì ẩn đi.
                    enabled: !past,
                    onTap: () => setState(() => _selectedTime = value),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGuests() {
    final atLimit = _guestCount >= _maxGuestCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.people_outline_rounded, size: 22, color: AppColors.textPrimary),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Số khách',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
              ),
              QuantityStepper(
                key: const ValueKey('booking-guest-stepper'),
                value: _guestCount,
                max: _maxGuestCount,
                size: QuantityStepperSize.large,
                buttonColor: AppColors.surface,
                onChanged: (v) => setState(() => _guestCount = v),
              ),
            ],
          ),
        ),
        // Chỉ nhắc khi chạm trần số khách đặt online, tránh làm rối bố cục mockup.
        AnimatedSize(
          duration: AppMotion.normal,
          curve: Curves.easeOutCubic,
          child: atLimit
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Đặt online tối đa $_maxGuestCount khách/lượt. Nhóm đông hơn vui lòng gọi '
                    '1900 1234 để nhà hàng sắp xếp riêng.',
                    style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondary),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _buildAreas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Khu vực', style: _labelStyle),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final (index, area) in MockData.areas.indexed) ...[
              if (index > 0) const SizedBox(width: 8),
              Expanded(
                child: _AreaCard(
                  title: area,
                  subtitle: '${_emptyTablesOfArea(area)} bàn trống',
                  selected: area == _selectedArea,
                  onTap: () => setState(() {
                    // Chỉ ghép bàn trong cùng khu vực nên đổi khu vực thì bỏ chọn hết.
                    _selectedArea = area;
                    _selectedTableIds.clear();
                  }),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildTables() {
    final tablesInArea = MockData.tables.where((t) => t.area == _selectedArea).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chọn bàn', style: _labelStyle),
        const SizedBox(height: 8),
        StatusLegend(
          items: [
            StatusLegendItem(AppColors.tableEmpty, 'Trống'),
            StatusLegendItem(AppColors.tableReserved, 'Đã đặt trước'),
            StatusLegendItem(AppColors.tableServing, 'Đang phục vụ'),
          ],
        ),
        const SizedBox(height: 10),
        _SeatSummary(
          guestCount: _guestCount,
          selectedTables: _selectedTables,
          missingSeats: _missingSeats,
          areaCapacity: _availableCapacityOfArea(_selectedArea),
          onClear: _selectedTableIds.isEmpty ? null : () => setState(_selectedTableIds.clear),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.9,
          ),
          itemCount: tablesInArea.length,
          itemBuilder: (context, index) {
            final table = tablesInArea[index];
            final canSelect = table.status == TableStatus.empty;
            final suitable = table.capacity >= _guestCount;
            final position = _selectedTableIds.indexOf(table.id);
            final selected = position != -1;
            return Opacity(
              opacity: canSelect ? 1 : 0.5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TableCard(
                    table: table,
                    selected: selected,
                    onTap: canSelect ? () => _toggleTable(table) : null,
                  ),
                  // Bàn đang chọn hiện số thứ tự ghép; bàn chưa chọn mà đủ chỗ
                  // một mình thì hiện dấu ✓.
                  if (selected)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
                        child: Text(
                          '${position + 1}',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryOnInk),
                        ),
                      ),
                    )
                  else if (canSelect && suitable)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                        child: Icon(Icons.check, size: 10, color: AppColors.textOnDark),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildNote() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ghi chú', style: _labelStyle),
        const SizedBox(height: 10),
        TextField(
          controller: _noteController,
          maxLines: 2,
          minLines: 1,
          decoration: const InputDecoration(hintText: 'Ví dụ: cần ghế trẻ em'),
        ),
      ],
    );
  }
}

/// Chip ngày: thứ viết tắt ở trên, ngày (2 chữ số) in đậm ở dưới.
class _DateChip extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  const _DateChip({super.key, required this.date, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      scale: 0.92,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: Curves.easeOut,
        width: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppFormatters.weekdayShort(date),
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.textOnPrimary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              date.day.toString().padLeft(2, '0'),
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.textOnPrimary : AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip giờ: chọn = nền vàng; giờ đã qua = nền kem, chữ gạch ngang, không bấm được.
class _TimeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _TimeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color borderColor;
    if (!enabled) {
      background = AppColors.surfaceAlt;
      borderColor = AppColors.surfaceAlt;
    } else if (selected) {
      background = AppColors.primary;
      borderColor = AppColors.primary;
    } else {
      background = AppColors.surface;
      borderColor = AppColors.border;
    }

    return PressScale(
      onTap: enabled ? onTap : null,
      scale: 0.93,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: Curves.easeOut,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: !enabled
                  ? AppColors.textSecondary
                  : (selected ? AppColors.textOnPrimary : AppColors.textPrimary),
              decoration: enabled ? null : TextDecoration.lineThrough,
              decorationColor: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Thẻ khu vực: tên khu vực + dòng phụ; đang chọn = nền nâu đen chữ trắng.
class _AreaCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _AreaCard({required this.title, required this.subtitle, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      scale: 0.95,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.ink : AppColors.border, width: 1.2),
        ),
        child: Column(
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.textOnDark : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: selected ? AppColors.textOnDark.withValues(alpha: 0.75) : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoSlotsNotice extends StatelessWidget {
  const _NoSlotsNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.event_busy_outlined, color: AppColors.textPrimary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Hôm nay đã hết khung giờ đặt bàn. Vui lòng chọn ngày khác.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thanh trạng thái ghép bàn: đã chọn những bàn nào, đủ chỗ hay còn thiếu.
class _SeatSummary extends StatelessWidget {
  final int guestCount;
  final List<TableModel> selectedTables;
  final int missingSeats;
  final int areaCapacity;
  final VoidCallback? onClear;

  const _SeatSummary({
    required this.guestCount,
    required this.selectedTables,
    required this.missingSeats,
    required this.areaCapacity,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final capacity = selectedTables.fold(0, (sum, t) => sum + t.capacity);
    final enough = selectedTables.isNotEmpty && missingSeats == 0;
    final areaTooSmall = areaCapacity < guestCount;

    final String message;
    final IconData icon;
    if (selectedTables.isEmpty) {
      icon = areaTooSmall ? Icons.error_outline_rounded : Icons.touch_app_outlined;
      message = areaTooSmall
          ? 'Khu vực này chỉ còn $areaCapacity chỗ trống, không đủ cho $guestCount khách. '
              'Hãy thử khu vực khác.'
          : 'Chọn bàn cho $guestCount khách. Nhóm đông có thể chọn nhiều bàn để ghép.';
    } else if (enough) {
      icon = Icons.check_circle_outline_rounded;
      message = selectedTables.length > 1
          ? 'Ghép ${selectedTables.length} bàn · $capacity chỗ · đủ cho $guestCount khách'
          : 'Đã chọn 1 bàn · $capacity chỗ · đủ cho $guestCount khách';
    } else {
      icon = Icons.add_circle_outline_rounded;
      message = 'Đã chọn $capacity/$guestCount chỗ · còn thiếu $missingSeats chỗ, '
          'hãy chọn thêm bàn để ghép';
    }

    return AnimatedContainer(
      duration: AppMotion.normal,
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: enough ? AppColors.successBg : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: enough ? AppColors.success : AppColors.surfaceAlt),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: enough ? AppColors.success : AppColors.textPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: enough ? AppColors.success : AppColors.textPrimary,
                  ),
                ),
              ),
              if (onClear != null) ...[
                const SizedBox(width: 8),
                PressScale(
                  onTap: onClear,
                  scale: 0.9,
                  child: Text(
                    'Bỏ chọn',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (selectedTables.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: selectedTables
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${t.number} (${t.capacity})',
                          style: TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.textOnPrimary),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
