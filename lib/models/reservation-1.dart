import 'dart:convert';

class Reservation {
  final int id;
  final String code;
  final int customerId;

  // Thông tin bàn
  final List<int> tableIds;
  final List<dynamic> tableNumbers;
  final String? area;
  final int? capacity;

  // Thông tin đặt bàn
  final DateTime dateTime;
  final int guestCount;
  final String? note;

  // Trạng thái
  final String status;
  final bool isHeld;
  final DateTime? holdExpiresAt;

  // Món đặt trước
  final List<dynamic>? preOrderItems;
  final String? preOrderPayment;
  final double preOrderTotal;

  // ── Tiền cọc ──────────────────────────────────────────────────────────────
  /// Số tiền cọc (50% tổng món đặt trước, làm tròn 100đ).
  /// null = không có cọc (khách không đặt món trước).
  final double? depositAmount;

  /// Thời điểm khách đã thanh toán cọc qua app.
  /// null = chưa thanh toán.
  final DateTime? depositPaidAt;
  // ──────────────────────────────────────────────────────────────────────────

  const Reservation({
    required this.id,
    required this.code,
    required this.customerId,
    required this.tableIds,
    required this.tableNumbers,
    this.area,
    this.capacity,
    required this.dateTime,
    required this.guestCount,
    this.note,
    required this.status,
    required this.isHeld,
    this.holdExpiresAt,
    this.preOrderItems,
    this.preOrderPayment,
    required this.preOrderTotal,
    this.depositAmount,
    this.depositPaidAt,
  });

  /// Khách đã thanh toán cọc chưa?
  bool get isDepositPaid => depositPaidAt != null;

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      id:         json['id'] as int,
      code:       json['code'] as String,
      customerId: json['customer_id'] as int,

      tableIds:     List<int>.from(json['table_ids'] ?? []),
      tableNumbers: List<dynamic>.from(json['table_numbers'] ?? []),
      area:         json['area'] as String?,
      capacity:     json['capacity'] as int?,

      dateTime:   DateTime.parse(json['date_time'] as String),
      guestCount: json['guest_count'] as int,
      note:       json['note'] as String?,

      status:        json['status'] as String,
      isHeld:        json['is_held'] as bool? ?? false,
      holdExpiresAt: json['hold_expires_at'] != null
          ? DateTime.parse(json['hold_expires_at'] as String)
          : null,

      preOrderItems:   json['pre_order_items'] != null
          ? (json['pre_order_items'] is String
              ? List<dynamic>.from(jsonDecode(json['pre_order_items'] as String))
              : List<dynamic>.from(json['pre_order_items'] as List))
          : null,
      preOrderPayment: json['pre_order_payment'] as String?,
      preOrderTotal:   (json['pre_order_total'] as num?)?.toDouble() ?? 0.0,

      // ── Tiền cọc ──────────────────────────────────────────────────────────
      depositAmount: json['deposit_amount'] != null
          ? (json['deposit_amount'] as num).toDouble()
          : null,
      depositPaidAt: json['deposit_paid_at'] != null
          ? DateTime.parse(json['deposit_paid_at'] as String)
          : null,
      // ──────────────────────────────────────────────────────────────────────
    );
  }

  Map<String, dynamic> toJson() => {
        'id':              id,
        'code':            code,
        'customer_id':     customerId,
        'table_ids':       tableIds,
        'table_numbers':   tableNumbers,
        'area':            area,
        'capacity':        capacity,
        'date_time':       dateTime.toIso8601String(),
        'guest_count':     guestCount,
        'note':            note,
        'status':          status,
        'is_held':         isHeld,
        'hold_expires_at': holdExpiresAt?.toIso8601String(),
        'pre_order_items':    preOrderItems,
        'pre_order_payment':  preOrderPayment,
        'pre_order_total':    preOrderTotal,
        'deposit_amount':     depositAmount,
        'deposit_paid_at':    depositPaidAt?.toIso8601String(),
      };
}
