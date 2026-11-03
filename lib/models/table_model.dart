/// Trạng thái bàn.
enum TableStatus { empty, serving, reserved, locked }

extension TableStatusX on TableStatus {
  String get label {
    switch (this) {
      case TableStatus.empty:
        return 'Trống';
      case TableStatus.serving:
        return 'Đang phục vụ';
      case TableStatus.reserved:
        return 'Đã đặt trước';
      case TableStatus.locked:
        return 'Khoá';
    }
  }
}

/// Bàn ăn trong nhà hàng.
class TableModel {
  final String id;
  final String number;
  final String area;
  final int capacity;
  final TableStatus status;
  final DateTime? servingSince;
  final String? currentOrderId;

  /// Admin: bàn đang bị khoá tạm thời (NV Order không mở được).
  final bool isLocked;

  /// Admin: bàn còn hoạt động (false = đã vô hiệu hoá / đã tháo).
  final bool isActive;

  const TableModel({
    required this.id,
    required this.number,
    required this.area,
    required this.capacity,
    this.status = TableStatus.empty,
    this.servingSince,
    this.currentOrderId,
    this.isLocked = false,
    this.isActive = true,
  });

  /// Đọc một bàn do API `/tables` trả về.
  ///
  /// `status` đã là trạng thái hiệu lực do server tính: bàn trống nhưng sắp có khách
  /// đặt trước thì server báo `reserved`.
  factory TableModel.fromApiJson(Map<String, dynamic> json) {
    final since = json['serving_since'] as String?;
    return TableModel(
      id: json['id'].toString(),
      number: json['number'] as String,
      area: json['area'] as String,
      capacity: (json['capacity'] as num).toInt(),
      status: switch (json['status']) {
        'serving' => TableStatus.serving,
        'reserved' => TableStatus.reserved,
        'locked' => TableStatus.locked,
        _ => TableStatus.empty,
      },
      servingSince: since == null ? null : DateTime.parse(since).toLocal(),
      currentOrderId: json['current_order_id']?.toString(),
      isLocked: json['is_locked'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  TableModel copyWith({
    TableStatus? status,
    DateTime? servingSince,
    String? currentOrderId,
    bool clearOrder = false,
    bool? isLocked,
    bool? isActive,
  }) {
    return TableModel(
      id: id,
      number: number,
      area: area,
      capacity: capacity,
      status: status ?? this.status,
      servingSince: servingSince ?? this.servingSince,
      currentOrderId: clearOrder ? null : (currentOrderId ?? this.currentOrderId),
      isLocked: isLocked ?? this.isLocked,
      isActive: isActive ?? this.isActive,
    );
  }
}
