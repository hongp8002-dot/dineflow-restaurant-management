import 'order_item.dart';

enum PaymentMethod { cash, qr, card }

extension PaymentMethodX on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'Tiền mặt';
      case PaymentMethod.qr:
        return 'QR';
      case PaymentMethod.card:
        return 'Thẻ ngân hàng';
    }
  }
}

/// Hóa đơn thanh toán.
class Invoice {
  final String id;

  /// Mã hóa đơn dễ đọc do server cấp (vd. `HD00007`); hóa đơn mẫu không có.
  final String? code;
  final String orderId;

  /// Mã đơn dễ đọc của đơn được thanh toán (vd. `OD251008-1012`).
  final String? orderCode;
  final String? tableNumber;
  final List<OrderItem> items;
  final double subtotal;
  final double discount;
  final double total;
  final PaymentMethod paymentMethod;
  final DateTime createdAt;
  final String cashierName;
  final String? cashierId;

  const Invoice({
    required this.id,
    this.code,
    required this.orderId,
    this.orderCode,
    this.tableNumber,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.paymentMethod,
    required this.createdAt,
    required this.cashierName,
    this.cashierId,
  });

  /// Đọc một hóa đơn do API trả về (khi thanh toán và ở danh sách `/invoices`).
  factory Invoice.fromApiJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'].toString(),
      code: json['code'] as String?,
      orderId: json['order_id'].toString(),
      orderCode: json['order_code'] as String?,
      tableNumber: json['table_number'] as String?,
      items: [
        for (final item in (json['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
          OrderItem.fromApiJson(item),
      ],
      subtotal: (json['subtotal'] as num).toDouble(),
      discount: (json['discount'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      paymentMethod: PaymentMethod.values.asNameMap()[json['payment_method']] ?? PaymentMethod.cash,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      cashierName: json['cashier_name'] as String? ?? '',
      cashierId: json['cashier_id']?.toString(),
    );
  }

  /// Nhãn hiển thị: mã server, hoặc id viết hoa với hóa đơn mẫu.
  String get displayCode => code ?? id.toUpperCase();

  /// Mã đơn hiển thị: mã server, hoặc id đơn viết hoa với dữ liệu mẫu.
  String get displayOrderCode => orderCode ?? orderId.toUpperCase();
}
