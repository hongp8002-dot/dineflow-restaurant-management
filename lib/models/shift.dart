/// Trạng thái ca làm.
enum ShiftStatus { open, closed }

extension ShiftStatusX on ShiftStatus {
  String get label => this == ShiftStatus.open ? 'Đang mở' : 'Đã đóng';
}

/// Doanh thu theo phương thức thanh toán trong ca.
class ShiftRevenue {
  final double cash;
  final double qr;
  final double card;

  const ShiftRevenue({this.cash = 0, this.qr = 0, this.card = 0});

  double get total => cash + qr + card;

  factory ShiftRevenue.fromMap(Map<String, dynamic> map) => ShiftRevenue(
        cash: (map['cash'] as num?)?.toDouble() ?? 0,
        qr: (map['qr'] as num?)?.toDouble() ?? 0,
        card: (map['card'] as num?)?.toDouble() ?? 0,
      );
}

/// Ca làm việc của thu ngân.
class Shift {
  final String id;
  final String cashierId;
  final String cashierName;
  final ShiftStatus status;
  final double openingCash;

  /// Tiền mặt thu ngân đếm được khi đóng ca (null = chưa đóng).
  final double? closingCashCounted;

  /// Tiền mặt phải có theo hệ thống (đầu ca + thu tiền mặt trong ca).
  final double expectedCash;

  /// Chênh lệch tiền mặt khi đóng ca (null = chưa đóng).
  final double? cashDifference;

  final ShiftRevenue revenueByMethod;
  final int invoiceCount;
  final DateTime openedAt;
  final DateTime? closedAt;

  const Shift({
    required this.id,
    required this.cashierId,
    required this.cashierName,
    required this.status,
    required this.openingCash,
    this.closingCashCounted,
    required this.expectedCash,
    this.cashDifference,
    required this.revenueByMethod,
    required this.invoiceCount,
    required this.openedAt,
    this.closedAt,
  });

  factory Shift.fromApiJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'].toString(),
      cashierId: json['cashier_id'].toString(),
      cashierName: json['cashier_name'] as String? ?? '',
      status: json['status'] == 'open' ? ShiftStatus.open : ShiftStatus.closed,
      openingCash: (json['opening_cash'] as num?)?.toDouble() ?? 0,
      closingCashCounted: (json['closing_cash_counted'] as num?)?.toDouble(),
      expectedCash: (json['expected_cash'] as num?)?.toDouble() ?? 0,
      cashDifference: (json['cash_difference'] as num?)?.toDouble(),
      revenueByMethod: ShiftRevenue.fromMap(
          (json['revenue_by_method'] as Map<String, dynamic>?) ?? {}),
      invoiceCount: (json['invoice_count'] as num?)?.toInt() ?? 0,
      openedAt: DateTime.parse(json['opened_at'] as String).toLocal(),
      closedAt: json['closed_at'] != null
          ? DateTime.parse(json['closed_at'] as String).toLocal()
          : null,
    );
  }

  bool get isOpen => status == ShiftStatus.open;
}
