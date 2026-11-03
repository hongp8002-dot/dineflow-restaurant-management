import 'food_option.dart';

/// Một dòng món trong đơn hàng/giỏ hàng.
class OrderItem {
  final String id;
  final String foodId;
  final String foodName;
  final double price;
  final int quantity;
  final List<FoodOption> selectedOptions;
  final String note;

  const OrderItem({
    required this.id,
    required this.foodId,
    required this.foodName,
    required this.price,
    this.quantity = 1,
    this.selectedOptions = const [],
    this.note = '',
  });

  /// Đọc một dòng món trong đơn do API trả về. `price` là đơn giá gốc lúc đặt (chưa gồm tùy chọn);
  /// `options` là bản chụp các tùy chọn đã chọn lúc đó.
  factory OrderItem.fromApiJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'].toString(),
      foodId: json['food_id']?.toString() ?? '',
      foodName: json['food_name'] as String? ?? '',
      price: (json['price'] as num).toDouble(),
      quantity: (json['quantity'] as num).toInt(),
      selectedOptions: [
        for (final o in (json['options'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
          FoodOption(
            id: o['id'].toString(),
            type: o['group'] == 'topping' ? FoodOptionType.topping : FoodOptionType.size,
            name: o['name'] as String? ?? '',
            extraPrice: (o['price_modifier'] as num?)?.toDouble() ?? 0,
          ),
      ],
      note: json['note'] as String? ?? '',
    );
  }

  double get optionsExtra => selectedOptions.fold(0, (sum, o) => sum + o.extraPrice);

  double get unitPrice => price + optionsExtra;

  double get total => unitPrice * quantity;

  String get optionsLabel => selectedOptions.map((o) => o.name).join(', ');

  OrderItem copyWith({int? quantity, String? note}) {
    return OrderItem(
      id: id,
      foodId: foodId,
      foodName: foodName,
      price: price,
      quantity: quantity ?? this.quantity,
      selectedOptions: selectedOptions,
      note: note ?? this.note,
    );
  }
}
