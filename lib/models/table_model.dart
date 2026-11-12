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

  /// Dùng bởi màn hình Đặt bàn: bàn có thể đặt theo ngày/giờ khách chọn.
  ///
  /// - null  → chưa biết (dữ liệu từ /tables — trạng thái hiện tại, không
  ///           phản ánh tương lai).
  /// - true  → trống tại thời điểm đặt (từ /tables/available).
  /// - false → đã có người đặt hoặc đang phục vụ tại thời điểm đó.
  final bool? available;

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
    this.available,
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
      // available không có trong /tables — dùng null để phân biệt
    );
  }

  /// Đọc một bàn do API `/tables/available` trả về.
  ///
  /// Trả về đúng cấu trúc như [fromApiJson] nhưng có thêm field `available`
  /// cho biết bàn có thể đặt theo ngày/giờ khách đang chọn hay không.
  ///
  /// **Override status**: nếu bàn hiện đang trống (status = empty) nhưng
  /// `available = false` (có người đặt vào giờ khách chọn), status được đổi
  /// thành `reserved` để TableCard hiển thị "Đã đặt trước" thay vì "Trống",
  /// tránh nhầm lẫn khi khách thấy bàn "Trống" nhưng lại không chọn được.
  factory TableModel.fromAvailabilityJson(Map<String, dynamic> json) {
    final base = TableModel.fromApiJson(json);
    final available = json['available'] as bool? ?? false;
    // Bàn hiện trống nhưng đã có người đặt lúc khách chọn → hiện "Đã đặt trước"
    final effectiveStatus = (!available && base.status == TableStatus.empty)
        ? TableStatus.reserved
        : base.status;
    return TableModel(
      id: base.id,
      number: base.number,
      area: base.area,
      capacity: base.capacity,
      status: effectiveStatus,
      servingSince: base.servingSince,
      currentOrderId: base.currentOrderId,
      isLocked: base.isLocked,
      isActive: base.isActive,
      available: available,
    );
  }

  TableModel copyWith({
    TableStatus? status,
    DateTime? servingSince,
    String? currentOrderId,
    bool clearOrder = false,
    bool? isLocked,
    bool? isActive,
    bool? available,
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
      available: available ?? this.available,
    );
  }
}
