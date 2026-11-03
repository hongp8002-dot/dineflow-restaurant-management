enum PromotionStatus { active, upcoming, expired }

extension PromotionStatusX on PromotionStatus {
  String get label {
    switch (this) {
      case PromotionStatus.active:
        return 'Đang áp dụng';
      case PromotionStatus.upcoming:
        return 'Sắp diễn ra';
      case PromotionStatus.expired:
        return 'Đã hết hạn';
    }
  }
}

/// Chương trình khuyến mãi / voucher.
class Promotion {
  final String id;
  final String name;
  final String code;
  final int percent;
  final DateTime startDate;
  final DateTime endDate;
  final PromotionStatus status;

  /// Số tiền giảm tối đa (null = không giới hạn) và giá trị đơn tối thiểu để áp dụng.
  final double? maxDiscount;
  final double minOrderAmount;

  const Promotion({
    required this.id,
    required this.name,
    required this.code,
    required this.percent,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.maxDiscount,
    this.minOrderAmount = 0,
  });

  /// Đọc một khuyến mãi do API `/promotions` trả về.
  factory Promotion.fromApiJson(Map<String, dynamic> json) {
    return Promotion(
      id: json['id'].toString(),
      name: json['title'] as String? ?? '',
      code: json['code'] as String,
      percent: (json['discount_percent'] as num).toInt(),
      startDate: DateTime.parse(json['valid_from'] as String).toLocal(),
      endDate: DateTime.parse(json['valid_to'] as String).toLocal(),
      status: switch (json['status']) {
        'upcoming' => PromotionStatus.upcoming,
        'expired' => PromotionStatus.expired,
        _ => PromotionStatus.active,
      },
      maxDiscount: (json['max_discount'] as num?)?.toDouble(),
      minOrderAmount: (json['min_order_amount'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Đơn có đạt giá trị tối thiểu để dùng voucher này không.
  bool appliesTo(double subtotal) => subtotal >= minOrderAmount;

  /// Số tiền được giảm cho đơn [subtotal] — tính giống hệt server (làm tròn, rồi áp trần
  /// [maxDiscount]) để số hiển thị khớp với số trên hóa đơn thật. Không đạt tối thiểu thì 0.
  double discountFor(double subtotal) {
    if (!appliesTo(subtotal)) return 0;
    final raw = (subtotal * percent / 100).roundToDouble();
    final cap = maxDiscount;
    return cap == null ? raw : (raw < cap ? raw : cap);
  }
}
