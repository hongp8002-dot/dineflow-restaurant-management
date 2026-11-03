import 'invoice.dart';
import 'order_item.dart';

/// Trạng thái của một lượt đặt bàn.
enum ReservationStatus { upcoming, completed, cancelled }

extension ReservationStatusX on ReservationStatus {
  String get label {
    switch (this) {
      case ReservationStatus.upcoming:
        return 'Sắp tới';
      case ReservationStatus.completed:
        return 'Đã hoàn thành';
      case ReservationStatus.cancelled:
        return 'Đã hủy';
    }
  }
}

/// Một lượt đặt bàn của khách hàng (đặt chỗ nhà hàng).
///
/// Một lượt đặt bàn có thể gồm **nhiều bàn được ghép lại** khi nhóm khách đông
/// hơn sức chứa của một bàn đơn (ví dụ 5 khách → ghép Bàn 1 + Bàn 2 = 6 chỗ).
/// Các bàn ghép luôn nằm trong cùng một khu vực.
class Reservation {
  final String id;
  final String code;
  final String customerId;

  /// Danh sách id các bàn thuộc lượt đặt này (1 phần tử nếu không ghép bàn).
  final List<String> tableIds;

  /// Tên hiển thị của các bàn, cùng thứ tự với [tableIds].
  final List<String> tableNumbers;

  final String area;

  /// Tổng số chỗ ngồi của tất cả các bàn trong lượt đặt.
  final int capacity;

  final DateTime dateTime;
  final int guestCount;
  final String? note;
  final ReservationStatus status;

  /// Các món khách đặt trước kèm lượt đặt bàn (rỗng nếu không đặt món).
  /// Món được chốt khi thanh toán; muốn gọi thêm thì gọi nhân viên khi đến quán.
  final List<OrderItem> preOrderItems;

  /// Phương thức khách chọn cho món đặt trước; [PaymentMethod.cash] là trả tại quán.
  /// null khi không đặt món.
  final PaymentMethod? preOrderPayment;

  /// Hạn giữ bàn khi lượt đặt còn đang chờ xác nhận (bước 1 xong, chưa thanh toán); null khi đã xác nhận.
  /// Quá hạn mà chưa xác nhận thì server tự hủy lượt đặt để nhả bàn.
  final DateTime? holdExpiresAt;

  const Reservation({
    required this.id,
    required this.code,
    required this.customerId,
    required this.tableIds,
    required this.tableNumbers,
    required this.area,
    required this.capacity,
    required this.dateTime,
    required this.guestCount,
    this.note,
    this.status = ReservationStatus.upcoming,
    this.preOrderItems = const [],
    this.preOrderPayment,
    this.holdExpiresAt,
  });

  /// Đọc một lượt đặt bàn do API trả về (khóa `snake_case`).
  factory Reservation.fromApiJson(Map<String, dynamic> json) {
    final lines = (json['pre_order_items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    final holdExpiresAt = json['hold_expires_at'] as String?;

    return Reservation(
      id: json['id'].toString(),
      code: json['code'] as String,
      customerId: json['customer_id'].toString(),
      tableIds: [for (final id in json['table_ids'] as List<dynamic>) id.toString()],
      tableNumbers: [for (final n in json['table_numbers'] as List<dynamic>) n as String],
      area: json['area'] as String,
      capacity: (json['capacity'] as num).toInt(),
      dateTime: DateTime.parse(json['date_time'] as String).toLocal(),
      guestCount: (json['guest_count'] as num).toInt(),
      note: json['note'] as String?,
      status: ReservationStatus.values.asNameMap()[json['status']] ?? ReservationStatus.upcoming,
      // Dòng món đặt trước server lưu không có id riêng nên đánh số theo thứ tự.
      preOrderItems: [
        for (final (i, line) in lines.indexed) OrderItem.fromApiJson({'id': 'pre-$i', ...line}),
      ],
      preOrderPayment: PaymentMethod.values.asNameMap()[json['pre_order_payment']],
      holdExpiresAt: holdExpiresAt == null ? null : DateTime.parse(holdExpiresAt).toLocal(),
    );
  }

  /// Đang giữ bàn chờ khách xác nhận.
  bool get isHeld => holdExpiresAt != null;

  /// Bàn chính (bàn đầu tiên) - dùng cho các chỗ chỉ cần tham chiếu một bàn.
  String get tableId => tableIds.first;

  /// Chuỗi hiển thị tên bàn, ví dụ `Bàn 1` hoặc `Bàn 1 + Bàn 2` khi ghép bàn.
  String get tableNumber => tableNumbers.join(' + ');

  /// Lượt đặt này có ghép nhiều bàn hay không.
  bool get isMerged => tableIds.length > 1;

  int get preOrderQuantity => preOrderItems.fold(0, (sum, i) => sum + i.quantity);

  double get preOrderTotal => preOrderItems.fold(0, (sum, i) => sum + i.total);

  Reservation copyWith({
    ReservationStatus? status,
    List<OrderItem>? preOrderItems,
    PaymentMethod? preOrderPayment,
    bool clearHold = false,
  }) {
    return Reservation(
      id: id,
      code: code,
      customerId: customerId,
      tableIds: tableIds,
      tableNumbers: tableNumbers,
      area: area,
      capacity: capacity,
      dateTime: dateTime,
      guestCount: guestCount,
      note: note,
      status: status ?? this.status,
      preOrderItems: preOrderItems ?? this.preOrderItems,
      preOrderPayment: preOrderPayment ?? this.preOrderPayment,
      holdExpiresAt: clearHold ? null : holdExpiresAt,
    );
  }
}
