import 'order_item.dart';

/// Trạng thái vận hành của đơn hàng (theo dõi bếp/phục vụ).
enum OrderStatus { placed, preparing, serving, completed, cancelled }

extension OrderStatusX on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.placed:
        return 'Đã đặt';
      case OrderStatus.preparing:
        return 'Đang chuẩn bị';
      case OrderStatus.serving:
        return 'Đang phục vụ';
      case OrderStatus.completed:
        return 'Hoàn thành';
      case OrderStatus.cancelled:
        return 'Đã hủy';
    }
  }
}

/// Trạng thái thanh toán của đơn hàng.
enum PaymentStatus { unpaid, pending, paid }

/// Đơn hàng (áp dụng cho cả đặt món tại bàn của Order Staff và đặt món của Customer).
class Order {
  final String id;

  /// Mã đơn dễ đọc do server cấp (vd. `OD261008-8144`); đơn mẫu không có.
  final String? code;
  final String? tableNumber;
  final String? customerName;

  /// Điểm thưởng khách đang có (chỉ có khi đơn gắn khách thành viên); thu ngân dùng khi thanh toán.
  final int customerPoints;
  final String staffName;
  final List<OrderItem> items;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final DateTime createdAt;
  final String note;

  /// ID đặt bàn liên kết (nếu đơn được tạo từ lượt đặt bàn của khách).
  final String? reservationId;

  /// Tiền cọc đã đặt bàn (từ reservation.deposit_amount nếu đã thanh toán cọc).
  /// 0.0 = không có cọc.
  final double depositAmount;

  /// Thông tin hủy (chỉ có khi đơn đã hủy): lý do, ghi chú, người hủy, thời điểm.
  final String? cancelReasonLabel;
  final String? cancelNote;
  final String? cancelledByName;
  final DateTime? cancelledAt;

  const Order({
    required this.id,
    this.code,
    this.tableNumber,
    this.customerName,
    this.customerPoints = 0,
    required this.staffName,
    required this.items,
    required this.status,
    this.paymentStatus = PaymentStatus.unpaid,
    required this.createdAt,
    this.note = '',
    this.reservationId,
    this.depositAmount = 0.0,
    this.cancelReasonLabel,
    this.cancelNote,
    this.cancelledByName,
    this.cancelledAt,
  });

  /// Đọc một đơn do API trả về (khóa `snake_case`).
  ///
  /// Đơn khách tự đặt qua app không có nhân viên tạo nên [staffName] là "Đặt qua app"
  /// (giống đơn mẫu).
  factory Order.fromApiJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'].toString(),
      code: json['code'] as String?,
      tableNumber: json['table_number'] as String?,
      customerName: json['customer_name'] as String?,
      customerPoints: (json['customer_points'] as num?)?.toInt() ?? 0,
      staffName: json['staff_name'] as String? ?? 'Đặt qua app',
      items: [
        for (final item in (json['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
          OrderItem.fromApiJson(item),
      ],
      status: OrderStatus.values.asNameMap()[json['status']] ?? OrderStatus.placed,
      paymentStatus: PaymentStatus.values.asNameMap()[json['payment_status']] ?? PaymentStatus.unpaid,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      note: json['note'] as String? ?? '',
      reservationId: json['reservation_id']?.toString(),
      depositAmount: (json['deposit_amount'] as num?)?.toDouble() ?? 0.0,
      cancelReasonLabel: json['cancel_reason_label'] as String?,
      cancelNote: json['cancel_note'] as String?,
      cancelledByName: json['cancelled_by_name'] as String?,
      cancelledAt: json['cancelled_at'] == null ? null : DateTime.parse(json['cancelled_at'] as String).toLocal(),
    );
  }

  /// Nhãn hiển thị cho người dùng: mã đơn của server, hoặc id viết hoa với đơn mẫu.
  String get displayCode => code ?? id.toUpperCase();

  double get subtotal => items.fold(0, (sum, i) => sum + i.total);

  /// Có tiền cọc được khấu trừ hay không.
  bool get hasDeposit => depositAmount > 0;

  int get totalQuantity => items.fold(0, (sum, i) => sum + i.quantity);
}
