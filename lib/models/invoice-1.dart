class Invoice {
  final int id;
  final String code;
  final int orderId;
  final String? orderCode;
  final String? tableNumber;

  final List<dynamic> items;

  final double subtotal;
  final double discount;

  /// Tiền cọc đã được khấu trừ (0 nếu không có cọc).
  /// Hiển thị rõ ràng trên hóa đơn: "Đã cọc: Xđ"
  final double depositAmount;

  final double total;

  final String? promotionCode;
  final String? paymentMethod;
  final String? status;
  final int? shiftId;
  final int? pointsEarned;

  final int? cashierId;
  final String? cashierName;

  final DateTime? createdAt;
  final DateTime? paidAt;

  const Invoice({
    required this.id,
    required this.code,
    required this.orderId,
    this.orderCode,
    this.tableNumber,
    required this.items,
    required this.subtotal,
    required this.discount,
    this.depositAmount = 0.0,
    required this.total,
    this.promotionCode,
    this.paymentMethod,
    this.status,
    this.shiftId,
    this.pointsEarned,
    this.cashierId,
    this.cashierName,
    this.createdAt,
    this.paidAt,
  });

  /// Có tiền cọc không?
  bool get hasDeposit => depositAmount > 0;

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id:          json['id'] as int,
      code:        json['code'] as String? ?? 'INV-${json['id']}',
      orderId:     json['order_id'] as int,
      orderCode:   json['order_code'] as String?,
      tableNumber: json['table_number'] as String?,

      items: List<dynamic>.from(json['items'] ?? []),

      subtotal:      (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount:      (json['discount'] as num?)?.toDouble() ?? 0.0,
      depositAmount: (json['deposit_amount'] as num?)?.toDouble() ?? 0.0,
      total:         (json['total'] as num?)?.toDouble() ?? 0.0,

      promotionCode: json['promotion_code'] as String?,
      paymentMethod: json['payment_method'] as String?,
      status:        json['status'] as String?,
      shiftId:       json['shift_id'] as int?,
      pointsEarned:  json['points_earned'] as int?,

      cashierId:   json['cashier_id'] as int?,
      cashierName: json['cashier_name'] as String?,

      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      paidAt:    json['paid_at']    != null ? DateTime.parse(json['paid_at']    as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id':             id,
        'code':           code,
        'order_id':       orderId,
        'order_code':     orderCode,
        'table_number':   tableNumber,
        'items':          items,
        'subtotal':       subtotal,
        'discount':       discount,
        'deposit_amount': depositAmount,
        'total':          total,
        'promotion_code': promotionCode,
        'payment_method': paymentMethod,
        'status':         status,
        'shift_id':       shiftId,
        'points_earned':  pointsEarned,
        'cashier_id':     cashierId,
        'cashier_name':   cashierName,
        'created_at':     createdAt?.toIso8601String(),
        'paid_at':        paidAt?.toIso8601String(),
      };
}
